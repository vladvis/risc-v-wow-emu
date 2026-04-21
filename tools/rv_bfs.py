"""
rv_bfs.py
---------
Static BFS block discovery over the ELF text segment.

Inputs
~~~~~~
* a memory image ``{word_addr: uint32}`` covering every allocated ELF section
  (executable + data + rodata + bss),
* ``text_ranges`` - a list of ``(addr, size)`` tuples for executable sections
  (``SHF_EXECINSTR``),
* ``entry_pc`` - the ELF header's ``e_entry``,
* optional ``scan_ranges`` to harvest 4-byte-aligned pointers from rodata/data
  (function-pointer tables, ``.init_array``, vtable-ish blobs),
* optional ``symbol_seeds`` - extra PCs to seed from the ELF symbol table (any
  ``STT_FUNC`` / ``T`` symbol is worth trying).

Output
~~~~~~
A :class:`DiscoveryResult` with:

* ``blocks``: ``list[Block]``, each a contiguous run of instructions ending
  with a terminator (BRANCH / JAL / JALR / ECALL / EBREAK).
* ``block_by_pc``: ``{start_pc: Block}``,
* statistics on how many text words were covered vs skipped.

Algorithm
~~~~~~~~~
Standard work-list BFS.

1. Seed queue with ``entry_pc``, ``symbol_seeds`` and every 4-aligned value
   scanned out of ``scan_ranges`` that lands inside a text range.
2. While queue non-empty:

   - Pop ``pc``; skip if already visited, or not inside a text range.
   - Walk instructions, decoding each word.  The walk stops on the first
     ``can_branch`` instruction.
   - Terminator fan-out (following the plan spec):

     * BRANCH: enqueue both ``pc + imm`` (taken) and ``pc_end + 4``
       (fall-through).
     * JAL: enqueue ``pc + imm`` (taken); if ``rd != 0``, also enqueue
       ``pc_end + 4`` (return-address landing pad).
     * JALR: target is unknown => enqueue nothing (runtime fallback picks it
       up).
     * ECALL / EBREAK: enqueue ``pc_end + 4``.

   - Add the assembled block to the result.

3. Return sorted by start PC for deterministic output.

The BFS deliberately over-approximates coverage: unreachable "blocks" rooted
at data-scan false positives are harmless (they just compile to a couple of
dead Lua functions) and the runtime will never branch into them.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from typing import Iterable, List, Optional, Sequence, Tuple

from rv_decoder import DecodedInsn, decode


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class Block:
    """A straight-line run of RV instructions ending in a terminator."""
    start_pc: int
    # instructions[i] = (pc_of_this_insn, decoded)
    instructions: List[Tuple[int, DecodedInsn]] = field(default_factory=list)

    @property
    def end_pc(self) -> int:
        """PC of the last (terminator) instruction in the block."""
        return self.instructions[-1][0]

    @property
    def terminator(self) -> DecodedInsn:
        return self.instructions[-1][1]

    @property
    def size_bytes(self) -> int:
        return len(self.instructions) * 4


@dataclass
class DiscoveryResult:
    blocks: List[Block]
    block_by_pc: dict
    text_word_count: int
    covered_word_count: int
    seeds: List[int]

    @property
    def coverage_pct(self) -> float:
        if self.text_word_count == 0:
            return 0.0
        return 100.0 * self.covered_word_count / self.text_word_count


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _in_range(pc: int, ranges: Sequence[Tuple[int, int]]) -> bool:
    for base, size in ranges:
        if base <= pc < base + size:
            return True
    return False


def _word_at(memory: dict, addr: int) -> Optional[int]:
    """Return the 4-byte word at ``addr`` (which must be 4-aligned) or None
    if the address isn't in the memory image."""
    if addr & 3:
        return None
    return memory.get(addr)


def _scan_for_text_pointers(
    memory: dict,
    scan_ranges: Sequence[Tuple[int, int]],
    text_ranges: Sequence[Tuple[int, int]],
) -> List[int]:
    """Walk ``scan_ranges`` in 4-byte strides and return every value that
    points into any of ``text_ranges``."""
    out: List[int] = []
    for base, size in scan_ranges:
        aligned_base = (base + 3) & ~3
        end = base + size
        for addr in range(aligned_base, end, 4):
            word = memory.get(addr)
            if word is None:
                continue
            if _in_range(word, text_ranges) and (word & 3) == 0:
                out.append(word)
    return out


