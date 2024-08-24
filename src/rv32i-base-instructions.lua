function BaseInstructions_LUI(CPU, rd, imm_value)
    CPU:StoreRegister(rd, imm_value)
end

function BaseInstructions_AUIPC(CPU, rd, imm_value)
    CPU:StoreRegister(rd, CPU.registers.pc + imm_value)
end

function BaseInstructions_JAL(CPU, rd, imm_value)
    local return_address = CPU.registers.pc + 4
    CPU:StorePC(CPU.registers.pc + imm_value)

    if (rd ~= 0) then
        CPU:StoreRegister(rd, return_address)
    end
end

function BaseInstructions_JALR(CPU, rd, funct3, rs1, imm_value)
    --assert(funct3 == 0, "funct3 is reserved for JALR")

    local return_address = CPU.registers.pc + 4
    if (rd ~= 0) then
        CPU:StoreRegister(rd, return_address)
    end

    CPU:StorePC(bit.band(CPU:LoadRegister(rs1) + imm_value), 0xFFFFFFFE)
end

local function bool_to_number(value)
    return value == true and 1 or 0
end

function BaseInstructions_BRANCH(CPU, funct3, rs1, rs2, imm_value)
    local op1 = CPU:LoadRegister(rs1)
    local op2 = CPU:LoadRegister(rs2)
    local cond = nil

    local test = bit.rshift(funct3, 1)

    if test == 0 then -- BEQ | BNE
        cond = op1 == op2
    elseif test == 2 then -- BLT | BGE
        op1 = set_sign(op1, 32)
        op2 = set_sign(op2, 32)
        cond = op1 < op2
    elseif test == 3 then -- BLTU | BGEU
        cond = op1 < op2
    else
        --assert(false, "condition " .. tostring(funct3) .. " is not existed")
    end

    cond = bit.bxor(bool_to_number(cond), bit.band(funct3, 1))

    if cond == 1 then
        CPU:StorePC(CPU.registers.pc + imm_value)
    end
end

function BaseInstructions_LOAD(CPU, rd, funct3, rs1, imm_value)
    local addr = CPU:LoadRegister(rs1) + imm_value
    local value = nil
    if funct3 == 0 then -- LB
        value = CPU.memory:Read(addr, 1)
        value = set_unsign(set_sign(value, 8), 32)
    elseif funct3 == 1 then -- LH
        value = CPU.memory:Read(addr, 2)
        value = set_unsign(set_sign(value, 16), 32)
    elseif funct3 == 2 then -- LW
        value = CPU.memory:Read(addr, 4)
    elseif funct3 == 4 then -- LBU
        value = CPU.memory:Read(addr, 1)
    elseif funct3 == 5 then -- LHU
        value = CPU.memory:Read(addr, 2)
    else
        --assert(false, "load opcode " .. tostring(funct3) .. " is not existed")
    end

    CPU:StoreRegister(rd, value)
end

function BaseInstructions_STORE(CPU, funct3, rs1, rs2, imm_value)
    local addr = CPU:LoadRegister(rs1) + imm_value
    local value = CPU:LoadRegister(rs2)
    
    if funct3 == 0 then -- SB
        CPU.memory:Write(addr, value, 1)
    elseif funct3 == 1 then -- SH
        CPU.memory:Write(addr, value, 2)
    elseif funct3 == 2 then -- SW
        CPU.memory:Write(addr, value, 4)
    else
        --assert(false, "store opcode " .. tostring(funct3) .. " is not existed")
    end
end

function BaseInstructions_OP_IMM(CPU, rd, funct3, rs1, imm_value)
    local op1 = CPU:LoadRegister(rs1)
    local result = nil

    if funct3 == 0x0 then -- ADDI
        result = op1 + imm_value
    elseif funct3 == 0x2 then -- SLTI
        result = set_sign(op1, 32) < set_sign(imm_value, 12) and 1 or 0
    elseif funct3 == 0x3 then -- SLTIU
        result = op1 < imm_value and 1 or 0
    elseif funct3 == 0x4 then -- XORI
        result = bit.bxor(op1, imm_value)
    elseif funct3 == 0x6 then -- ORI
        result = bit.bor(op1, imm_value)
    elseif funct3 == 0x7 then -- ANDI
        result = bit.band(op1, imm_value)
    elseif funct3 == 0x1 then -- SLLI
        result = bit.lshift(op1, bit.band(imm_value, 0x1F))
    elseif funct3 == 0x5 then
        local shift_amount = bit.band(imm_value, 0x1F)
        if bit.rshift(imm_value, 10) == 0 then -- SRLI
            result = bit.rshift(op1, shift_amount)
        else -- SRAI
            result = bit.arshift(op1, shift_amount)
        end
    else
        --assert(false, "Unsupported OP_IMM funct3: " .. tostring(funct3))
    end

    CPU:StoreRegister(rd, result)
end

