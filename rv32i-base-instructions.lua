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
    assert(funct3 == 0, "funct3 is reserved for JALR")

    local return_address = CPU.registers.pc + 4
    if (rd ~= 0) then
        CPU:StoreRegister(rd, return_address)
    end

    CPU:StorePC(bit.band(CPU:LoadRegister(rs1) + imm_value), 0xFFFFFFFE)
end

local function bool_to_number(value)
    return value == true and 1 or value == false and 0
end

function BaseInstructions_BRANCH(CPU, funct3, rs1, rs2, imm_value)
    local op1 = CPU:LoadRegister(rs1)
    local op2 = CPU:LoadRegister(rs2)
    local cond = nil

    local test = bit.rshift(funct3, 1)

    if funct3 == 0 then -- BEQ | BNE
        cond = op1 == op2
    elseif funct3 == 2 then -- BLT | BGE
        op1 = set_sign(op1, 32)
        op2 = set_sign(op2, 32)
        cond = op1 < op2
    elseif funct3 == 3 then -- BLTU | BGEU
        cond = op1 < op2
    else
        assert(0, "condition " .. tostring(funct3) .. " is not existed")
    end

    cond = bit.bxor(bool_to_number(cond), bit.band(funct3, 1))

    if cond then
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
        assert(0, "load opcode " .. tostring(funct3) .. " is not existed")
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
        assert(0, "store opcode " .. tostring(funct3) .. " is not existed")
    end
end

function BaseInstructions_OP_IMM(CPU, rd, funct3, rs1, imm_value)

end

function BaseInstructions_OP(CPU, rd, funct3, rs1, rs2, funct7)

end

function BaseInstructions_MISC_MEM(CPU, rd, funct3, rs1, imm_value)

end

function BaseInstructions_SYSTEM(CPU, rd, funct3, rs1, imm_value)
    
end