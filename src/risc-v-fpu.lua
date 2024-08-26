RVEMU_INF = 1/0
RVEMU_NAN = 0/0
RVEMU_INF_INV = -1/0
RVEMU_MINUS_Z = 0/RVEMU_INF_INV

local function get_sign(x)
    return x >= 0 and 1 or -1
end

-- Loads a floating-point value from memory into a floating-point register.
-- @param CPU The CPU object.
-- @param rd The destination floating-point register.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the address.
-- @param imm_value The immediate value for the address offset.
function RVEMU_FPU_Load(CPU, rd, funct3, rs1, imm_value)
    local registers = CPU.registers
    return function()
        local addr = CPU:LoadRegister(rs1) + imm_value
        local value = nil

        if funct3 == 0x2 then
            -- FLW: Load 32-bit float
            value = CPU.memory:Read(addr, 'float')
        elseif funct3 == 0x3 then
            -- FLD: Load 64-bit double
            value = CPU.memory:Read(addr, 'double')
        else
            --assert(false, "Unsupported FPU load funct3: " .. tostring(funct3))
        end

        CPU.fregisters[rd].value = value
        registers.pc = registers.pc + 4
    end
end

-- Stores a floating-point value from a floating-point register into memory.
-- @param CPU The CPU object.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the address.
-- @param rs2 The source floating-point register for the value.
-- @param imm_value The immediate value for the address offset.
function RVEMU_FPU_Store(CPU, funct3, rs1, rs2, imm_value)
    local registers = CPU.registers
    return function()

        local addr = CPU:LoadRegister(rs1) + imm_value
        local value = CPU.fregisters[rs2].value

        if funct3 == 0x2 then
            -- FSW: Store 32-bit float
            CPU.memory:Write(addr, value, 'float')
        elseif funct3 == 0x3 then
            -- FSD: Store 64-bit double
            CPU.memory:Write(addr, value, 'double')
        else
            --assert(false, "Unsupported FPU store funct3: " .. tostring(funct3))
        end
        registers.pc = registers.pc + 4
    end
end

