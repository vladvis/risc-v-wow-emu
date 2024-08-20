INF = 1/0
NAN = 0/0
INF_INV = -1/0
MINUS_Z = 0/INF_INV

local function get_sign(x)
    return x >= 0 and 1 or -1
end

function FPU_Load(CPU, rd, funct3, rs1, imm_value)
    local addr = CPU:LoadRegister(rs1) + imm_value
    local value = nil

    if funct3 == 0x2 then
        -- FLW: Load 32-bit float
        value = CPU.memory:Read(addr, 'float')
    elseif funct3 == 0x3 then
        -- FLD: Load 64-bit double
        value = CPU.memory:Read(addr, 'double')
    else
        assert(false, "Unsupported FPU load funct3: " .. tostring(funct3))
    end

    CPU.fregisters[rd].value = value
end

function FPU_Store(CPU, funct3, rs1, rs2, imm_value)
    local addr = CPU:LoadRegister(rs1) + imm_value
    local value = CPU.fregisters[rs2].value

    if funct3 == 0x2 then
        -- FSW: Store 32-bit float
        CPU.memory:Write(addr, value, 'float')
    elseif funct3 == 0x3 then
        -- FSD: Store 64-bit double
        CPU.memory:Write(addr, value, 'double')
    else
        assert(false, "Unsupported FPU store funct3: " .. tostring(funct3))
    end
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

    local is_double = bit.band(funct7, 1)
    local funct6 = bit.rshift(funct7, 1)

    if funct6 == 0x00 then -- FADD.S | FADD.D
        result = op1 + op2
    elseif funct6 == 0x02 then -- FSUB.S | FSUB.D
        result = op1 - op2
    elseif funct6 == 0x04 then -- FMUL.S | FMUL.D
        result = op1 * op2
    elseif funct6 == 0x06 then -- FDIV.S | FDIV.D
        result = op1 / op2
    elseif funct6 == 0x0a then
        if funct3 == 0x0 then -- FMIN.S | FMIN.D
            result = math.min(op1, op2)
        elseif funct3 == 0x1 then -- FMAX.S | FMAX.D
            result = math.max(op1, op2)
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct6 == 0x08 then
        if funct3 == 0x00 then -- FSGNJ.S | FSGNJ.D
            result = math.abs(op1) * get_sign(op2)
        elseif funct3 == 0x01 then -- FSGNJN.S | FSGNJN.D
            result = - math.abs(op1) * get_sign(op2)
        elseif funct3 == 0x02 then -- FSGNJX.S | FSGNJX.D
            result = op1 * get_sign(op2)
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct6 == 0x16 then -- FSQRT.S | FSQRT.D
        result = math.sqrt(op1)
    elseif funct6 == 0x28 then -- (ATTENTION: rd is integer)
        if funct3 == 0x00 then -- FLE.S | FLE.D
            result = (op1 <= op2) and 1 or 0
        elseif funct3 == 0x01 then -- FLT.S | FLT.D
            result = (op1 < op2) and 1 or 0
        elseif funct3 == 0x02 then -- FEQ.S | FEQ.D
            result = (op1 == op2) and 1 or 0
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct6 == 0x10 then -- FCVT.S.D | FCVT.D.S
        result = op1
    elseif funct6 == 0x30 then -- (ATTENTION: rd is integer)
        local rm = funct3 == 0x07 and CPU.fcsr.rm or funct3
        if rm == 0x00 then -- Round to Nearest, ties to Even
            local x = op1 - math.floor(op1)
            if x == 0.5 and (math.floor(op1) % 2) == 0 then
                x = 0.4
            end
            result = x > 0.5 and math.ceil(op1) or math.floor(op1)
        elseif rm == 0x01 then -- Round towards Zero
            result = op1 >= 0 and math.floor(op1) or math.ceil(op1)
        elseif rm == 0x02 then -- Round Down (towards −∞)
            result = math.floor(op1)
        elseif rm == 0x03 then -- Round Up (towards +∞)
            result = math.ceil(op1)
        elseif rm == 0x04 then -- Round to Nearest, ties to Max Magnitude
            local x = op1 - math.floor(op1)
            if x == 0.5 and op1 < 0 then
                x = 0.4
            end
            result = x > 0.5 and math.ceil(op1) or math.floor(op1)
        else
            assert(false, "Invalid Rounding Mode value: " .. tostring(rm))
        end
        if rs2 == 0x00 then -- FCVT.W.S | FCVT.W.D
            result = math.max(-0x80000000, result)
            result = math.min(0x7FFFFFFF, result)
            result = set_unsign(result, 32)
        elseif rs2 == 0x01 then -- FCVT.WU.S | FCVT.WU.D
            result = math.max(0, result)
            result = math.min(0xFFFFFFFF, result)
        else
            assert(false, "invalid rs2 value: " .. tostring(rs2))
        end
    elseif funct6 == 0x34 then -- (FCVT.S.W | FCVT.S.WU) | (FCVT.D.W | FCVT.D.WU) (ATTENTION: rs1 is integer)
        if rs2 == 0x00 then -- FCVT.S.W | FCVT.D.W
            result = set_sign(CPU:LoadRegister(rs1), 32)
        elseif rs2 == 0x01 then -- FCVT.S.WU | FCVT.D.WU
            result = CPU:LoadRegister(rs1)
        else
            assert(false, "invalid rs2 value: " .. tostring(rs2))
        end
    elseif funct6 == 0x38 then -- (ATTENTION: rd is integer)
        if funct3 == 0x00 then -- FMV.X.W
            result = float_to_bits(op1)
        elseif funct3 == 0x01 then -- FCLASS.S | FCLASS.D
            if op1 == INF_INV then
                result = 0
            elseif op1 == MINUS_Z then
                result = 3
            elseif op1 == 0 then
                result = 4
            elseif op1 == INF then
                result = 7
            elseif op1 == NAN then
                result = 8
            elseif op1 < 0 then
                result = 1
            elseif op1 > 0 then
                result = 6
            else
                assert(false, "WOOT?")
            end
        else
            assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
        end
    elseif funct6 == 0x3c then -- FMV.W.X (ATTENTION: rs1 is integer)
        result = bits_to_float(CPU:LoadRegister(rs1))
    else
        assert(false, "Unsupported FP operation funct7: " .. tostring(funct7) .. " " .. tostring(funct6))
    end

    if funct6 == 0x38 or funct6 == 0x30 or funct6 == 0x28 then
        CPU:StoreRegister(rd, result)
    else
        CPU.fregisters[rd].value = result
    end
end