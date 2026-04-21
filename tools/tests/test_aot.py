"""Unit tests for the AOT codegen.

Each test encodes a known instruction word by hand (via :mod:`rv_encoder`),
runs it through the decoder and then through the codegen, and asserts the
Lua snippet contains the expected structural fragments.

We use substring assertions rather than exact-string comparisons so minor
formatting changes in the emitters don't force test churn.
"""

from __future__ import annotations

import pytest

import rv_codegen
from rv_decoder import decode

from . import rv_encoder as enc


# Convenience helper: decode + emit in one step.
def _emit(word: int, pc: int = 0x10000) -> str:
    insn = decode(word, pc)
    return rv_codegen.emit_insn(insn, pc)


# ---------------------------------------------------------------------------
# Decoder sanity
# ---------------------------------------------------------------------------

class TestDecoder:
    def test_addi_positive(self):
        i = decode(enc.addi(5, 2, 16))
        assert i.op == "ADDI"
        assert i.rd == 5 and i.rs1 == 2 and i.imm == 16

    def test_addi_negative(self):
        i = decode(enc.addi(5, 2, -16))
        assert i.op == "ADDI"
        assert i.imm == -16

    def test_beq_signed_imm(self):
        i = decode(enc.beq(1, 2, -4))
        assert i.op == "BEQ"
        assert i.imm == -4
        assert i.can_branch is True

    def test_jal_can_branch(self):
        i = decode(enc.jal(1, 0x100))
        assert i.op == "JAL"
        assert i.imm == 0x100
        assert i.can_branch is True

    def test_jalr_indirect(self):
        i = decode(enc.jalr(0, 1, 0))
        assert i.op == "JALR"
        assert i.indirect is True
        assert i.can_branch is True

    def test_ecall_and_ebreak(self):
        e = decode(enc.ecall())
        b = decode(enc.ebreak())
        assert e.op == "ECALL" and e.can_branch
        assert b.op == "EBREAK" and b.can_branch

    def test_op_dispatch_mul_vs_add(self):
        assert decode(enc.mul(5, 6, 7)).op == "MUL"
        assert decode(enc.add(5, 6, 7)).op == "ADD"

    def test_srai_vs_srli(self):
        assert decode(enc.srli(5, 6, 3)).op == "SRLI"
        assert decode(enc.srai(5, 6, 3)).op == "SRAI"

    def test_fmadd_fields(self):
        i = decode(enc.fmadd(3, 4, 5, 6, funct3=7, funct2=1))
        assert i.op == "FMADD"
        assert i.rd == 3 and i.rs1 == 4 and i.rs2 == 5 and i.rs3 == 6
        assert i.funct3 == 7


# ---------------------------------------------------------------------------
# Codegen snippet checks
# ---------------------------------------------------------------------------

class TestOpImm:
    def test_addi(self):
        s = _emit(enc.addi(5, 2, 16))
        assert "R5" in s and "R2" in s and "+ (16)" in s
        assert "% 0x100000000" in s

    def test_addi_negative_imm_preserves_sign(self):
        s = _emit(enc.addi(5, 2, -16))
        assert "(-16)" in s

    def test_addi_x0_elides(self):
        assert _emit(enc.addi(0, 2, 16)) == ""

    def test_slli_folds_shift_as_multiply(self):
        s = _emit(enc.slli(5, 2, 4))
        # 2^4 = 16 folded as a literal multiplier.
        assert "R5" in s and "R2" in s and " * 16" in s

    def test_srli_uses_bit_rshift(self):
        s = _emit(enc.srli(5, 2, 3))
        assert "bit.rshift" in s and "3" in s

    def test_srai_uses_bit_arshift(self):
        s = _emit(enc.srai(5, 2, 3))
        assert "bit.arshift" in s

    def test_andi(self):
        s = _emit(enc.andi(5, 2, 0xFF))
        assert "bit.band" in s and "0xff" in s

    def test_slti_inlines_sign_extend(self):
        s = _emit(enc.slti(5, 2, -1))
        assert "a >= 0x80000000" in s
        assert "< (-1)" in s