# ---------------------------------------------------------------------------
# BFS entry point
# ---------------------------------------------------------------------------

def discover_blocks(
    memory: dict,
    text_ranges: Sequence[Tuple[int, int]],
    entry_pc: int,
    scan_ranges: Optional[Sequence[Tuple[int, int]]] = None,
    symbol_seeds: Optional[Iterable[int]] = None,
    max_insns_per_block: int = 4096,
) -> DiscoveryResult:
    """Run static BFS over the ELF text.

    See module docstring for semantics.

    ``max_insns_per_block`` is a safety net: if a block hasn't terminated
    after that many instructions we force-terminate (treat the next slot as
    outside text).  In practice Doom's biggest basic block is well under
    a few hundred instructions.
    """
    scan_ranges = list(scan_ranges or [])
    symbol_seeds = list(symbol_seeds or [])

    # Build list of seed PCs.
    seeds: List[int] = [entry_pc]
    seeds.extend(symbol_seeds)
    seeds.extend(_scan_for_text_pointers(memory, scan_ranges, text_ranges))

    # Unique + in-range + 4-aligned.
    filtered_seeds: List[int] = []
    seen_seed: set = set()
    for pc in seeds:
        if pc in seen_seed:
            continue
        seen_seed.add(pc)
        if (pc & 3) != 0:
            continue
        if not _in_range(pc, text_ranges):
            continue
        filtered_seeds.append(pc)

    queue: deque = deque(filtered_seeds)
    visited: set = set()
    blocks: List[Block] = []

    while queue:
        start_pc = queue.popleft()
        if start_pc in visited:
            continue
        if not _in_range(start_pc, text_ranges):
            continue
        visited.add(start_pc)

        block = Block(start_pc=start_pc)
        pc = start_pc
        walked = 0
        while walked < max_insns_per_block:
            if not _in_range(pc, text_ranges):
                break
            word = _word_at(memory, pc)
            if word is None:
                break
            insn = decode(word, pc)
            block.instructions.append((pc, insn))
            walked += 1

            if insn.can_branch:
                # Terminator-specific fanout.
                op = insn.op
                if op in ("BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU"):
                    taken = (pc + insn.imm) & 0xFFFFFFFF
                    fall = (pc + 4) & 0xFFFFFFFF
                    if taken not in visited:
                        queue.append(taken)
                    if fall not in visited:
                        queue.append(fall)
                elif op == "JAL":
                    target = (pc + insn.imm) & 0xFFFFFFFF
                    if target not in visited:
                        queue.append(target)
                    if insn.rd is not None and insn.rd != 0:
                        ret_landing = (pc + 4) & 0xFFFFFFFF
                        if ret_landing not in visited:
                            queue.append(ret_landing)
                elif op == "JALR":
                    # Indirect: we do NOT enqueue anything; runtime fallback
                    # handles unknown targets.
                    pass
                elif op in ("ECALL", "EBREAK"):
                    after = (pc + 4) & 0xFFFFFFFF
                    if after not in visited:
                        queue.append(after)
                break

            pc = (pc + 4) & 0xFFFFFFFF
        else:
            # Ran out of insns without a terminator.  Synthesize an "overflow"
            # JAL to pc (self loop) so the block has a clean terminator; the
            # runtime path will never execute this since a real program
            # wouldn't have a 4k-insn basic block.  We simply *don't* enqueue
            # fall-through and end the block with its last straight-line insn
            # so the codegen still emits a pc= fall-through terminator.
            pass

        if block.instructions:
            blocks.append(block)

    blocks.sort(key=lambda b: b.start_pc)
    block_by_pc = {b.start_pc: b for b in blocks}

    # Stats.
    text_word_count = 0
    for base, size in text_ranges:
        text_word_count += size // 4
    covered_word_count = sum(len(b.instructions) for b in blocks)

    return DiscoveryResult(
        blocks=blocks,
        block_by_pc=block_by_pc,
        text_word_count=text_word_count,
        covered_word_count=covered_word_count,
        seeds=filtered_seeds,
    )