function BaseInstructions_OP(CPU, rd, funct3, rs1, rs2, funct7)
    local op1 = CPU:LoadRegister(rs1)
    local op2 = CPU:LoadRegister(rs2)
    local result = nil

    if funct3 == 0x0 then
        if funct7 == 0x00 then -- ADD
            result = bit.band(op1 + op2, 0xFFFFFFFF)
        elseif funct7 == 0x20 then -- SUB
            result = bit.band(op1 - op2, 0xFFFFFFFF)
        elseif funct7 == 0x01 then -- MUL (RV32M)
            local signed_op1 = set_sign(op1, 32)
            local signed_op2 = set_sign(op2, 32)
            result = bit.band(signed_op1 * signed_op2, 0xFFFFFFFF)
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x1 then
        if funct7 == 0x00 then -- SLL
            result = bit.lshift(op1, bit.band(op2, 0x1F))
        elseif funct7 == 0x01 then -- MULH
            local signed_op1 = set_sign(op1, 32)
            local signed_op2 = set_sign(op2, 32)
            local full_result = signed_op1 * signed_op2
            result = math.floor(set_unsign(full_result, 64) / 0x100000000)
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x2 then
        if funct7 == 0x00 then -- SLT
            result = bit.band(set_sign(op1, 32) < set_sign(op2, 32) and 1 or 0, 0xFFFFFFFF)
        elseif funct7 == 0x01 then -- MULHSU
            local signed_op1 = set_sign(op1, 32)
            local unsigned_op2 = op2
            local full_result = signed_op1 * unsigned_op2
            result = math.floor(set_unsign(full_result, 64) / 0x100000000)
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x3 then
        if funct7 == 0x00 then -- SLTU
            result = bit.band(op1 < op2 and 1 or 0, 0xFFFFFFFF)
        elseif funct7 == 0x01 then -- MULHU
            local full_result = op1 * op2
            result = math.floor(full_result / 0x100000000)
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x4 then
        if funct7 == 0x00 then -- XOR
            result = bit.bxor(op1, op2)
        elseif funct7 == 0x01 then -- DIV (RV32M)
            if op2 == 0 then
                result = 0xFFFFFFFF
            else
                result = set_unsign(math.floor(set_sign(op1, 32) / set_sign(op2, 32)), 32)
            end
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x5 then
        if funct7 == 0x00 then -- SRL
            result = bit.band(bit.rshift(op1, bit.band(op2, 0x1F)), 0xFFFFFFFF)
        elseif funct7 == 0x20 then -- SRA
            result = bit.band(bit.arshift(op1, bit.band(op2, 0x1F)), 0xFFFFFFFF)
        elseif funct7 == 0x01 then -- DIVU (RV32M)
            if op2 == 0 then
                result = 0xFFFFFFFF
            else
                result = set_unsign(math.floor(op1 / op2), 32)
            end
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x6 then
        if funct7 == 0x00 then -- OR
            result = bit.bor(op1, op2)
        elseif funct7 == 0x01 then -- REM (RV32M)
            if op2 == 0 then
                result = op1
            else
                local signed_op1 = set_sign(op1, 32)
                local signed_op2 = set_sign(op2, 32)
                result = set_unsign(signed_op1 % signed_op2, 32)
            end
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x7 then
        if funct7 == 0x00 then -- AND
            result = bit.band(op1, op2)
        elseif funct7 == 0x01 then -- REMU (RV32M)
            if op2 == 0 then
                result = op1
            else
                result = set_unsign(op1 % op2, 32)
            end
        else
            --assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    else
        --assert(false, "Unsupported OP funct3: " .. tostring(funct3))
    end

    CPU:StoreRegister(rd, result)
end

function BaseInstructions_MISC_MEM(CPU, rd, funct3, rs1, imm_value)
    if funct3 == 0x0 then -- FENCE
        return nil
    elseif funct3 == 0x1 then -- FENCE.I
        return nil
    else
        --assert(false, "Unsupported MISC_MEM funct3: " .. tostring(funct3))
    end
end

function BaseInstructions_SYSTEM(CPU, rd, funct3, rs1, imm_value)
    if funct3 == 0 then
        if imm_value == 0 then -- ECALL
            syscall_num = CPU:LoadRegister(17)
            handle_syscall(CPU, syscall_num)
        elseif imm_value == 1 then -- EBREAK
            print("EBREAK encountered at PC: " .. tostring(CPU.registers.pc))
            CPU.is_running = 0
        else
            --assert(false, "Unsupported SYSTEM funct12: " .. tostring(imm_value))
        end
    elseif funct3 == 0x1 then -- CSRRW
        local csr_value = CPU:ReadCSR(imm_value)
        CPU:WriteCSR(imm_value, CPU:LoadRegister(rs1))
        CPU:StoreRegister(rd, csr_value)
    elseif funct3 == 0x2 then -- CSRRS
        local csr_value = CPU:ReadCSR(imm_value)
        CPU:WriteCSR(imm_value, bit.bor(csr_value, CPU:LoadRegister(rs1)))
        CPU:StoreRegister(rd, csr_value)
    elseif funct3 == 0x3 then -- CSRRC
        local csr_value = CPU:ReadCSR(imm_value)
        CPU:WriteCSR(imm_value, bit.band(csr_value, bit.bnot(CPU:LoadRegister(rs1))))
        CPU:StoreRegister(rd, csr_value)
    elseif funct3 == 0x5 then -- CSRRWI
        local csr_value = CPU:ReadCSR(imm_value)
        CPU:WriteCSR(imm_value, rs1)
        CPU:StoreRegister(rd, csr_value)
    elseif funct3 == 0x6 then -- CSRRSI
        local csr_value = CPU:ReadCSR(imm_value)
        CPU:WriteCSR(imm_value, bit.bor(csr_value, rs1))
        CPU:StoreRegister(rd, csr_value)
    elseif funct3 == 0x7 then -- CSRRCI
        local csr_value = CPU:ReadCSR(imm_value)
        CPU:WriteCSR(imm_value, bit.band(csr_value, bit.bnot(rs1)))
        CPU:StoreRegister(rd, csr_value)
    else
        --assert(0, "Unsupported SYSTEM funct3: " .. tostring(funct3))
    end
end