"""
rv_codegen.py
-------------
Per-opcode Lua source emitters for the AOT codegen pipeline.

Each emitter takes a :class:`rv_decoder.DecodedInsn` + the instruction's
``pc`` and returns a Lua source snippet (``str``).  Snippets are inserted
verbatim into the body of a ``blocks[pc] = function() ... end`` closure
that runs inside the AOT outer chunk, so they assume the following *lexical*
environment:

    local R0,R1,...,R31 = 0,0,...,0      -- 32-entry GPR bank (upvalues)
    local pc                              -- program counter
    local mem                             -- word-addressed memory table
    local SHIFT8 = {1, 256, 65536, 16777216, 4294967296}
    local ecall                           -- ecall bridge (takes syscall num)
    local fpu                             -- FPU bridge table
    local bootState                       -- { CPU = ..., is_running = 0|1 }
    local function sync_out() ... end
    local function sync_in()  ... end

Design rules (from the plan):

  * **x0 destination writes elide** to an empty snippet.
  * **Immediate constants are folded** into Lua literals at build time;
    never recomputed at runtime.
  * **Sign/unsign helpers are inlined** - no function-call overhead for
    something that's a two-line ``if v >= 0x80000000 then ...`` idiom.
  * **Terminators set pc and return**, i.e. the last statement is
    ``return`` so control exits the block closure.  The outer loop picks up
    the new pc and dispatches to the next ``blocks[pc]``.
  * **FP instructions bridge to a Lua-side helper table** (``fpu``) because
    re-implementing IEEE-754 rounding modes as Lua-source-strings is way
    out of scope for Phase 1; the runtime glue plugs the existing
    ``risc-v-fpu.lua`` into that bridge.
  * **JALR avoids the legacy single-arg ``bit.band`` bug** by computing
    ``t - t % 2`` directly in Lua.
"""

from __future__ import annotations

from typing import List, Optional

from rv_decoder import DecodedInsn


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_TERMINATOR_OPS = frozenset({
    "JAL", "JALR",
    "BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU",
    "ECALL", "EBREAK",
})


def _u32(x: int) -> int:
    """Reduce a Python int to an unsigned 32-bit value (for Lua literal output)."""
    return x & 0xFFFFFFFF


def _rreg(r: Optional[int]) -> str:
    """Register name: ``R5``, ``R17``, etc."""
    assert r is not None, "register index missing"
    return f"R{r}"


def _hex(v: int) -> str:
    """Pretty hex constant, always positive."""
    return f"0x{_u32(v):x}"


def _imm(v: int) -> str:
    """Format a signed immediate as a Lua literal.  We keep the sign so
    negative immediates get ``-16`` style literals instead of 32-bit
    two's-complement bit patterns - Lua handles signed arithmetic fine."""
    return f"({v})"


# ---------------------------------------------------------------------------
# Per-opcode emitters
#
# Each returns a Lua source fragment.  Return ``""`` for x0-writes or no-ops.
# Terminators end with ``return`` on their own final line.
# ---------------------------------------------------------------------------

# -- U-type ----------------------------------------------------------------

