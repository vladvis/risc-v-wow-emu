"""Unit tests for ``aot_coverage.py``.

Uses the same synthetic ELF builder as :mod:`test_integration` so the two
tools get tested against an identical in-memory fixture format.  That
keeps "aot_compile compiled it" and "aot_coverage classifies it" in
lock-step -- if the BFS or ELF parser ever diverges between the two
tools, these tests will catch it.
"""

from __future__ import annotations

import os
import subprocess
import sys

import pytest

from . import rv_encoder as enc
from .test_integration import _build_elf


_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.dirname(_THIS_DIR)
AOT_COVERAGE = os.path.join(TOOLS_DIR, "aot_coverage.py")


# ---------------------------------------------------------------------------
# In-process tests (fast, no subprocess)
# ---------------------------------------------------------------------------

def _import_coverage():
    """Import the module under test, adding ``tools/`` to ``sys.path`` if the
    conftest shim hasn't already."""
    if TOOLS_DIR not in sys.path:
        sys.path.insert(0, TOOLS_DIR)
    import aot_coverage  # noqa: WPS433 - intentional local import
    return aot_coverage


def test_all_supported_reports_100pct():
    """ADDI + JAL form a minimal fully-supported program: coverage must be
    100.00% and no unsupported instructions should surface."""
    aot_coverage = _import_coverage()

    entry = 0x10000
    words = [
        enc.addi(5, 0, 1),
        enc.jal(0, 0),  # self-loop terminator
    ]
    elf = _build_elf(entry, words)

    report, supported, unsupported, blocks = aot_coverage.analyze(
        elf_bytes=elf, name="doom-mini",
    )

    assert unsupported == 0
    assert supported >= 2
    assert blocks >= 1

    # The header must be stable and greppable.
    head = report.splitlines()[:3]
    assert head[0] == "# aot_coverage report"
    assert head[1] == "# program: doom-mini"
    assert "coverage=100.00%" in head[2]
    assert "unsupported=0" in head[2]

    # The per-opcode histogram must list both mnemonics.
    assert "ADDI" in report
    assert "JAL" in report

    # The unsupported section must be explicitly empty.
    assert "(none)" in report


def test_unsupported_instruction_is_flagged():
    """Seeding the text with a raw 0xFFFFFFFF word produces an UNKNOWN
    decode that the codegen doesn't handle -- the coverage tool must
    count it as unsupported and surface its PC in the sample list."""
    aot_coverage = _import_coverage()

    entry = 0x10000
    # 0xFFFFFFFF has opcode bits 1111111, which doesn't match any of the
    # decoder's opcode branches, so it decodes as op="UNKNOWN".  We
    # precede it with a valid ADDI so the BFS walks past it into the
    # illegal word, then trail with a JAL to terminate the block.
    words = [
        enc.addi(5, 0, 1),
        0xFFFFFFFF,
        enc.jal(0, 0),
    ]
    elf = _build_elf(entry, words)

    report, supported, unsupported, _blocks = aot_coverage.analyze(
        elf_bytes=elf, name="doom-bad",
    )

    assert unsupported == 1
    assert supported >= 1  # ADDI is still counted; JAL may or may not be reached
    assert "UNKNOWN" in report

    # Header must reflect the failure.
    head = report.splitlines()[:3]
    assert "unsupported=1" in head[2]
    # Coverage must be strictly < 100%.
    assert "coverage=100.00%" not in head[2]

    # PC sample list must include the address of the illegal word
    # (entry + 4).
    assert f"0x{entry + 4:08x}" in report


def test_max_samples_flag_truncates_sample_list():
    """If there are more unsupported PCs than ``--max-unsupported-samples``,
    the report must only print the cap and annotate the remainder."""
    aot_coverage = _import_coverage()

    entry = 0x10000
    # Five illegal words in a row, then a JAL to close the block.  Note
    # the BFS will only walk until the first terminator, but UNKNOWN
    # isn't a terminator, so all five are captured.
    words = [0xFFFFFFFF] * 5 + [enc.jal(0, 0)]
    elf = _build_elf(entry, words)

    report, _supported, unsupported, _blocks = aot_coverage.analyze(
        elf_bytes=elf, name="doom-spam", max_samples=2,
    )

    assert unsupported == 5
    # 2 PCs should appear; the remaining 3 should be summarized.
    assert "+3 more" in report


# ---------------------------------------------------------------------------
# CLI / subprocess tests
# ---------------------------------------------------------------------------

def _run_coverage(elf_bytes: bytes, extra_args=None):
    args = [sys.executable, AOT_COVERAGE, "doom"]
    if extra_args:
        args.extend(extra_args)
    return subprocess.run(
        args,
        input=elf_bytes,
        capture_output=True,
        check=False,
    )


def test_cli_exits_zero_when_all_supported():
    entry = 0x10000
    words = [enc.addi(5, 0, 1), enc.jal(0, 0)]
    elf = _build_elf(entry, words)

    result = _run_coverage(elf)
    assert result.returncode == 0, result.stderr.decode("utf-8", "replace")
    stdout = result.stdout.decode("utf-8")
    # ``splitlines()`` is newline-agnostic so this test works on both Unix
    # (``\n``) and Windows (``\r\n``) default subprocess stdout decoding.
    assert stdout.splitlines()[0] == "# aot_coverage report"
    assert "coverage=100.00%" in stdout


def test_cli_exits_nonzero_when_unsupported_present():
    entry = 0x10000
    words = [enc.addi(5, 0, 1), 0xFFFFFFFF, enc.jal(0, 0)]
    elf = _build_elf(entry, words)

    result = _run_coverage(elf)
    assert result.returncode == 1, (
        f"expected exit 1, got {result.returncode}\n"
        f"stderr: {result.stderr.decode('utf-8', 'replace')}"
    )
    stdout = result.stdout.decode("utf-8")
    assert "unsupported=1" in stdout


def test_cli_rejects_empty_stdin():
    result = _run_coverage(b"")
    assert result.returncode == 2
    assert b"no ELF data" in result.stderr