class TestOp:
    def test_and(self):
        s = _emit(enc.and_(5, 6, 7))
        assert "bit.band(R6, R7)" in s

    def test_add(self):
        s = _emit(enc.add(5, 6, 7))
        assert "(R6 + R7)" in s and "% 0x100000000" in s

    def test_sub(self):
        s = _emit(enc.sub(5, 6, 7))
        assert "(R6 - R7)" in s

    def test_slt_sign_extends_both_operands(self):
        s = _emit(enc.slt(5, 6, 7))
        assert s.count("0x80000000") == 2

    def test_mul_sign_extends(self):
        s = _emit(enc.mul(5, 6, 7))
        assert "a * b" in s and "0x80000000" in s

    def test_mulhu_uses_unsigned_product(self):
        s = _emit(enc.mulhu(5, 6, 7))
        assert "math.floor((R6 * R7) / 0x100000000)" in s

    def test_div_handles_zero(self):
        s = _emit(enc.div(5, 6, 7))
        assert "b == 0" in s and "0xFFFFFFFF" in s


class TestLoadStore:
    def test_lw(self):
        s = _emit(enc.lw(5, 2, 12))
        assert "mem[(R2 + (12))]" in s and "or 0" in s

    def test_lw_x0_elides(self):
        assert _emit(enc.lw(0, 2, 12)) == ""

    def test_lbu_uses_shift8(self):
        s = _emit(enc.lbu(5, 2, 3))
        assert "SHIFT8[m+1]" in s and "% 256" in s

    def test_lb_sign_extends_byte(self):
        s = _emit(enc.lb(5, 2, 3))
        assert "v >= 0x80" in s and "0xFFFFFF00" in s

    def test_lh_sign_extends_half(self):
        s = _emit(enc.lh(5, 2, 2))
        assert "h >= 0x8000" in s and "0xFFFF0000" in s

    def test_sw(self):
        s = _emit(enc.sw(2, 5, 12))
        assert "mem[(R2 + (12))] = R5" in s

    def test_sb_handles_four_misalignments(self):
        s = _emit(enc.sb(2, 5, 3))
        assert "m == 0" in s and "m == 1" in s and "m == 2" in s
        assert "v % 0x100" in s

    def test_sh_handles_split_misalignment(self):
        s = _emit(enc.sh(2, 5, 2))
        assert "m == 0" in s and "m == 1" in s


class TestBranches:
    def test_beq_sets_both_paths(self):
        s = _emit(enc.beq(1, 2, 16), pc=0x100)
        assert "R1 == R2" in s
        assert "pc = 0x110" in s and "pc = 0x104" in s
        assert s.rstrip().endswith("return")

    def test_bne(self):
        s = _emit(enc.bne(1, 2, 8), pc=0x200)
        assert "R1 ~= R2" in s
        assert "pc = 0x208" in s and "pc = 0x204" in s

    def test_bltu(self):
        s = _emit(enc.bltu(1, 2, 8), pc=0x200)
        assert "R1 < R2" in s
        assert "0x80000000" not in s  # unsigned: no sign-extend

    def test_blt_signed(self):
        s = _emit(enc.blt(1, 2, 8), pc=0x200)
        assert s.count("0x80000000") == 2
        assert "a < b" in s

    def test_bge_signed(self):
        s = _emit(enc.bge(1, 2, 8), pc=0x200)
        assert "a >= b" in s


class TestJumps:
    def test_jal_links_and_sets_pc(self):
        s = _emit(enc.jal(1, 0x40), pc=0x1000)
        assert "R1 = 0x1004" in s
        assert "pc = 0x1040" in s
        assert s.rstrip().endswith("return")

    def test_jal_x0_no_link(self):
        s = _emit(enc.jal(0, 0x40), pc=0x1000)
        assert "R0" not in s
        assert "pc = 0x1040" in s

    def test_jalr_uses_modulo_two(self):
        # Plan-mandated: emit ``t - t % 2`` rather than bit.band.
        s = _emit(enc.jalr(1, 2, 0), pc=0x1000)
        assert "t - t % 2" in s
        assert "bit.band" not in s
        assert "R1 = 0x1004" in s