def emit_lui(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return f"{_rreg(insn.rd)} = {_hex(insn.imm)}"


def emit_auipc(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return f"{_rreg(insn.rd)} = {_hex(pc + insn.imm)}"


# -- J-type / JALR ---------------------------------------------------------

def emit_jal(insn: DecodedInsn, pc: int) -> str:
    target = _u32(pc + insn.imm)
    if insn.rd == 0:
        return f"pc = {_hex(target)}\nreturn"
    return (
        f"{_rreg(insn.rd)} = {_hex(pc + 4)}\n"
        f"pc = {_hex(target)}\n"
        f"return"
    )


def emit_jalr(insn: DecodedInsn, pc: int) -> str:
    # We intentionally use ``t - t % 2`` instead of ``bit.band(t, 0xFFFFFFFE)``
    # so this AOT path doesn't inherit the single-arg ``bit.band`` bug that
    # exists in the legacy interpreter's JALR.  Lua's ``%`` is correct for
    # negative operands too, so even if rs1+imm underflows we still land on
    # a clean even address.
    link = ""
    if insn.rd != 0:
        link = f"{_rreg(insn.rd)} = {_hex(pc + 4)}; "
    return (
        f"do local t = {_rreg(insn.rs1)} + {_imm(insn.imm)}; "
        f"{link}pc = t - t % 2 end\n"
        f"return"
    )


# -- BRANCH ----------------------------------------------------------------

def _emit_branch(insn: DecodedInsn, pc: int, op: str) -> str:
    taken = _u32(pc + insn.imm)
    fall = _u32(pc + 4)
    a, b = _rreg(insn.rs1), _rreg(insn.rs2)

    if op == "BEQ":
        cond = f"{a} == {b}"
    elif op == "BNE":
        cond = f"{a} ~= {b}"
    elif op == "BLTU":
        cond = f"{a} < {b}"
    elif op == "BGEU":
        cond = f"{a} >= {b}"
    elif op in ("BLT", "BGE"):
        # Signed compare - inline sign-extend of both operands.
        cmp_op = "<" if op == "BLT" else ">="
        return (
            f"do local a = {a}; local b = {b}\n"
            f"  if a >= 0x80000000 then a = a - 0x100000000 end\n"
            f"  if b >= 0x80000000 then b = b - 0x100000000 end\n"
            f"  if a {cmp_op} b then pc = {_hex(taken)} "
            f"else pc = {_hex(fall)} end end\n"
            f"return"
        )
    else:
        raise ValueError(f"unexpected branch op {op}")

    return (
        f"if {cond} then pc = {_hex(taken)} else pc = {_hex(fall)} end\n"
        f"return"
    )


def emit_beq(insn, pc):  return _emit_branch(insn, pc, "BEQ")
def emit_bne(insn, pc):  return _emit_branch(insn, pc, "BNE")
def emit_blt(insn, pc):  return _emit_branch(insn, pc, "BLT")
def emit_bge(insn, pc):  return _emit_branch(insn, pc, "BGE")
def emit_bltu(insn, pc): return _emit_branch(insn, pc, "BLTU")
def emit_bgeu(insn, pc): return _emit_branch(insn, pc, "BGEU")


# -- LOAD ------------------------------------------------------------------

def emit_lw(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return (
        f"{_rreg(insn.rd)} = mem[({_rreg(insn.rs1)} + {_imm(insn.imm)})] or 0"
    )


def emit_lbu(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return (
        f"do local a = {_rreg(insn.rs1)} + {_imm(insn.imm)}; local m = a % 4\n"
        f"  {_rreg(insn.rd)} = "
        f"math.floor((mem[a-m] or 0) / SHIFT8[m+1]) % 256 end"
    )


def emit_lb(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return (
        f"do local a = {_rreg(insn.rs1)} + {_imm(insn.imm)}; local m = a % 4\n"
        f"  local v = math.floor((mem[a-m] or 0) / SHIFT8[m+1]) % 256\n"
        f"  if v >= 0x80 then v = v + 0xFFFFFF00 end\n"
        f"  {_rreg(insn.rd)} = v end"
    )


def emit_lhu(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    # Replicates risc-v-memory.lua halfword-read: handles misalign==3 split.
    return (
        f"do local a = {_rreg(insn.rs1)} + {_imm(insn.imm)}; local m = a % 4\n"
        f"  local h\n"
        f"  if m == 3 then\n"
        f"    local p1 = math.floor((mem[a-3] or 0) / 16777216)\n"
        f"    local p2 = ((mem[a+1] or 0) % 256) * 256\n"
        f"    h = p1 + p2\n"
        f"  else\n"
        f"    h = math.floor((mem[a-m] or 0) / SHIFT8[m+1]) % 65536\n"
        f"  end\n"
        f"  {_rreg(insn.rd)} = h end"
    )


def emit_lh(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return (
        f"do local a = {_rreg(insn.rs1)} + {_imm(insn.imm)}; local m = a % 4\n"
        f"  local h\n"
        f"  if m == 3 then\n"
        f"    local p1 = math.floor((mem[a-3] or 0) / 16777216)\n"
        f"    local p2 = ((mem[a+1] or 0) % 256) * 256\n"
        f"    h = p1 + p2\n"
        f"  else\n"
        f"    h = math.floor((mem[a-m] or 0) / SHIFT8[m+1]) % 65536\n"
        f"  end\n"
        f"  if h >= 0x8000 then h = h + 0xFFFF0000 end\n"
        f"  {_rreg(insn.rd)} = h end"
    )


# -- STORE -----------------------------------------------------------------

def emit_sw(insn: DecodedInsn, pc: int) -> str:
    return (
        f"mem[({_rreg(insn.rs1)} + {_imm(insn.imm)})] = {_rreg(insn.rs2)}"
    )


def emit_sb(insn: DecodedInsn, pc: int) -> str:
    # Full replica of risc-v-memory.lua SB word-packing.
    return (
        f"do local a = {_rreg(insn.rs1)} + {_imm(insn.imm)}\n"
        f"  local v = {_rreg(insn.rs2)}; local m = a % 4\n"
        f"  if m == 0 then\n"
        f"    local old = mem[a] or 0\n"
        f"    mem[a] = (old - (old % 0x100)) + (v % 0x100)\n"
        f"  elseif m == 1 then\n"
        f"    local base = a - 1; local old = mem[base] or 0\n"
        f"    local low = old % 0x100\n"
        f"    local upper = math.floor(old / 0x10000) * 0x10000\n"
        f"    mem[base] = low + upper + ((v % 0x100) * 0x100)\n"
        f"  elseif m == 2 then\n"
        f"    local base = a - 2; local old = mem[base] or 0\n"
        f"    local low16 = old % 0x10000\n"
        f"    local top = math.floor(old / 0x1000000) * 0x1000000\n"
        f"    mem[base] = low16 + top + ((v % 0x100) * 0x10000)\n"
        f"  else\n"
        f"    local base = a - 3; local old = mem[base] or 0\n"
        f"    mem[base] = (old % 0x1000000) + ((v % 0x100) * 0x1000000)\n"
        f"  end end"
    )


def emit_sh(insn: DecodedInsn, pc: int) -> str:
    # Full replica of risc-v-memory.lua SH word-packing.
    return (
        f"do local a = {_rreg(insn.rs1)} + {_imm(insn.imm)}\n"
        f"  local v = {_rreg(insn.rs2)}; local m = a % 4\n"
        f"  if m == 0 then\n"
        f"    local old = mem[a] or 0\n"
        f"    local newv = (math.floor(old / 0x10000) * 0x10000) + (v % 0x10000)\n"
        f"    mem[a] = newv\n"
        f"  elseif m == 1 then\n"
        f"    local base = a - 1; local old = mem[base] or 0\n"
        f"    local low8 = old % 0x100\n"
        f"    local high8 = math.floor(old / 0x1000000)\n"
        f"    local mid = v % 0x10000\n"
        f"    mem[base] = low8 + ((mid % 0x100) * 0x100)\n"
        f"               + (math.floor(mid / 0x100) * 0x10000)\n"
        f"               + (high8 * 0x1000000)\n"
        f"  elseif m == 2 then\n"
        f"    local base = a - 2; local old = mem[base] or 0\n"
        f"    mem[base] = (old % 0x10000) + ((v % 0x10000) * 0x10000)\n"
        f"  else\n"
        f"    local base1 = a - 3; local old1 = mem[base1] or 0\n"
        f"    mem[base1] = (old1 % 0x1000000) + ((v % 0x100) * 0x1000000)\n"
        f"    local base2 = a + 1; local old2 = mem[base2] or 0\n"
        f"    mem[base2] = (old2 - (old2 % 0x100)) + (math.floor(v / 0x100) % 0x100)\n"
        f"  end end"
    )


# -- OP-IMM ----------------------------------------------------------------

def emit_addi(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return f"{_rreg(insn.rd)} = ({_rreg(insn.rs1)} + {_imm(insn.imm)}) % 0x100000000"


def emit_slti(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    return (
        f"do local a = {_rreg(insn.rs1)}\n"
        f"  if a >= 0x80000000 then a = a - 0x100000000 end\n"
        f"  {_rreg(insn.rd)} = (a < {_imm(insn.imm)}) and 1 or 0 end"
    )


def emit_sltiu(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    imm_u = _u32(insn.imm)
    return f"{_rreg(insn.rd)} = ({_rreg(insn.rs1)} < {_hex(imm_u)}) and 1 or 0"


def emit_xori(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    imm_u = _u32(insn.imm)
    return (
        f"{_rreg(insn.rd)} = bit.bxor({_rreg(insn.rs1)}, {_hex(imm_u)})"
        f" % 0x100000000"
    )


def emit_ori(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    imm_u = _u32(insn.imm)
    return (
        f"{_rreg(insn.rd)} = bit.bor({_rreg(insn.rs1)}, {_hex(imm_u)})"
        f" % 0x100000000"
    )


def emit_andi(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    imm_u = _u32(insn.imm)
    return (
        f"{_rreg(insn.rd)} = bit.band({_rreg(insn.rs1)}, {_hex(imm_u)})"
    )


def emit_slli(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    mul = 1 << (insn.shamt & 0x1F)
    return f"{_rreg(insn.rd)} = ({_rreg(insn.rs1)} * {mul}) % 0x100000000"


def emit_srli(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    shamt = insn.shamt & 0x1F
    return f"{_rreg(insn.rd)} = bit.rshift({_rreg(insn.rs1)}, {shamt}) % 0x100000000"


def emit_srai(insn: DecodedInsn, pc: int) -> str:
    if insn.rd == 0:
        return ""
    shamt = insn.shamt & 0x1F
    return f"{_rreg(insn.rd)} = bit.arshift({_rreg(insn.rs1)}, {shamt}) % 0x100000000"


# -- OP (RV32I + RV32M) ----------------------------------------------------

def emit_add(insn, pc):
    if insn.rd == 0: return ""
    return f"{_rreg(insn.rd)} = ({_rreg(insn.rs1)} + {_rreg(insn.rs2)}) % 0x100000000"


def emit_sub(insn, pc):
    if insn.rd == 0: return ""
    return f"{_rreg(insn.rd)} = ({_rreg(insn.rs1)} - {_rreg(insn.rs2)}) % 0x100000000"


def emit_sll(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"{_rreg(insn.rd)} = ({_rreg(insn.rs1)} * "
        f"2^({_rreg(insn.rs2)} % 0x20)) % 0x100000000"
    )


def emit_slt(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}\n"
        f"  if a >= 0x80000000 then a = a - 0x100000000 end\n"
        f"  if b >= 0x80000000 then b = b - 0x100000000 end\n"
        f"  {_rreg(insn.rd)} = (a < b) and 1 or 0 end"
    )


def emit_sltu(insn, pc):
    if insn.rd == 0: return ""
    return f"{_rreg(insn.rd)} = ({_rreg(insn.rs1)} < {_rreg(insn.rs2)}) and 1 or 0"


def emit_xor(insn, pc):
    if insn.rd == 0: return ""
    return f"{_rreg(insn.rd)} = bit.bxor({_rreg(insn.rs1)}, {_rreg(insn.rs2)}) % 0x100000000"


def emit_srl(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"{_rreg(insn.rd)} = bit.rshift({_rreg(insn.rs1)}, "
        f"{_rreg(insn.rs2)} % 0x20) % 0x100000000"
    )


def emit_sra(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"{_rreg(insn.rd)} = bit.arshift({_rreg(insn.rs1)}, "
        f"{_rreg(insn.rs2)} % 0x20) % 0x100000000"
    )


def emit_or(insn, pc):
    if insn.rd == 0: return ""
    return f"{_rreg(insn.rd)} = bit.bor({_rreg(insn.rs1)}, {_rreg(insn.rs2)}) % 0x100000000"


def emit_and(insn, pc):
    if insn.rd == 0: return ""
    return f"{_rreg(insn.rd)} = bit.band({_rreg(insn.rs1)}, {_rreg(insn.rs2)})"


def emit_mul(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}\n"
        f"  if a >= 0x80000000 then a = a - 0x100000000 end\n"
        f"  if b >= 0x80000000 then b = b - 0x100000000 end\n"
        f"  {_rreg(insn.rd)} = (a * b) % 0x100000000 end"
    )


def emit_mulh(insn, pc):
    if insn.rd == 0: return ""
    # Mirrors the legacy RVEMU_BaseInstructions_OP MULH path bit-for-bit,
    # including its ``RVEMU_set_unsign_64`` bug: because BitOp's
    # ``bit.lshift(1, 64)`` masks the shift amount to 5 bits and produces
    # 1, legacy's set_unsign_64 is effectively ``p + 1`` for negative p
    # rather than ``p + 2^64``.  The "correct" 2^64 form looks right but
    # hits IEEE-754 precision loss in Lua: ``(-2) + 2^64`` rounds up to
    # ``2^64`` exactly because 2^64 - 2 has too many significant bits for
    # a 53-bit mantissa, then ``math.floor(2^64 / 2^32) = 2^32``, which
    # propagates a spurious bit through the next ``slli`` in sequences
    # like Doom's ``FixedMul``.  Matching legacy's ``p + 1`` keeps both
    # paths arithmetically identical and lets the lockstep verifier
    # confirm parity end-to-end.
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}\n"
        f"  if a >= 0x80000000 then a = a - 0x100000000 end\n"
        f"  if b >= 0x80000000 then b = b - 0x100000000 end\n"
        f"  local p = a * b\n"
        f"  if p < 0 then p = p + 1 end\n"
        f"  {_rreg(insn.rd)} = math.floor(p / 0x100000000) end"
    )


def emit_mulhsu(insn, pc):
    if insn.rd == 0: return ""
    # Same ``p + 1`` legacy-compat shim as emit_mulh above -- see that
    # comment for the precision-loss rationale.
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}\n"
        f"  if a >= 0x80000000 then a = a - 0x100000000 end\n"
        f"  local p = a * b\n"
        f"  if p < 0 then p = p + 1 end\n"
        f"  {_rreg(insn.rd)} = math.floor(p / 0x100000000) end"
    )


def emit_mulhu(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"{_rreg(insn.rd)} = math.floor(("
        f"{_rreg(insn.rs1)} * {_rreg(insn.rs2)}) / 0x100000000)"
    )


def emit_div(insn, pc):
    # Matches the legacy interpreter's behaviour including its math.floor
    # rounding on negative results.  Divergence here would break the
    # differential validator in Phase 2.
    if insn.rd == 0: return ""
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}; local r\n"
        f"  if b == 0 then r = 0xFFFFFFFF\n"
        f"  else\n"
        f"    if a >= 0x80000000 then a = a - 0x100000000 end\n"
        f"    if b >= 0x80000000 then b = b - 0x100000000 end\n"
        f"    local q = math.floor(a / b)\n"
        f"    if q < 0 then q = q + 0x100000000 end\n"
        f"    r = q\n"
        f"  end\n"
        f"  {_rreg(insn.rd)} = r end"
    )


def emit_divu(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}; local r\n"
        f"  if b == 0 then r = 0xFFFFFFFF\n"
        f"  else r = math.floor(a / b) end\n"
        f"  {_rreg(insn.rd)} = r end"
    )


def emit_rem(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}; local r\n"
        f"  if b == 0 then r = a\n"
        f"  else\n"
        f"    if a >= 0x80000000 then a = a - 0x100000000 end\n"
        f"    if b >= 0x80000000 then b = b - 0x100000000 end\n"
        f"    local rem = a % b\n"
        f"    if rem < 0 then rem = rem + 0x100000000 end\n"
        f"    r = rem\n"
        f"  end\n"
        f"  {_rreg(insn.rd)} = r end"
    )


def emit_remu(insn, pc):
    if insn.rd == 0: return ""
    return (
        f"do local a = {_rreg(insn.rs1)}; local b = {_rreg(insn.rs2)}; local r\n"
        f"  if b == 0 then r = a else r = a % b end\n"
        f"  {_rreg(insn.rd)} = r end"
    )


# -- MISC-MEM --------------------------------------------------------------

def emit_fence(insn: DecodedInsn, pc: int) -> str:
    return ""


def emit_fence_i(insn: DecodedInsn, pc: int) -> str:
    return ""


# -- SYSTEM ----------------------------------------------------------------

def emit_ecall(insn: DecodedInsn, pc: int) -> str:
    return (
        "sync_out(); ecall(R17); sync_in()\n"
        f"pc = {_hex(pc + 4)}\n"
        "return"
    )


def emit_ebreak(insn: DecodedInsn, pc: int) -> str:
    return (
        "bootState.is_running = 0\n"
        f"pc = {_hex(pc + 4)}\n"
        "return"
    )


def _emit_csr_common(insn: DecodedInsn, pc: int, update_expr: str,
                     rs1_is_imm: bool) -> str:
    csr = _u32(insn.imm) & 0xFFF
    # rs1 field may hold a register index OR a 5-bit immediate depending on
    # opcode variant; the decoder stores whichever one is relevant in rs1.
    src = str(insn.rs1) if rs1_is_imm else _rreg(insn.rs1)
    rd_assign = ""
    if insn.rd != 0:
        rd_assign = f"  {_rreg(insn.rd)} = csr\n"
    return (
        f"do local csr = bootState.CPU:ReadCSR({csr})\n"
        f"  bootState.CPU:WriteCSR({csr}, {update_expr.format(src=src)})\n"
        f"{rd_assign}"
        f"end"
    )


def emit_csrrw(insn, pc):
    return _emit_csr_common(insn, pc, "{src}", rs1_is_imm=False)


def emit_csrrs(insn, pc):
    return _emit_csr_common(insn, pc, "bit.bor(csr, {src})", rs1_is_imm=False)


def emit_csrrc(insn, pc):
    return _emit_csr_common(insn, pc, "bit.band(csr, bit.bnot({src}))",
                             rs1_is_imm=False)


def emit_csrrwi(insn, pc):
    return _emit_csr_common(insn, pc, "{src}", rs1_is_imm=True)


def emit_csrrsi(insn, pc):
    return _emit_csr_common(insn, pc, "bit.bor(csr, {src})", rs1_is_imm=True)


def emit_csrrci(insn, pc):
    return _emit_csr_common(insn, pc, "bit.band(csr, bit.bnot({src}))",
                             rs1_is_imm=True)


# -- FP (bridged) ----------------------------------------------------------

def emit_flw(insn, pc):
    return (
        f"fpu.flw({insn.rd}, {_rreg(insn.rs1)} + {_imm(insn.imm)})"
    )


def emit_fld(insn, pc):
    return (
        f"fpu.fld({insn.rd}, {_rreg(insn.rs1)} + {_imm(insn.imm)})"
    )


def emit_fsw(insn, pc):
    return (
        f"fpu.fsw({insn.rs2}, {_rreg(insn.rs1)} + {_imm(insn.imm)})"
    )


def emit_fsd(insn, pc):
    return (
        f"fpu.fsd({insn.rs2}, {_rreg(insn.rs1)} + {_imm(insn.imm)})"
    )


def emit_fmadd(insn, pc):
    return (
        f"fpu.fmadd({insn.rd}, {insn.funct3}, {insn.rs1}, {insn.rs2}, "
        f"{insn.funct2}, {insn.rs3})"
    )


def emit_fmsub(insn, pc):
    return (
        f"fpu.fmsub({insn.rd}, {insn.funct3}, {insn.rs1}, {insn.rs2}, "
        f"{insn.funct2}, {insn.rs3})"
    )


def emit_fnmsub(insn, pc):
    return (
        f"fpu.fnmsub({insn.rd}, {insn.funct3}, {insn.rs1}, {insn.rs2}, "
        f"{insn.funct2}, {insn.rs3})"
    )


def emit_fnmadd(insn, pc):
    return (
        f"fpu.fnmadd({insn.rd}, {insn.funct3}, {insn.rs1}, {insn.rs2}, "
        f"{insn.funct2}, {insn.rs3})"
    )


def emit_op_fp(insn, pc):
    # OP-FP packs an entire mini-ISA (FADD, FSUB, FCLASS, FCVT, ...).  We
    # hand the funct fields through and let the Lua-side bridge dispatch.
    return (
        f"fpu.op_fp({insn.rd}, {insn.funct3}, {insn.rs1}, {insn.rs2}, "
        f"{insn.funct7})"
    )


# ---------------------------------------------------------------------------
# Dispatch table
# ---------------------------------------------------------------------------

EMITTERS = {
    # U
    "LUI": emit_lui, "AUIPC": emit_auipc,
    # J / I jumps
    "JAL": emit_jal, "JALR": emit_jalr,
    # B
    "BEQ": emit_beq, "BNE": emit_bne, "BLT": emit_blt, "BGE": emit_bge,
    "BLTU": emit_bltu, "BGEU": emit_bgeu,
    # LOAD
    "LB": emit_lb, "LH": emit_lh, "LW": emit_lw,
    "LBU": emit_lbu, "LHU": emit_lhu,
    # STORE
    "SB": emit_sb, "SH": emit_sh, "SW": emit_sw,
    # OP-IMM
    "ADDI": emit_addi, "SLTI": emit_slti, "SLTIU": emit_sltiu,
    "XORI": emit_xori, "ORI": emit_ori, "ANDI": emit_andi,
    "SLLI": emit_slli, "SRLI": emit_srli, "SRAI": emit_srai,
    # OP
    "ADD": emit_add, "SUB": emit_sub, "SLL": emit_sll, "SLT": emit_slt,
    "SLTU": emit_sltu, "XOR": emit_xor, "SRL": emit_srl, "SRA": emit_sra,
    "OR": emit_or, "AND": emit_and,
    # RV32M
    "MUL": emit_mul, "MULH": emit_mulh, "MULHSU": emit_mulhsu,
    "MULHU": emit_mulhu, "DIV": emit_div, "DIVU": emit_divu,
    "REM": emit_rem, "REMU": emit_remu,
    # MISC-MEM
    "FENCE": emit_fence, "FENCE_I": emit_fence_i,
    # SYSTEM
    "ECALL": emit_ecall, "EBREAK": emit_ebreak,
    "CSRRW": emit_csrrw, "CSRRS": emit_csrrs, "CSRRC": emit_csrrc,
    "CSRRWI": emit_csrrwi, "CSRRSI": emit_csrrsi, "CSRRCI": emit_csrrci,
    # FP
    "FLW": emit_flw, "FLD": emit_fld, "FSW": emit_fsw, "FSD": emit_fsd,
    "FMADD": emit_fmadd, "FMSUB": emit_fmsub,
    "FNMSUB": emit_fnmsub, "FNMADD": emit_fnmadd,
    "OP_FP": emit_op_fp,
}


def emit_insn(insn: DecodedInsn, pc: int) -> str:
    """Dispatch a single instruction to its emitter.  Unknown opcodes
    degrade to a commented-out placeholder so the file still parses; the
    runtime fallback catches them."""
    emitter = EMITTERS.get(insn.op)
    if emitter is None:
        return f"-- UNSUPPORTED op={insn.op} raw=0x{insn.raw:08x} pc={_hex(pc)}"
    return emitter(insn, pc)


def is_codegen_supported(insn: DecodedInsn) -> bool:
    """True iff :data:`EMITTERS` has a dedicated handler for ``insn.op``.

    Used by the coverage tool (``aot_coverage.py``) to classify decoded
    instructions without forcing it to reimplement the dispatch table.
    """
    return insn.op in EMITTERS


# ---------------------------------------------------------------------------
# Block assembly
# ---------------------------------------------------------------------------

def emit_block_body(instructions) -> str:
    """Join per-instruction snippets into a block body.

    ``instructions`` is an iterable of ``(pc, DecodedInsn)`` tuples (the
    format produced by :class:`rv_bfs.Block`).

    The block is expected to end with a terminator; if it does not (e.g. an
    overflow in BFS), a synthetic ``pc = <last+4>; return`` tail is appended
    so the block closure always exits cleanly.
    """
    lines: List[str] = []
    last_pc = 0
    last_op: Optional[str] = None
    for pc, insn in instructions:
        last_pc = pc
        last_op = insn.op
        snippet = emit_insn(insn, pc)
        if snippet:
            lines.append(f"-- 0x{pc:08x} {insn.op}")
            lines.append(snippet)

    if last_op is None:
        return "return"

    if last_op not in _TERMINATOR_OPS:
        # Overflow / non-terminated block: append a safe fall-through.
        lines.append(f"pc = {_hex(last_pc + 4)}")
        lines.append("return")

    return "\n".join(lines)
