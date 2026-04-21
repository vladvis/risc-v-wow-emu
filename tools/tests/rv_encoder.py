"""Tiny RV32 instruction encoder used by unit tests to synthesize known
instructions and check them through :mod:`rv_decoder` + :mod:`rv_codegen`.

Not imported by the production tool - tests only.
"""

from __future__ import annotations


def _u(v: int, bits: int) -> int:
    """Truncate ``v`` to ``bits`` bits as unsigned."""
    return v & ((1 << bits) - 1)


def r_type(opcode: int, rd: int, funct3: int, rs1: int, rs2: int, funct7: int) -> int:
    return (
        (funct7 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | opcode
    )


def i_type(opcode: int, rd: int, funct3: int, rs1: int, imm: int) -> int:
    imm12 = _u(imm, 12)
    return (
        (imm12 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | opcode
    )


def s_type(opcode: int, funct3: int, rs1: int, rs2: int, imm: int) -> int:
    imm12 = _u(imm, 12)
    return (
        ((imm12 >> 5) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((imm12 & 0x1F) << 7)
        | opcode
    )


def b_type(opcode: int, funct3: int, rs1: int, rs2: int, imm: int) -> int:
    imm13 = _u(imm, 13)
    b12 = (imm13 >> 12) & 1
    b11 = (imm13 >> 11) & 1
    b10_5 = (imm13 >> 5) & 0x3F
    b4_1 = (imm13 >> 1) & 0xF
    return (
        (b12 << 31)
        | (b10_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (b4_1 << 8)
        | (b11 << 7)
        | opcode
    )


def u_type(opcode: int, rd: int, imm: int) -> int:
    return ((imm & 0xFFFFF000)) | (rd << 7) | opcode


def j_type(opcode: int, rd: int, imm: int) -> int:
    imm21 = _u(imm, 21)
    b20 = (imm21 >> 20) & 1
    b10_1 = (imm21 >> 1) & 0x3FF
    b11 = (imm21 >> 11) & 1
    b19_12 = (imm21 >> 12) & 0xFF
    return (
        (b20 << 31)
        | (b10_1 << 21)
        | (b11 << 20)
        | (b19_12 << 12)
        | (rd << 7)
        | opcode
    )


# Convenience wrappers keyed by mnemonic - tests only need the ones we check.
def addi(rd, rs1, imm):  return i_type(0x13, rd, 0b000, rs1, imm)
def slti(rd, rs1, imm):  return i_type(0x13, rd, 0b010, rs1, imm)
def sltiu(rd, rs1, imm): return i_type(0x13, rd, 0b011, rs1, imm)
def xori(rd, rs1, imm):  return i_type(0x13, rd, 0b100, rs1, imm)
def ori(rd, rs1, imm):   return i_type(0x13, rd, 0b110, rs1, imm)
def andi(rd, rs1, imm):  return i_type(0x13, rd, 0b111, rs1, imm)
def slli(rd, rs1, shamt):
    return i_type(0x13, rd, 0b001, rs1, shamt & 0x1F)
def srli(rd, rs1, shamt):
    return i_type(0x13, rd, 0b101, rs1, shamt & 0x1F)
def srai(rd, rs1, shamt):
    return i_type(0x13, rd, 0b101, rs1, (shamt & 0x1F) | (0x20 << 5))

def add(rd, rs1, rs2):   return r_type(0x33, rd, 0b000, rs1, rs2, 0x00)
def sub(rd, rs1, rs2):   return r_type(0x33, rd, 0b000, rs1, rs2, 0x20)
def sll(rd, rs1, rs2):   return r_type(0x33, rd, 0b001, rs1, rs2, 0x00)
def slt(rd, rs1, rs2):   return r_type(0x33, rd, 0b010, rs1, rs2, 0x00)
def sltu(rd, rs1, rs2):  return r_type(0x33, rd, 0b011, rs1, rs2, 0x00)
def xor_(rd, rs1, rs2):  return r_type(0x33, rd, 0b100, rs1, rs2, 0x00)
def srl(rd, rs1, rs2):   return r_type(0x33, rd, 0b101, rs1, rs2, 0x00)
def sra(rd, rs1, rs2):   return r_type(0x33, rd, 0b101, rs1, rs2, 0x20)
def or_(rd, rs1, rs2):   return r_type(0x33, rd, 0b110, rs1, rs2, 0x00)
def and_(rd, rs1, rs2):  return r_type(0x33, rd, 0b111, rs1, rs2, 0x00)

def mul(rd, rs1, rs2):    return r_type(0x33, rd, 0b000, rs1, rs2, 0x01)
def mulh(rd, rs1, rs2):   return r_type(0x33, rd, 0b001, rs1, rs2, 0x01)
def mulhsu(rd, rs1, rs2): return r_type(0x33, rd, 0b010, rs1, rs2, 0x01)
def mulhu(rd, rs1, rs2):  return r_type(0x33, rd, 0b011, rs1, rs2, 0x01)
def div(rd, rs1, rs2):    return r_type(0x33, rd, 0b100, rs1, rs2, 0x01)
def divu(rd, rs1, rs2):   return r_type(0x33, rd, 0b101, rs1, rs2, 0x01)
def rem(rd, rs1, rs2):    return r_type(0x33, rd, 0b110, rs1, rs2, 0x01)
def remu(rd, rs1, rs2):   return r_type(0x33, rd, 0b111, rs1, rs2, 0x01)

def lb(rd, rs1, imm):  return i_type(0x03, rd, 0b000, rs1, imm)
def lh(rd, rs1, imm):  return i_type(0x03, rd, 0b001, rs1, imm)
def lw(rd, rs1, imm):  return i_type(0x03, rd, 0b010, rs1, imm)
def lbu(rd, rs1, imm): return i_type(0x03, rd, 0b100, rs1, imm)
def lhu(rd, rs1, imm): return i_type(0x03, rd, 0b101, rs1, imm)

def sb(rs1, rs2, imm): return s_type(0x23, 0b000, rs1, rs2, imm)
def sh(rs1, rs2, imm): return s_type(0x23, 0b001, rs1, rs2, imm)
def sw(rs1, rs2, imm): return s_type(0x23, 0b010, rs1, rs2, imm)

def beq(rs1, rs2, imm):  return b_type(0x63, 0b000, rs1, rs2, imm)
def bne(rs1, rs2, imm):  return b_type(0x63, 0b001, rs1, rs2, imm)
def blt(rs1, rs2, imm):  return b_type(0x63, 0b100, rs1, rs2, imm)
def bge(rs1, rs2, imm):  return b_type(0x63, 0b101, rs1, rs2, imm)
def bltu(rs1, rs2, imm): return b_type(0x63, 0b110, rs1, rs2, imm)
def bgeu(rs1, rs2, imm): return b_type(0x63, 0b111, rs1, rs2, imm)

def lui(rd, imm):   return u_type(0x37, rd, imm)
def auipc(rd, imm): return u_type(0x17, rd, imm)
def jal(rd, imm):   return j_type(0x6F, rd, imm)
def jalr(rd, rs1, imm): return i_type(0x67, rd, 0b000, rs1, imm)

def ecall():  return i_type(0x73, 0, 0, 0, 0)
def ebreak(): return i_type(0x73, 0, 0, 0, 1)
def fence():  return i_type(0x0F, 0, 0, 0, 0)
def fence_i(): return i_type(0x0F, 0, 0b001, 0, 0)

def csrrw(rd, rs1, csr):  return i_type(0x73, rd, 0b001, rs1, csr)
def csrrs(rd, rs1, csr):  return i_type(0x73, rd, 0b010, rs1, csr)
def csrrc(rd, rs1, csr):  return i_type(0x73, rd, 0b011, rs1, csr)
def csrrwi(rd, imm, csr): return i_type(0x73, rd, 0b101, imm, csr)
def csrrsi(rd, imm, csr): return i_type(0x73, rd, 0b110, imm, csr)
def csrrci(rd, imm, csr): return i_type(0x73, rd, 0b111, imm, csr)

def flw(rd, rs1, imm): return i_type(0x07, rd, 0b010, rs1, imm)
def fld(rd, rs1, imm): return i_type(0x07, rd, 0b011, rs1, imm)
def fsw(rs1, rs2, imm): return s_type(0x27, 0b010, rs1, rs2, imm)
def fsd(rs1, rs2, imm): return s_type(0x27, 0b011, rs1, rs2, imm)

def fmadd(rd, rs1, rs2, rs3, funct3=0, funct2=0):
    return (rs3 << 27) | (funct2 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x43

def fmsub(rd, rs1, rs2, rs3, funct3=0, funct2=0):
    return (rs3 << 27) | (funct2 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x47

def fnmsub(rd, rs1, rs2, rs3, funct3=0, funct2=0):
    return (rs3 << 27) | (funct2 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x4B

def fnmadd(rd, rs1, rs2, rs3, funct3=0, funct2=0):
    return (rs3 << 27) | (funct2 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x4F

def op_fp(rd, rs1, rs2, funct3, funct7):
    return r_type(0x53, rd, funct3, rs1, rs2, funct7)
