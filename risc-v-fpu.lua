function FPU_Load(CPU, rd, funct3, rs1, imm_value)
    local addr = CPU:LoadRegister(rs1) + imm_value
    local value = CPU.memory:Read(addr, 4)
    CPU.fregisters[rd].value = value
end

function FPU_Store(CPU, funct3, rs1, rs2, imm_value)
    local addr = CPU:LoadRegister(rs1) + imm_value
    local value = CPU.fregisters[rs2].value
    CPU.memory:Write(addr, value, 4)
end

function FPU_FMADD(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local op1 = CPU.fregisters[rs1].value
    local op2 = CPU.fregisters[rs2].value
    local op3 = CPU.fregisters[rs3].value
    local result = (op1 * op2) + op3
    CPU.fregisters[rd].value = result
end

function FPU_FMSUB(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local op1 = CPU.fregisters[rs1].value
    local op2 = CPU.fregisters[rs2].value
    local op3 = CPU.fregisters[rs3].value
    local result = (op1 * op2) - op3
    CPU.fregisters[rd].value = result
end

function FPU_FNMSUB(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local op1 = CPU.fregisters[rs1].value
    local op2 = CPU.fregisters[rs2].value
    local op3 = CPU.fregisters[rs3].value
    local result = -(op1 * op2) + op3
    CPU.fregisters[rd].value = result
end

function FPU_FNMADD(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local op1 = CPU.fregisters[rs1].value
    local op2 = CPU.fregisters[rs2].value
    local op3 = CPU.fregisters[rs3].value
    local result = -(op1 * op2) - op3
    CPU.fregisters[rd].value = result
end

function FPU_OP_FP(CPU, rd, funct3, rs1, rs2, funct7)
    local op1 = CPU.fregisters[rs1].value
    local op2 = CPU.fregisters[rs2].value
    local result = nil

    if funct7 == 0x00 then
        if funct3 == 0x0 then -- FADD.S
            result = op1 + op2
        elseif funct3 == 0x1 then -- FSUB.S
            result = op1 - op2
        elseif funct3 == 0x2 then -- FMUL.S
            result = op1 * op2
        elseif funct3 == 0x3 then -- FDIV.S
            result = op1 / op2
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct7 == 0x01 then
        if funct3 == 0x0 then -- FADD.D
            result = op1 + op2
        elseif funct3 == 0x1 then -- FSUB.D
            result = op1 - op2
        elseif funct3 == 0x2 then -- FMUL.D
            result = op1 * op2
        elseif funct3 == 0x3 then -- FDIV.D
            result = op1 / op2
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct7 == 0x20 then -- FMIN/MAX
        if funct3 == 0x0 then -- FMIN.S
            result = math.min(op1, op2)
        elseif funct3 == 0x1 then -- FMAX.S
            result = math.max(op1, op2)
        elseif funct3 == 0x2 then -- FMIN.D
            result = math.min(op1, op2)
        elseif funct3 == 0x3 then -- FMAX.D
            result = math.max(op1, op2)
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct7 == 0x60 then -- Convert FP to Integer
        if funct3 == 0x0 then -- FCVT.W.S
            result = math.floor(op1)
        elseif funct3 == 0x1 then -- FCVT.WU.S
            result = math.floor(math.abs(op1))
        elseif funct3 == 0x2 then -- FCVT.W.D
            result = math.floor(op1)
        elseif funct3 == 0x3 then -- FCVT.WU.D
            result = math.floor(math.abs(op1))
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct7 == 0x68 then -- Convert Integer to FP
        if funct3 == 0x0 then -- FCVT.S.W
            result = tonumber(op1)
        elseif funct3 == 0x1 then -- FCVT.S.WU
            result = tonumber(math.abs(op1))
        elseif funct3 == 0x2 then -- FCVT.D.W
            result = tonumber(op1)
        elseif funct3 == 0x3 then -- FCVT.D.WU
            result = tonumber(math.abs(op1))
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    else
        assert(false, "Unsupported FP operation funct7: " .. tostring(funct7))
    end

    CPU.fregisters[rd].value = result
end