"""
rv_decoder.py
-------------
Pure-Python RV32IMFD instruction decoder used by the AOT codegen pipeline.

This is the build-time mirror of the runtime Lua decoder in
``risc-v-wow-emu/src/risc-v-core.lua`` (see ``DecodeInstruction``) and the
per-opcode semantics in ``rv32i-base-instructions.lua`` and
``risc-v-fpu.lua``.  The goal is a *structural* decode that produces a small
dataclass describing one instruction, sufficient for:

  * BFS block discovery (``rv_bfs.py``) - needs ``op``, ``can_branch``,
    ``indirect``, ``imm``, ``rd``, ``size``.
  * Lua snippet emission (``rv_codegen.py``) - needs every relevant field
    (``rd``, ``rs1``, ``rs2``, ``rs3``, ``imm``, ``shamt``, ``funct3``,
    ``funct7``, ``funct2``).

Only the "what is this instruction" question is answered here; semantic
evaluation happens in the codegen emitters.

The decoder returns :class:`DecodedInsn` with a stable ``op`` string
enumerating the concrete RV32IMFD opcode (e.g. ``"ADDI"`` rather than
``"OP-IMM"``).  Unknown / reserved encodings come back as
``op == "UNKNOWN"`` so the caller can treat them as implicit block
terminators or opaque blobs when scanning data regions.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


# ---------------------------------------------------------------------------
# Bit helpers
# ---------------------------------------------------------------------------

def _bits(word: int, hi: int, lo: int) -> int:
    """Extract bits [hi:lo] (inclusive) from a 32-bit word, unsigned."""
    width = hi - lo + 1
    return (word >> lo) & ((1 << width) - 1)


def _sign_extend(value: int, bits: int) -> int:
    """Sign-extend ``value`` interpreted as a ``bits``-wide two's-complement int."""
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


# ---------------------------------------------------------------------------
# Decoded representation
# ---------------------------------------------------------------------------

@dataclass
class DecodedInsn:
    """Structured RV32IMFD instruction.

    Attributes
    ----------
    raw : 32-bit little-endian instruction word exactly as found in memory.
    op  : concrete opcode mnemonic (``ADDI``, ``LW``, ``BEQ``, ``FADD_S`` ...).
    rd, rs1, rs2, rs3 : register indices (0-31) or None if unused.
    imm   : sign-extended immediate, already in its "natural" encoding
            (byte offset for LOAD/STORE/BRANCH/JAL, upper-20 value for
            LUI/AUIPC, CSR address for SYSTEM).
    shamt : shift amount for SLLI/SRLI/SRAI (0-31), else None.
    funct3, funct7, funct2 : sub-opcode fields.
    size  : instruction size in bytes (always 4 for RV32).
    can_branch : True for any instruction that may alter ``pc`` non-sequentially
                 (BRANCH, JAL, JALR, ECALL, EBREAK).  Block terminators.
    indirect   : True only for JALR (target unknown at build time).
    opcode     : the 7-bit major opcode; handy for raw-word debugging.
    """

    raw: int
    op: str
    opcode: int
    rd: Optional[int] = None
    rs1: Optional[int] = None
    rs2: Optional[int] = None
    rs3: Optional[int] = None
    imm: int = 0
    shamt: Optional[int] = None
    funct3: Optional[int] = None
    funct7: Optional[int] = None
    funct2: Optional[int] = None
    size: int = 4
    can_branch: bool = False
    indirect: bool = False
    # Free-form fields stashed for odd ops (e.g. SYSTEM csr address uses imm;
    # EBREAK reports ``sys_subop``).
    extras: dict = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Field decoders (match Lua decode_* helpers in risc-v-core.lua)
# ---------------------------------------------------------------------------

def _rd(w: int) -> int:
    return _bits(w, 11, 7)


def _rs1(w: int) -> int:
    return _bits(w, 19, 15)


def _rs2(w: int) -> int:
    return _bits(w, 24, 20)


def _rs3(w: int) -> int:
    return _bits(w, 31, 27)


def _funct3(w: int) -> int:
    return _bits(w, 14, 12)


def _funct7(w: int) -> int:
    return _bits(w, 31, 25)


def _funct2(w: int) -> int:
    return _bits(w, 26, 25)


# Immediate decoders - all return SIGNED python ints.

def _imm_i(w: int) -> int:
    return _sign_extend(_bits(w, 31, 20), 12)


def _imm_s(w: int) -> int:
    raw = (_bits(w, 31, 25) << 5) | _bits(w, 11, 7)
    return _sign_extend(raw, 12)