class TestSystem:
    def test_ecall_uses_bridge(self):
        s = _emit(enc.ecall(), pc=0x1000)
        assert "sync_out()" in s and "sync_in()" in s
        assert "ecall(R17)" in s
        assert "pc = 0x1004" in s
        assert s.rstrip().endswith("return")

    def test_ebreak_stops_cpu(self):
        s = _emit(enc.ebreak(), pc=0x1000)
        assert "bootState.is_running = 0" in s
        assert "pc = 0x1004" in s

    def test_csrrw_reads_writes(self):
        s = _emit(enc.csrrw(5, 6, 0xC00))
        assert "ReadCSR(3072)" in s  # 0xC00 == 3072
        assert "WriteCSR(3072" in s
        assert "R5" in s

    def test_csrrs_uses_bor(self):
        s = _emit(enc.csrrs(5, 6, 0xC00))
        assert "bit.bor(csr, R6)" in s

    def test_csrrci_uses_imm_source(self):
        s = _emit(enc.csrrci(5, 7, 0xC00))
        # rs1 field is an immediate (7), emitted directly.
        assert "bit.bnot(7)" in s


class TestMiscMem:
    def test_fence_elides(self):
        assert _emit(enc.fence()) == ""

    def test_fence_i_elides(self):
        assert _emit(enc.fence_i()) == ""


class TestU:
    def test_lui(self):
        s = _emit(enc.lui(5, 0x12345000))
        assert "R5 = 0x12345000" in s

    def test_auipc_folds_pc(self):
        s = _emit(enc.auipc(5, 0x1000), pc=0x2000)
        # 0x2000 + 0x1000 == 0x3000
        assert "R5 = 0x3000" in s


class TestFP:
    def test_flw_bridge(self):
        s = _emit(enc.flw(3, 2, 8))
        assert "fpu.flw(3," in s and "R2 + (8)" in s

    def test_fsw_bridge(self):
        s = _emit(enc.fsw(2, 3, 8))
        assert "fpu.fsw(3," in s and "R2 + (8)" in s

    def test_fmadd_bridge(self):
        s = _emit(enc.fmadd(3, 4, 5, 6, funct3=0, funct2=0))
        assert "fpu.fmadd(3, 0, 4, 5, 0, 6)" in s

    def test_op_fp_bridge(self):
        s = _emit(enc.op_fp(3, 4, 5, 0, 0))
        assert s.startswith("fpu.op_fp(")


# ---------------------------------------------------------------------------
# Block-level assembly
# ---------------------------------------------------------------------------

class TestBlockAssembly:
    def test_block_with_terminator_ends_in_return(self):
        words = [(0x1000, enc.addi(5, 2, 1)),
                 (0x1004, enc.jal(0, 0x10))]
        from rv_decoder import decode as _dec
        insns = [(pc, _dec(w, pc)) for pc, w in words]
        body = rv_codegen.emit_block_body(insns)
        assert body.rstrip().endswith("return")
        assert "pc = 0x1014" in body
        assert "R5" in body  # ADDI did emit

    def test_block_x0_addi_elides_in_body(self):
        from rv_decoder import decode as _dec
        insns = [
            (0x1000, _dec(enc.addi(0, 2, 1), 0x1000)),
            (0x1004, _dec(enc.jal(0, 4), 0x1004)),
        ]
        body = rv_codegen.emit_block_body(insns)
        # No "R0 =" assignment anywhere.
        assert "R0 = " not in body
        assert "pc = 0x1008" in body

    def test_unterminated_block_gets_synthetic_fallthrough(self):
        # BFS in production guarantees terminators, but the emitter should
        # still cope with an instruction-only block.
        from rv_decoder import decode as _dec
        insns = [
            (0x2000, _dec(enc.addi(5, 2, 1), 0x2000)),
            (0x2004, _dec(enc.addi(6, 3, 2), 0x2004)),
        ]
        body = rv_codegen.emit_block_body(insns)
        assert body.rstrip().endswith("return")
        assert "pc = 0x2008" in body
