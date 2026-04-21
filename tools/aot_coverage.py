#!/usr/bin/env python3
"""
aot_coverage.py
---------------
Opcode-coverage auditor for the AOT Lua codegen.

Reads an RV32IMFD ELF binary from stdin (same CLI style as ``elf2lua.py``
and ``aot_compile.py``), runs the same BFS block discovery that the codegen
uses at build time, and reports which decoded opcodes have a dedicated
emitter in ``rv_codegen.py`` and which would be silently emitted as
``-- UNSUPPORTED`` comments.

The purpose is to catch regressions where a new build of ``doomgeneric``
introduces an instruction encoding (an F-extension rounding-mode variant,
a stray compressed insn, an illegal word landed in .text by a linker bug)
that the codegen doesn't handle -- before the chunk ships into the WoW
addon and blows up at runtime.

Usage::

    cat build/bin/doomgeneric | python3 aot_coverage.py doom

The report goes to stdout, in a stable greppable format whose first three
lines are::

    # aot_coverage report
    # program: <name>
    # blocks=N insns=N supported=N unsupported=N coverage=xx.xx%

Exit code is ``1`` if any unsupported instructions are present -- intended
for CI gating of shipped builds. Exit code ``2`` means no ELF data was
supplied on stdin.
"""

from __future__ import annotations

import argparse
import os
import sys
from collections import Counter
from typing import Dict, List, Tuple

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import rv_bfs
import rv_codegen
from aot_compile import parse_elf


def _format_report(
    name: str,
    blocks,
    supported_hist: Counter,
    unsupported_hist: Counter,
    unsupported_samples: Dict[str, List[int]],
    max_samples: int,
) -> Tuple[str, int, int]:
    """Build the plain-text report.  Returns ``(text, supported, unsupported)``."""
    supported = sum(supported_hist.values())
    unsupported = sum(unsupported_hist.values())
    total = supported + unsupported
    pct = (100.0 * supported / total) if total else 100.0

    lines: List[str] = []
    lines.append("# aot_coverage report")
    lines.append(f"# program: {name}")
    lines.append(
        f"# blocks={len(blocks)} insns={total} "
        f"supported={supported} unsupported={unsupported} "
        f"coverage={pct:.2f}%"
    )
    lines.append("")

    # -- Opcode histogram (all ops, supported + unsupported). -----------
    lines.append("## opcode histogram")
    combined = Counter()
    combined.update(supported_hist)
    combined.update(unsupported_hist)
    # Sort by descending count, tiebreak alphabetically for stability.
    for op, cnt in sorted(combined.items(), key=lambda kv: (-kv[1], kv[0])):
        flag = " " if op in supported_hist else "!"
        lines.append(f"  {flag} {op:<10s} {cnt}")
    lines.append("")

    # -- Unsupported histogram with sample PCs. -------------------------
    lines.append("## unsupported instructions")
    if unsupported == 0:
        lines.append("  (none)")
    else:
        for op, cnt in sorted(unsupported_hist.items(),
                              key=lambda kv: (-kv[1], kv[0])):
            samples = unsupported_samples.get(op, [])
            shown = samples[:max_samples]
            sample_s = ", ".join(f"0x{pc:08x}" for pc in shown)
            extra = ""
            if len(samples) > len(shown):
                extra = f" (+{len(samples) - len(shown)} more)"
            lines.append(f"  {op:<10s} {cnt}  pcs=[{sample_s}]{extra}")
    lines.append("")

    # -- Summary. -------------------------------------------------------
    lines.append(
        f"## summary: supported: {supported} / {total} ({pct:.2f}%)"
    )

    return "\n".join(lines) + "\n", supported, unsupported


def analyze(
    elf_bytes: bytes,
    name: str,
    max_samples: int = 5,
) -> Tuple[str, int, int, int]:
    """Run coverage analysis.

    Returns ``(report_text, supported_count, unsupported_count, block_count)``.
    """
    entry_pc, memory, text_ranges, data_ranges, symbol_seeds = parse_elf(elf_bytes)

    discovery = rv_bfs.discover_blocks(
        memory=memory,
        text_ranges=text_ranges,
        entry_pc=entry_pc,
        scan_ranges=data_ranges,
        symbol_seeds=symbol_seeds,
    )

    supported_hist: Counter = Counter()
    unsupported_hist: Counter = Counter()
    unsupported_samples: Dict[str, List[int]] = {}

    for block in discovery.blocks:
        for pc, insn in block.instructions:
            if rv_codegen.is_codegen_supported(insn):
                supported_hist[insn.op] += 1
            else:
                unsupported_hist[insn.op] += 1
                unsupported_samples.setdefault(insn.op, []).append(pc)

    report, supported, unsupported = _format_report(
        name=name,
        blocks=discovery.blocks,
        supported_hist=supported_hist,
        unsupported_hist=unsupported_hist,
        unsupported_samples=unsupported_samples,
        max_samples=max_samples,
    )
    return report, supported, unsupported, len(discovery.blocks)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Walk an RV32IMFD ELF's .text and report which opcodes the "
            "AOT codegen can handle.  Exits 1 if any unsupported "
            "instruction is present."
        ),
    )
    parser.add_argument("name", help="Program symbolic name, e.g. 'doom'.")
    parser.add_argument(
        "--max-unsupported-samples",
        type=int,
        default=5,
        metavar="N",
        help="Maximum number of example PCs to list per unsupported op "
             "(default: 5).",
    )
    args = parser.parse_args(argv)

    elf_bytes = sys.stdin.buffer.read()
    if not elf_bytes:
        print("aot_coverage: no ELF data on stdin", file=sys.stderr)
        return 2

    report, _supported, unsupported, _blocks = analyze(
        elf_bytes=elf_bytes,
        name=args.name,
        max_samples=args.max_unsupported_samples,
    )
    sys.stdout.write(report)
    return 0 if unsupported == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
