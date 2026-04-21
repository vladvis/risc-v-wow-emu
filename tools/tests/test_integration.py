"""End-to-end integration test for ``aot_compile.py``.

Builds a minimal synthetic ELF in-memory containing a handful of RV32
instructions (ADDI, BEQ, JAL, ECALL), pipes it through ``aot_compile.py``
via subprocess, and parses the emitted Lua with :mod:`luaparser` to prove
the generated file is at least syntactically valid Lua.

We don't run the Lua (no Lua interpreter is assumed on the host); the
differential validator that runs the chunk against a ground-truth trace
lives in a later phase of the plan.
"""

from __future__ import annotations

import os
import struct
import subprocess
import sys

import pytest

from . import rv_encoder as enc


_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.dirname(_THIS_DIR)
AOT_COMPILE = os.path.join(TOOLS_DIR, "aot_compile.py")
TEMPLATE = os.path.join(TOOLS_DIR, "aot.lua.j2")


# ---------------------------------------------------------------------------
# Minimal ELF32 (little-endian, RISC-V) builder
# ---------------------------------------------------------------------------
#
# We only need enough ELF to let pyelftools enumerate one executable
# section containing our raw RV instructions.  The layout is:
#
#     [ELF header] [program header x1] [.text bytes] [section header table]
#
# Strictly speaking, having no .shstrtab is borderline - pyelftools
# tolerates it, but including a tiny string table makes the output
# reproducible and inspectable in a hex editor.

def _build_elf(entry_pc: int, code_words):
    """Construct an in-memory ELF32 RISC-V blob with one PT_LOAD program
    header and one SHF_EXECINSTR | SHF_ALLOC section (".text") containing
    ``code_words`` at address ``entry_pc``.
    """
    code = b"".join(struct.pack("<I", w) for w in code_words)

    # Constants.
    EI_NIDENT = 16
    ELFCLASS32 = 1
    ELFDATA2LSB = 1
    EV_CURRENT = 1
    ELFOSABI_SYSV = 0
    ET_EXEC = 2
    EM_RISCV = 243
    SHT_NULL = 0
    SHT_PROGBITS = 1
    SHT_STRTAB = 3
    SHF_WRITE = 0x1
    SHF_ALLOC = 0x2
    SHF_EXECINSTR = 0x4
    PT_LOAD = 1
    PF_X = 1
    PF_R = 4

    # String table contents.
    shstrtab = b"\x00" + b".text\x00" + b".shstrtab\x00"
    text_name_off = 1
    shstrtab_name_off = 1 + len(b".text\x00")

    # Layout offsets.
    ehsize = 52
    phentsize = 32
    phnum = 1
    shentsize = 40
    shnum = 3  # NULL, .text, .shstrtab

    phoff = ehsize
    text_off = phoff + phentsize
    shstrtab_off = text_off + len(code)
    shoff = shstrtab_off + len(shstrtab)
    # Pad shoff to 4-byte alignment.
    pad = (-shoff) & 3
    shoff += pad
    shstrtab_section_size = len(shstrtab)

    # ELF header.
    e_ident = bytes([
        0x7F, ord('E'), ord('L'), ord('F'),
        ELFCLASS32, ELFDATA2LSB, EV_CURRENT, ELFOSABI_SYSV,
        0, 0, 0, 0, 0, 0, 0, 0,
    ])
    assert len(e_ident) == EI_NIDENT

    ehdr = e_ident + struct.pack(
        "<HHIIIIIHHHHHH",
        ET_EXEC,          # e_type
        EM_RISCV,         # e_machine
        EV_CURRENT,       # e_version
        entry_pc,         # e_entry
        phoff,            # e_phoff
        shoff,            # e_shoff
        0,                # e_flags
        ehsize,           # e_ehsize
        phentsize,        # e_phentsize
        phnum,            # e_phnum
        shentsize,        # e_shentsize
        shnum,            # e_shnum
        2,                # e_shstrndx (.shstrtab index)
    )

    # Program header (loads the .text at entry_pc).
    phdr = struct.pack(
        "<IIIIIIII",
        PT_LOAD,          # p_type
        text_off,         # p_offset
        entry_pc,         # p_vaddr
        entry_pc,         # p_paddr
        len(code),        # p_filesz
        len(code),        # p_memsz
        PF_R | PF_X,      # p_flags
        0x1000,           # p_align
    )

    # Section headers: [0]=NULL, [1]=.text, [2]=.shstrtab
    sh_null = struct.pack(
        "<IIIIIIIIII",
        0, SHT_NULL, 0, 0, 0, 0, 0, 0, 0, 0,
    )
    sh_text = struct.pack(
        "<IIIIIIIIII",
        text_name_off,                    # sh_name
        SHT_PROGBITS,                     # sh_type
        SHF_ALLOC | SHF_EXECINSTR,        # sh_flags
        entry_pc,                         # sh_addr
        text_off,                         # sh_offset
        len(code),                        # sh_size
        0,                                # sh_link
        0,                                # sh_info
        4,                                # sh_addralign
        0,                                # sh_entsize
    )
    sh_shstrtab = struct.pack(
        "<IIIIIIIIII",
        shstrtab_name_off,                # sh_name
        SHT_STRTAB,                       # sh_type
        0,                                # sh_flags
        0,                                # sh_addr
        shstrtab_off,                     # sh_offset
        shstrtab_section_size,            # sh_size
        0, 0, 1, 0,
    )

    blob = (
        ehdr
        + phdr
        + code
        + shstrtab
        + b"\x00" * pad
        + sh_null
        + sh_text
        + sh_shstrtab
    )
    return blob


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