def _imm_b(w: int) -> int:
    # [12|10:5|4:1|11] << 1  (bit 0 is always 0)
    raw = (_bits(w, 31, 31) << 12) | \
          (_bits(w,  7,  7) << 11) | \
          (_bits(w, 30, 25) <<  5) | \
          (_bits(w, 11,  8) <<  1)
    return _sign_extend(raw, 13)


def _imm_u(w: int) -> int:
    # Upper-20 value, left-shifted into the high 20 bits.  Lua stores this
    # post-shift (``bit_band(instruction, 0xfffff000)``), so match that.
    return w & 0xFFFFF000


def _imm_j(w: int) -> int:
    # [20|10:1|11|19:12] << 1
    raw = (_bits(w, 31, 31) << 20) | \
          (_bits(w, 19, 12) << 12) | \
          (_bits(w, 20, 20) << 11) | \
          (_bits(w, 30, 21) <<  1)
    return _sign_extend(raw, 21)


# ---------------------------------------------------------------------------
# Sub-opcode tables
# ---------------------------------------------------------------------------

_BRANCH_BY_F3 = {
    0b000: "BEQ",
    0b001: "BNE",
    0b100: "BLT",
    0b101: "BGE",
    0b110: "BLTU",
    0b111: "BGEU",
}

_LOAD_BY_F3 = {
    0b000: "LB",
    0b001: "LH",
    0b010: "LW",
    0b100: "LBU",
    0b101: "LHU",
}

_STORE_BY_F3 = {
    0b000: "SB",
    0b001: "SH",
    0b010: "SW",
}

_OP_IMM_BY_F3 = {
    0b000: "ADDI",
    0b010: "SLTI",
    0b011: "SLTIU",
    0b100: "XORI",
    0b110: "ORI",
    0b111: "ANDI",
    # 0b001 SLLI, 0b101 SRLI/SRAI handled specially (shamt)
}

# (funct3, funct7) -> mnemonic for the OP (RV32I + RV32M) opcode.
_OP_BY_F3F7 = {
    (0b000, 0x00): "ADD",
    (0b000, 0x20): "SUB",
    (0b000, 0x01): "MUL",
    (0b001, 0x00): "SLL",
    (0b001, 0x01): "MULH",
    (0b010, 0x00): "SLT",
    (0b010, 0x01): "MULHSU",
    (0b011, 0x00): "SLTU",
    (0b011, 0x01): "MULHU",
    (0b100, 0x00): "XOR",
    (0b100, 0x01): "DIV",
    (0b101, 0x00): "SRL",
    (0b101, 0x20): "SRA",
    (0b101, 0x01): "DIVU",
    (0b110, 0x00): "OR",
    (0b110, 0x01): "REM",
    (0b111, 0x00): "AND",
    (0b111, 0x01): "REMU",
}

_SYSTEM_BY_F3 = {
    0b001: "CSRRW",
    0b010: "CSRRS",
    0b011: "CSRRC",
    0b101: "CSRRWI",
    0b110: "CSRRSI",
    0b111: "CSRRCI",
}


# ---------------------------------------------------------------------------
# Main decode entry point
# ---------------------------------------------------------------------------