-- Performs a fused multiply-add operation on floating-point registers.
-- @param CPU The CPU object.
-- @param rd The destination floating-point register.
-- @param funct3 The function code for the operation.
-- @param rs1 The first source floating-point register.
-- @param rs2 The second source floating-point register.
-- @param funct2 The function code for the operation.
-- @param rs3 The third source floating-point register.
function RVEMU_FPU_FMADD(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local registers = CPU.registers
    return function()

        local op1 = CPU.fregisters[rs1].value
        local op2 = CPU.fregisters[rs2].value
        local op3 = CPU.fregisters[rs3].value
        local result = (op1 * op2) + op3
        CPU.fregisters[rd].value = result
        registers.pc = registers.pc + 4
    end
end

-- Performs a fused multiply-subtract operation on floating-point registers.
-- @param CPU The CPU object.
-- @param rd The destination floating-point register.
-- @param funct3 The function code for the operation.
-- @param rs1 The first source floating-point register.
-- @param rs2 The second source floating-point register.
-- @param funct2 The function code for the operation.
-- @param rs3 The third source floating-point register.
function RVEMU_FPU_FMSUB(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local registers = CPU.registers
    return function()
        local op1 = CPU.fregisters[rs1].value
        local op2 = CPU.fregisters[rs2].value
        local op3 = CPU.fregisters[rs3].value
        local result = (op1 * op2) - op3
        CPU.fregisters[rd].value = result
        registers.pc = registers.pc + 4
    end
end

-- Performs a fused negative multiply-subtract operation on floating-point registers.
-- @param CPU The CPU object.
-- @param rd The destination floating-point register.
-- @param funct3 The function code for the operation.
-- @param rs1 The first source floating-point register.
-- @param rs2 The second source floating-point register.
-- @param funct2 The function code for the operation.
-- @param rs3 The third source floating-point register.
function RVEMU_FPU_FNMSUB(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local registers = CPU.registers
    return function()
        local op1 = CPU.fregisters[rs1].value
        local op2 = CPU.fregisters[rs2].value
        local op3 = CPU.fregisters[rs3].value
        local result = -(op1 * op2) + op3
        CPU.fregisters[rd].value = result
        registers.pc = registers.pc + 4
    end
end

-- Performs a fused negative multiply-add operation on floating-point registers.
-- @param CPU The CPU object.
-- @param rd The destination floating-point register.
-- @param funct3 The function code for the operation.
-- @param rs1 The first source floating-point register.
-- @param rs2 The second source floating-point register.
-- @param funct2 The function code for the operation.
-- @param rs3 The third source floating-point register.
function RVEMU_FPU_FNMADD(CPU, rd, funct3, rs1, rs2, funct2, rs3)
    local registers = CPU.registers
    return function()
        local op1 = CPU.fregisters[rs1].value
        local op2 = CPU.fregisters[rs2].value
        local op3 = CPU.fregisters[rs3].value
        local result = -(op1 * op2) - op3
        CPU.fregisters[rd].value = result
        registers.pc = registers.pc + 4
    end
end

-- Performs a floating-point operation on floating-point registers.
-- @param CPU The CPU object.
-- @param rd The destination floating-point register.
-- @param funct3 The function code for the operation.
-- @param rs1 The first source floating-point register.
-- @param rs2 The second source floating-point register.
-- @param funct7 The function code for the operation.
function RVEMU_FPU_OP_FP(CPU, rd, funct3, rs1, rs2, funct7)
    local registers = CPU.registers
    local RVEMU_set_unsign_32 = _RVEMU_set_unsign(32)
    local RVEMU_set_sign_32 = _RVEMU_set_sign(32)
    return function()
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
                --assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
            end
        elseif funct6 == 0x08 then
            if funct3 == 0x00 then -- FSGNJ.S | FSGNJ.D
                result = math.abs(op1) * get_sign(op2)
            elseif funct3 == 0x01 then -- FSGNJN.S | FSGNJN.D
                result = - math.abs(op1) * get_sign(op2)
            elseif funct3 == 0x02 then -- FSGNJX.S | FSGNJX.D
                result = op1 * get_sign(op2)
            else
                --assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
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
                --assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
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
                --assert(false, "Invalid Rounding Mode value: " .. tostring(rm))
            end
            if rs2 == 0x00 then -- FCVT.W.S | FCVT.W.D
                result = math.max(-0x80000000, result)
                result = math.min(0x7FFFFFFF, result)
                result = RVEMU_set_unsign_32(result)
            elseif rs2 == 0x01 then -- FCVT.WU.S | FCVT.WU.D
                result = math.max(0, result)
                result = math.min(0xFFFFFFFF, result)
            else
                --assert(false, "invalid rs2 value: " .. tostring(rs2))
            end
        elseif funct6 == 0x34 then -- (ATTENTION: rs1 is integer)
            if rs2 == 0x00 then -- FCVT.S.W | FCVT.D.W
                result = RVEMU_set_sign_32(CPU:LoadRegister(rs1))
            elseif rs2 == 0x01 then -- FCVT.S.WU | FCVT.D.WU
                result = CPU:LoadRegister(rs1)
            else
                --assert(false, "invalid rs2 value: " .. tostring(rs2))
            end
        elseif funct6 == 0x38 then -- (ATTENTION: rd is integer)
            if funct3 == 0x00 then -- FMV.X.W
                result = RVEMU_float_to_bits(op1)
            elseif funct3 == 0x01 then -- FCLASS.S | FCLASS.D
                if op1 == RVEMU_INF_INV then
                    result = bit.lshift(1, 0)
                elseif op1 == RVEMU_MINUS_Z then
                    result = bit.lshift(1, 3)
                elseif op1 == 0 then
                    result = bit.lshift(1, 4)
                elseif op1 == RVEMU_INF then
                    result = bit.lshift(1, 7)
                elseif op1 == RVEMU_NAN then
                    result = bit.lshift(1, 8)
                elseif op1 < 0 then
                    result = bit.lshift(1, 1)
                elseif op1 > 0 then
                    result = bit.lshift(1, 6)
                else
                    --assert(false, "WOOT?")
                end
            else
                --assert(false, "Unsupported FP operation funct3: " .. tostring(funct3))
            end
        elseif funct6 == 0x3c then -- FMV.W.X (ATTENTION: rs1 is integer)
            result = RVEMU_bits_to_float(CPU:LoadRegister(rs1))
        else
            --assert(false, "Unsupported FP operation funct7: " .. tostring(funct7) .. " " .. tostring(funct6))
        end

        if funct6 == 0x38 or funct6 == 0x30 or funct6 == 0x28 then
            CPU:StoreRegister(rd, result)
        else
            CPU.fregisters[rd].value = result
        end
        registers.pc = registers.pc + 4
    end
end