def _run_aot(elf_bytes: bytes, extra_args=None):
    args = [sys.executable, AOT_COMPILE, "doom", TEMPLATE]
    if extra_args:
        args.extend(extra_args)
    result = subprocess.run(
        args,
        input=elf_bytes,
        capture_output=True,
        check=False,
    )
    return result


def _require_luaparser():
    try:
        from luaparser import ast  # noqa: F401
    except ImportError:
        pytest.skip("luaparser not installed")


def test_tiny_program_parses_as_valid_lua():
    _require_luaparser()
    from luaparser import ast

    entry = 0x10000
    # Small self-contained program:
    #   0x10000: addi x5, x0, 1
    #   0x10004: addi x6, x0, 2
    #   0x10008: beq  x5, x6, +8   -> taken @ 0x10010 (fall-through continues)
    #   0x1000C: jal  x0, +8       -> 0x10014
    #   0x10010: ecall
    #   0x10014: jal  x0, 0         -> infinite loop (terminates the BFS)
    words = [
        enc.addi(5, 0, 1),
        enc.addi(6, 0, 2),
        enc.beq(5, 6, 8),
        enc.jal(0, 8),
        enc.ecall(),
        enc.jal(0, 0),
    ]
    elf = _build_elf(entry, words)

    result = _run_aot(elf, extra_args=["--stats"])
    assert result.returncode == 0, (
        "aot_compile failed\n"
        f"stderr: {result.stderr.decode('utf-8', errors='replace')}"
    )
    lua_source = result.stdout.decode("utf-8")
    assert "_DW_DoomAOTChunk" in lua_source
    assert "blocks[0x10000]" in lua_source
    assert "sync_out" in lua_source and "sync_in" in lua_source

    # luaparser proves the output is syntactically well-formed Lua 5.x.
    ast.parse(lua_source)


def test_stats_flag_emits_coverage_to_stderr():
    _require_luaparser()

    entry = 0x10000
    words = [
        enc.addi(5, 0, 1),
        enc.jal(0, 0),  # loops on itself -> single 2-insn block
    ]
    elf = _build_elf(entry, words)

    result = _run_aot(elf, extra_args=["--stats"])
    assert result.returncode == 0
    stderr_text = result.stderr.decode("utf-8", errors="replace")
    assert "blocks=" in stderr_text
    assert "insns=" in stderr_text
    assert "coverage=" in stderr_text


def test_entry_and_block_table_are_linked():
    """Sanity: ``pc = <entrypoint>`` initializer matches ELF e_entry, and
    blocks table contains that address."""
    _require_luaparser()

    entry = 0x20000
    words = [enc.addi(5, 0, 1), enc.ecall(), enc.jal(0, 0)]
    elf = _build_elf(entry, words)

    result = _run_aot(elf)
    assert result.returncode == 0
    src = result.stdout.decode("utf-8")
    assert "local pc = 0x20000" in src
    assert "blocks[0x20000]" in src
