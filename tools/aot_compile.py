#!/usr/bin/env python3
"""
aot_compile.py
--------------
Build-time AOT Lua codegen for the RISC-V emulator that runs Doom inside
the DoomWithin WoW addon.

Reads an RV32IMFD ELF binary from stdin and emits a Lua source file to
stdout.  The emitted file defines a single global ``_DW_DoomAOTChunk``
whose body holds one anonymous Lua closure per statically-discovered basic
block in the program text.  See ``aot.lua.j2`` for the exact shape and the
project plan (``aot_codegen_for_rv_emulator_36b31e42``) for rationale.

Usage:

    cat doomgeneric | python3 aot_compile.py doom aot.lua.j2 > doomgeneric_aot.lua

Optional ``--stats`` flag prints coverage statistics to stderr:

    cat doomgeneric | python3 aot_compile.py --stats doom aot.lua.j2 > out.lua

The tool style mirrors ``elf2lua.py``: positional ``<name> <template>`` with
ELF piped through stdin, Lua emitted on stdout.  The tool is expected to
run on Linux in WSL at build time; it is pure-Python and cross-platform.
"""

from __future__ import annotations

import argparse
import os
import sys
from io import BytesIO
from typing import Dict, List, Tuple

from elftools.elf.elffile import ELFFile
from elftools.elf.sections import SymbolTableSection
from jinja2 import Environment, FileSystemLoader

# Make sibling modules importable when invoked either as a script or via
# ``python -m``.
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import rv_bfs
import rv_codegen


# ---------------------------------------------------------------------------
# ELF ingestion
# ---------------------------------------------------------------------------

# SHF_* constants from elf.h.
SHF_WRITE = 0x1
SHF_ALLOC = 0x2
SHF_EXECINSTR = 0x4


def parse_elf(elf_bytes: bytes):
    """Parse an ELF blob and return:

        entry_pc, memory, text_ranges, data_ranges, symbol_seeds

    ``memory`` is a flat word-addressed ``{addr: uint32}`` table covering
    every allocated section (SHF_ALLOC).  ``text_ranges`` and
    ``data_ranges`` are lists of ``(base, size)`` tuples split by
    ``SHF_EXECINSTR``.  ``symbol_seeds`` is a list of PCs for every
    ``STT_FUNC`` symbol inside ``text_ranges``.
    """
    elf = ELFFile(BytesIO(elf_bytes))
    entry_pc = elf.header.e_entry

    memory: Dict[int, int] = {}
    text_ranges: List[Tuple[int, int]] = []
    data_ranges: List[Tuple[int, int]] = []

    for section in elf.iter_sections():
        sh_flags = section['sh_flags']
        if not (sh_flags & SHF_ALLOC):
            continue
        addr = section['sh_addr']
        size = section['sh_size']
        data = section.data()

        # Pack bytes into 32-bit little-endian words, matching the existing
        # memory representation in ``risc-v-memory.lua``.
        for i in range(0, len(data), 4):
            chunk = data[i:i + 4]
            # Zero-pad a final partial word if the section size isn't a
            # multiple of 4 (rare in practice but legal in ELF).
            if len(chunk) < 4:
                chunk = chunk + b"\x00" * (4 - len(chunk))
            memory[addr + i] = int.from_bytes(chunk, "little")

        # NOBITS sections (like .bss) report size but zero data.
        if len(data) < size:
            for addr_rem in range(addr + len(data), addr + size, 4):
                memory.setdefault(addr_rem, 0)

        if sh_flags & SHF_EXECINSTR:
            text_ranges.append((addr, size))
        else:
            data_ranges.append((addr, size))

    # Symbol-table assisted seeding: any STT_FUNC symbol that falls inside
    # a text range is a very-likely block entry.  Robust to stripped
    # binaries (we just get an empty list).
    symbol_seeds: List[int] = []
    for section in elf.iter_sections():
        if not isinstance(section, SymbolTableSection):
            continue
        for sym in section.iter_symbols():
            if sym['st_info']['type'] != 'STT_FUNC':
                continue
            value = sym['st_value']
            for base, size in text_ranges:
                if base <= value < base + size:
                    symbol_seeds.append(value)
                    break

    return entry_pc, memory, text_ranges, data_ranges, symbol_seeds


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def render_lua(name: str, template_path: str, entry_pc: int, blocks) -> Tuple[str, int]:
    """Render the Jinja template.  Returns ``(lua_source, insn_count)``."""
    template_dir = os.path.dirname(os.path.abspath(template_path)) or "."
    template_name = os.path.basename(template_path)
    env = Environment(
        loader=FileSystemLoader(template_dir),
        trim_blocks=False,
        lstrip_blocks=False,
        keep_trailing_newline=True,
    )
    env.filters['hex'] = lambda v: f"0x{v & 0xFFFFFFFF:x}"

    template = env.get_template(template_name)

    rendered_blocks = []
    total_insns = 0
    for block in blocks:
        body = rv_codegen.emit_block_body(block.instructions)
        rendered_blocks.append({
            "pc": block.start_pc,
            "body": body,
            "insn_count": len(block.instructions),
        })
        total_insns += len(block.instructions)

    lua = template.render(
        name=name,
        generator="aot_compile.py",
        entrypoint=entry_pc,
        blocks=rendered_blocks,
        block_count=len(rendered_blocks),
        insn_count=total_insns,
    )
    return lua, total_insns


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Build-time AOT Lua codegen for the DoomWithin RISC-V emulator.",
    )
    parser.add_argument("name", help="Program symbolic name, e.g. 'doom'.")
    parser.add_argument("template", help="Path to the Jinja2 template (e.g. aot.lua.j2).")
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Print coverage stats to stderr after emitting Lua.",
    )
    args = parser.parse_args(argv)

    elf_bytes = sys.stdin.buffer.read()
    if not elf_bytes:
        print("aot_compile: no ELF data on stdin", file=sys.stderr)
        return 2

    entry_pc, memory, text_ranges, data_ranges, symbol_seeds = parse_elf(elf_bytes)

    discovery = rv_bfs.discover_blocks(
        memory=memory,
        text_ranges=text_ranges,
        entry_pc=entry_pc,
        scan_ranges=data_ranges,
        symbol_seeds=symbol_seeds,
    )

    lua_source, insn_count = render_lua(
        name=args.name,
        template_path=args.template,
        entry_pc=entry_pc,
        blocks=discovery.blocks,
    )

    sys.stdout.write(lua_source)

    if args.stats:
        print(
            "aot_compile stats: "
            f"blocks={len(discovery.blocks)} "
            f"insns={insn_count} "
            f"text_words={discovery.text_word_count} "
            f"covered_words={discovery.covered_word_count} "
            f"coverage={discovery.coverage_pct:.2f}% "
            f"seeds={len(discovery.seeds)}",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