def decode(word: int, pc: int = 0) -> DecodedInsn:
    """Decode a single 32-bit little-endian RV32IMFD instruction word.

    ``pc`` is optional; currently unused by the decoder but accepted so the
    call site can carry it alongside for block assembly.
    """
    word &= 0xFFFFFFFF
    opcode = word & 0x7F

    if opcode == 0x37:  # LUI
        return DecodedInsn(
            raw=word, op="LUI", opcode=opcode,
            rd=_rd(word), imm=_imm_u(word),
        )

    if opcode == 0x17:  # AUIPC
        return DecodedInsn(
            raw=word, op="AUIPC", opcode=opcode,
            rd=_rd(word), imm=_imm_u(word),
        )

    if opcode == 0x6F:  # JAL
        return DecodedInsn(
            raw=word, op="JAL", opcode=opcode,
            rd=_rd(word), imm=_imm_j(word),
            can_branch=True,
        )

    if opcode == 0x67:  # JALR
        return DecodedInsn(
            raw=word, op="JALR", opcode=opcode,
            rd=_rd(word), rs1=_rs1(word),
            funct3=_funct3(word), imm=_imm_i(word),
            can_branch=True, indirect=True,
        )

    if opcode == 0x63:  # BRANCH
        f3 = _funct3(word)
        op = _BRANCH_BY_F3.get(f3, "UNKNOWN_BRANCH")
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rs1=_rs1(word), rs2=_rs2(word),
            funct3=f3, imm=_imm_b(word),
            can_branch=True,
        )

    if opcode == 0x03:  # LOAD
        f3 = _funct3(word)
        op = _LOAD_BY_F3.get(f3, "UNKNOWN_LOAD")
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rd=_rd(word), rs1=_rs1(word),
            funct3=f3, imm=_imm_i(word),
        )

    if opcode == 0x23:  # STORE
        f3 = _funct3(word)
        op = _STORE_BY_F3.get(f3, "UNKNOWN_STORE")
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rs1=_rs1(word), rs2=_rs2(word),
            funct3=f3, imm=_imm_s(word),
        )

    if opcode == 0x13:  # OP-IMM
        f3 = _funct3(word)
        if f3 == 0b001:  # SLLI
            shamt = _bits(word, 24, 20)
            return DecodedInsn(
                raw=word, op="SLLI", opcode=opcode,
                rd=_rd(word), rs1=_rs1(word),
                funct3=f3, funct7=_funct7(word),
                shamt=shamt, imm=shamt,
            )
        if f3 == 0b101:  # SRLI / SRAI
            shamt = _bits(word, 24, 20)
            funct7 = _funct7(word)
            op = "SRAI" if (funct7 & 0x20) else "SRLI"
            return DecodedInsn(
                raw=word, op=op, opcode=opcode,
                rd=_rd(word), rs1=_rs1(word),
                funct3=f3, funct7=funct7,
                shamt=shamt, imm=shamt,
            )
        op = _OP_IMM_BY_F3.get(f3, "UNKNOWN_OPIMM")
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rd=_rd(word), rs1=_rs1(word),
            funct3=f3, imm=_imm_i(word),
        )

    if opcode == 0x33:  # OP (RV32I + RV32M)
        f3 = _funct3(word)
        f7 = _funct7(word)
        op = _OP_BY_F3F7.get((f3, f7), "UNKNOWN_OP")
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rd=_rd(word), rs1=_rs1(word), rs2=_rs2(word),
            funct3=f3, funct7=f7,
        )

    if opcode == 0x0F:  # MISC-MEM (FENCE / FENCE.I)
        f3 = _funct3(word)
        op = "FENCE_I" if f3 == 0b001 else "FENCE"
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rd=_rd(word), rs1=_rs1(word),
            funct3=f3, imm=_imm_i(word),
        )

    if opcode == 0x73:  # SYSTEM
        f3 = _funct3(word)
        imm_raw = _bits(word, 31, 20)  # unsigned 12-bit CSR address / sys subop
        if f3 == 0b000:
            # ECALL (imm == 0) / EBREAK (imm == 1).  Both are block terminators.
            op = "EBREAK" if imm_raw == 1 else "ECALL"
            return DecodedInsn(
                raw=word, op=op, opcode=opcode,
                rd=_rd(word), rs1=_rs1(word),
                funct3=f3, imm=imm_raw,
                can_branch=True,
                extras={"sys_subop": imm_raw},
            )
        op = _SYSTEM_BY_F3.get(f3, "UNKNOWN_SYSTEM")
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rd=_rd(word), rs1=_rs1(word),
            funct3=f3, imm=imm_raw,
        )

    if opcode == 0x07:  # FLW / FLD
        f3 = _funct3(word)
        op = "FLD" if f3 == 0b011 else "FLW"
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rd=_rd(word), rs1=_rs1(word),
            funct3=f3, imm=_imm_i(word),
        )

    if opcode == 0x27:  # FSW / FSD
        f3 = _funct3(word)
        op = "FSD" if f3 == 0b011 else "FSW"
        return DecodedInsn(
            raw=word, op=op, opcode=opcode,
            rs1=_rs1(word), rs2=_rs2(word),
            funct3=f3, imm=_imm_s(word),
        )

    if opcode in (0x43, 0x47, 0x4B, 0x4F):  # FMADD / FMSUB / FNMSUB / FNMADD
        name = {
            0x43: "FMADD",
            0x47: "FMSUB",
            0x4B: "FNMSUB",
            0x4F: "FNMADD",
        }[opcode]
        return DecodedInsn(
            raw=word, op=name, opcode=opcode,
            rd=_rd(word), rs1=_rs1(word), rs2=_rs2(word), rs3=_rs3(word),
            funct3=_funct3(word), funct2=_funct2(word),
        )

    if opcode == 0x53:  # OP-FP (all F/D ops)
        return DecodedInsn(
            raw=word, op="OP_FP", opcode=opcode,
            rd=_rd(word), rs1=_rs1(word), rs2=_rs2(word),
            funct3=_funct3(word), funct7=_funct7(word),
        )

    # Unknown / reserved - treat as opaque, not a branch.
    return DecodedInsn(raw=word, op="UNKNOWN", opcode=opcode)
