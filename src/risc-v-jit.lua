-- JIT code generation for RISC-V instructions
-- Mirrors the structure of rv32i-base-instructions.lua but generates Lua code strings

RVEMU_JIT = {}



-- Loads an immediate value into a register (LUI instruction).
function RVEMU_JIT.LUI(r_regs, w_regs, rd, imm_value)
    w_regs[rd] = true
    return function(code_lines, pc)
        code_lines[#code_lines + 1] = string.format("  r%d = 0x%x", rd, imm_value % 0x100000000)
        return true
    end
end

-- Adds an immediate value to the program counter and stores the result in a register (AUIPC instruction).
function RVEMU_JIT.AUIPC(r_regs, w_regs, rd, imm_value)
    w_regs[rd] = true
    return function(code_lines, pc)
        code_lines[#code_lines + 1] = string.format("  r%d = 0x%x", rd, (pc + imm_value) % 0x100000000)
        return true
    end
end

-- Jumps to a target address and stores the return address in a register (JAL instruction).
function RVEMU_JIT.JAL(r_regs, w_regs, rd, imm_value)
    if rd ~= 0 then
        w_regs[rd] = true
    end
    w_regs[33] = true  -- PC register
    return function(code_lines, pc)
        if rd ~= 0 then
            code_lines[#code_lines + 1] = string.format("  r%d = %d", rd, pc + 4)
        end
        code_lines[#code_lines + 1] = string.format("  r33 = %d", pc + imm_value)
        return true
    end
end

-- Jumps to a target address computed from a register and an immediate value (JALR instruction).
function RVEMU_JIT.JALR(r_regs, w_regs, rd, funct3, rs1, imm_value)
    r_regs[rs1] = true
    if rd ~= 0 then
        w_regs[rd] = true
    end
    w_regs[33] = true  -- PC register
    return function(code_lines, pc)
        if rd ~= 0 then
            code_lines[#code_lines + 1] = string.format("  r%d = %d", rd, pc + 4)
        end
        code_lines[#code_lines + 1] = string.format("  r33 = bit_band(r%d + %d, 0xFFFFFFFE)", rs1, imm_value)
        return true
    end
end

-- Performs a conditional branch based on register comparison (BRANCH instruction).
function RVEMU_JIT.BRANCH(r_regs, w_regs, funct3, rs1, rs2, imm_value)
    r_regs[rs1] = true
    r_regs[rs2] = true
    w_regs[33] = true  -- PC register
    return function(code_lines, pc)
        local test = bit.rshift(funct3, 1)
        
        if test == 0 then -- BEQ/BNE
            code_lines[#code_lines + 1] = string.format("  cond = r%d == r%d", rs1, rs2)
        elseif test == 2 then -- BLT/BGE
            code_lines[#code_lines + 1] = string.format("  op1 = RVEMU_set_sign(r%d, 32)", rs1)
            code_lines[#code_lines + 1] = string.format("  op2 = RVEMU_set_sign(r%d, 32)", rs2)
            code_lines[#code_lines + 1] = "  cond = op1 < op2"
        elseif test == 3 then -- BLTU/BGEU
            code_lines[#code_lines + 1] = string.format("  cond = r%d < r%d", rs1, rs2)
        else
            print("JIT: Invalid funct3 for BRANCH instruction: " .. funct3)
            return false
        end
        
        code_lines[#code_lines + 1] = string.format("  cond = bit_bxor(cond and 1 or 0, bit_band(%d, 1)) == 1", funct3)
        code_lines[#code_lines + 1] = "  if cond then"
        code_lines[#code_lines + 1] = string.format("    r33 = %d", pc + imm_value)
        code_lines[#code_lines + 1] = "  else"
        code_lines[#code_lines + 1] = string.format("    r33 = %d", pc + 4)
        code_lines[#code_lines + 1] = "  end"
        return true
    end
end

-- Loads a value from memory into a register (LOAD instruction).
function RVEMU_JIT.LOAD(r_regs, w_regs, rd, funct3, rs1, imm_value)
    r_regs[rs1] = true
    w_regs[rd] = true
    return function(code_lines, pc)
        if funct3 == 0x0 then -- LB
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = "  value = CPU_memory_Read_1(addr)"
            code_lines[#code_lines + 1] = "  value = RVEMU_set_unsign(RVEMU_set_sign(value, 8), 32)"
            code_lines[#code_lines + 1] = string.format("  r%d = value", rd)
            return true
        elseif funct3 == 0x1 then -- LH
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = "  value = CPU_memory_Read_2(addr)"
            code_lines[#code_lines + 1] = "  value = RVEMU_set_unsign(RVEMU_set_sign(value, 16), 32)"
            code_lines[#code_lines + 1] = string.format("  r%d = value", rd)
            return true
        elseif funct3 == 0x2 then -- LW
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = string.format("  r%d = CPU_memory_Read_4(addr)", rd)
            return true
        elseif funct3 == 0x4 then -- LBU
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = "  value = CPU_memory_Read_1(addr)"
            code_lines[#code_lines + 1] = string.format("  r%d = value", rd)
            return true
        elseif funct3 == 0x5 then -- LHU
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = "  value = CPU_memory_Read_2(addr)"
            code_lines[#code_lines + 1] = string.format("  r%d = value", rd)
            return true
        end
        print("JIT: Invalid funct3 for LOAD instruction: " .. funct3)
        return false
    end
end

-- Stores a value from a register into memory (STORE instruction).
function RVEMU_JIT.STORE(r_regs, w_regs, funct3, rs1, rs2, imm_value)
    r_regs[rs1] = true
    r_regs[rs2] = true
    return function(code_lines, pc)
        if funct3 == 0x0 then -- SB
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = string.format("  CPU_memory_Write_1(addr, r%d)", rs2)
            return true
        elseif funct3 == 0x1 then -- SH
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = string.format("  CPU_memory_Write_2(addr, r%d)", rs2)
            return true
        elseif funct3 == 0x2 then -- SW
            code_lines[#code_lines + 1] = string.format("  addr = r%d + %d", rs1, imm_value)
            code_lines[#code_lines + 1] = string.format("  CPU_memory_Write_4(addr, r%d)", rs2)
            return true
        end
        print("JIT: Invalid funct3 for STORE instruction: " .. funct3)
        return false
    end
end

-- Performs arithmetic operations with immediate values (OP-IMM instruction).
function RVEMU_JIT.OP_IMM(r_regs, w_regs, rd, funct3, rs1, imm_value)
    r_regs[rs1] = true
    w_regs[rd] = true
    return function(code_lines, pc)
        if funct3 == 0x0 then -- ADDI
            code_lines[#code_lines + 1] = string.format("  r%d = (r%d + 0x%x) %% 0x100000000", rd, rs1, imm_value)
            return true
        elseif funct3 == 0x2 then -- SLTI
            code_lines[#code_lines + 1] = string.format("  op1 = RVEMU_set_sign(r%d, 32)", rs1)
            code_lines[#code_lines + 1] = string.format("  op2 = RVEMU_set_sign(0x%x, 12)", imm_value)
            code_lines[#code_lines + 1] = string.format("  r%d = op1 < op2 and 1 or 0", rd)
            return true
        elseif funct3 == 0x3 then -- SLTIU
            code_lines[#code_lines + 1] = string.format("  r%d = r%d < 0x%x and 1 or 0", rd, rs1, imm_value)
            return true
        elseif funct3 == 0x4 then -- XORI
            code_lines[#code_lines + 1] = string.format("  r%d = bit_bxor(r%d, 0x%x)", rd, rs1, imm_value)
            return true
        elseif funct3 == 0x6 then -- ORI
            code_lines[#code_lines + 1] = string.format("  r%d = bit_bor(r%d, 0x%x)", rd, rs1, imm_value)
            return true
        elseif funct3 == 0x7 then -- ANDI
            code_lines[#code_lines + 1] = string.format("  r%d = bit_band(r%d, 0x%x)", rd, rs1, imm_value)
            return true
        elseif funct3 == 0x1 then -- SLLI
            code_lines[#code_lines + 1] = string.format("  r%d = (r%d * 2^(%d %% 0x20)) %% 0x100000000", rd, rs1, imm_value)
            return true
        elseif funct3 == 0x5 then
            if bit.rshift(imm_value, 10) == 0 then -- SRLI
                code_lines[#code_lines + 1] = string.format("  r%d = bit_rshift(r%d, %d %% 0x20)", rd, rs1, imm_value)
                return true
            else -- SRAI
                code_lines[#code_lines + 1] = string.format("  r%d = bit_arshift(r%d, %d %% 0x20)", rd, rs1, imm_value)
                return true
            end
        end
        print("JIT: Invalid funct3 for OP_IMM instruction: " .. funct3)
        return false
    end
end

-- Performs arithmetic operations between registers (OP instruction).
function RVEMU_JIT.OP(r_regs, w_regs, rd, funct3, rs1, rs2, funct7)
    r_regs[rs1] = true
    r_regs[rs2] = true
    w_regs[rd] = true
    return function(code_lines, pc)
        if funct3 == 0x0 then
            if funct7 == 0x00 then -- ADD
                code_lines[#code_lines + 1] = string.format("  r%d = (r%d + r%d) %% 0x100000000", rd, rs1, rs2)
                return true
            elseif funct7 == 0x20 then -- SUB
                code_lines[#code_lines + 1] = string.format("  r%d = (r%d - r%d) %% 0x100000000", rd, rs1, rs2)
                return true
            elseif funct7 == 0x01 then -- MUL (RV32M)
                code_lines[#code_lines + 1] = string.format("  op1 = RVEMU_set_sign(r%d, 32)", rs1)
                code_lines[#code_lines + 1] = string.format("  op2 = RVEMU_set_sign(r%d, 32)", rs2)
                code_lines[#code_lines + 1] = string.format("  r%d = (op1 * op2) %% 0x100000000", rd)
                return true
            end
        elseif funct3 == 0x1 then
            if funct7 == 0x00 then -- SLL
                code_lines[#code_lines + 1] = string.format("  r%d = (r%d * 2^(r%d %% 0x20)) %% 0x100000000", rd, rs1, rs2)
                return true
            elseif funct7 == 0x01 then -- MULH
                code_lines[#code_lines + 1] = string.format("  op1 = RVEMU_set_sign(r%d, 32)", rs1)
                code_lines[#code_lines + 1] = string.format("  op2 = RVEMU_set_sign(r%d, 32)", rs2)
                code_lines[#code_lines + 1] = string.format("  full_result = op1 * op2")
                code_lines[#code_lines + 1] = string.format("  r%d = math.floor(RVEMU_set_unsign(full_result, 64) / 0x100000000)", rd)
                return true
            end
        elseif funct3 == 0x2 then
            if funct7 == 0x00 then -- SLT
                code_lines[#code_lines + 1] = string.format("  op1 = RVEMU_set_sign(r%d, 32)", rs1)
                code_lines[#code_lines + 1] = string.format("  op2 = RVEMU_set_sign(r%d, 32)", rs2)
                code_lines[#code_lines + 1] = string.format("  r%d = op1 < op2 and 1 or 0", rd)
                return true
            elseif funct7 == 0x01 then -- MULHSU
                code_lines[#code_lines + 1] = string.format("  op1 = RVEMU_set_sign(r%d, 32)", rs1)
                code_lines[#code_lines + 1] = string.format("  op2 = r%d", rs2)
                code_lines[#code_lines + 1] = string.format("  full_result = op1 * op2")
                code_lines[#code_lines + 1] = string.format("  r%d = math.floor(RVEMU_set_unsign(full_result, 64) / 0x100000000)", rd)
                return true
            end
        elseif funct3 == 0x3 then
            if funct7 == 0x00 then -- SLTU
                code_lines[#code_lines + 1] = string.format("  r%d = r%d < r%d and 1 or 0", rd, rs1, rs2)
                return true
            elseif funct7 == 0x01 then -- MULHU
                code_lines[#code_lines + 1] = string.format("  full_result = r%d * r%d", rs1, rs2)
                code_lines[#code_lines + 1] = string.format("  r%d = math.floor(full_result / 0x100000000)", rd)
                return true
            end
        elseif funct3 == 0x4 then
            if funct7 == 0x00 then -- XOR
                code_lines[#code_lines + 1] = string.format("  r%d = bit_bxor(r%d, r%d)", rd, rs1, rs2)
                return true
            elseif funct7 == 0x01 then -- DIV
                code_lines[#code_lines + 1] = string.format("  if r%d == 0 then", rs2)
                code_lines[#code_lines + 1] = string.format("    r%d = 0xFFFFFFFF", rd)
                code_lines[#code_lines + 1] = "  else"
                code_lines[#code_lines + 1] = string.format("    op1 = RVEMU_set_sign(r%d, 32)", rs1)
                code_lines[#code_lines + 1] = string.format("    op2 = RVEMU_set_sign(r%d, 32)", rs2)
                code_lines[#code_lines + 1] = string.format("    r%d = RVEMU_set_unsign(math.floor(op1 / op2), 32)", rd)
                code_lines[#code_lines + 1] = "  end"
                return true
            end
        elseif funct3 == 0x5 then
            if funct7 == 0x00 then -- SRL
                code_lines[#code_lines + 1] = string.format("  r%d = bit_rshift(r%d, r%d %% 0x20)", rd, rs1, rs2)
                return true
            elseif funct7 == 0x20 then -- SRA
                code_lines[#code_lines + 1] = string.format("  r%d = bit_arshift(r%d, r%d %% 0x20)", rd, rs1, rs2)
                return true
            elseif funct7 == 0x01 then -- DIVU
                code_lines[#code_lines + 1] = string.format("  if r%d == 0 then", rs2)
                code_lines[#code_lines + 1] = string.format("    r%d = 0xFFFFFFFF", rd)
                code_lines[#code_lines + 1] = "  else"
                code_lines[#code_lines + 1] = string.format("    r%d = RVEMU_set_unsign(math.floor(r%d / r%d), 32)", rd, rs1, rs2)
                code_lines[#code_lines + 1] = "  end"
                return true
            end
        elseif funct3 == 0x6 then
            if funct7 == 0x00 then -- OR
                code_lines[#code_lines + 1] = string.format("  r%d = bit_bor(r%d, r%d)", rd, rs1, rs2)
                return true
            elseif funct7 == 0x01 then -- REM
                code_lines[#code_lines + 1] = string.format("  if r%d == 0 then", rs2)
                code_lines[#code_lines + 1] = string.format("    r%d = r%d", rd, rs1)
                code_lines[#code_lines + 1] = "  else"
                code_lines[#code_lines + 1] = string.format("    op1 = RVEMU_set_sign(r%d, 32)", rs1)
                code_lines[#code_lines + 1] = string.format("    op2 = RVEMU_set_sign(r%d, 32)", rs2)
                code_lines[#code_lines + 1] = string.format("    r%d = RVEMU_set_unsign(op1 %% op2, 32)", rd)
                code_lines[#code_lines + 1] = "  end"
                return true
            end
        elseif funct3 == 0x7 then
            if funct7 == 0x00 then -- AND
                code_lines[#code_lines + 1] = string.format("  r%d = bit_band(r%d, r%d)", rd, rs1, rs2)
                return true
            elseif funct7 == 0x01 then -- REMU
                code_lines[#code_lines + 1] = string.format("  if r%d == 0 then", rs2)
                code_lines[#code_lines + 1] = string.format("    r%d = r%d", rd, rs1)
                code_lines[#code_lines + 1] = "  else"
                code_lines[#code_lines + 1] = string.format("    r%d = RVEMU_set_unsign(r%d %% r%d, 32)", rd, rs1, rs2)
                code_lines[#code_lines + 1] = "  end"
                return true
            end
        end
        print("JIT: Invalid funct3/funct7 for OP instruction: " .. funct3 .. "/" .. funct7)
        return false
    end
end 