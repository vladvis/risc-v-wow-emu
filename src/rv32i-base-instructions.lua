-- Sets the sign of a value based on the specified number of bits.
-- @param value The value to set the sign for.
-- @param bits The number of bits to consider for the sign.
-- @return The value with the sign set.
local function _RVEMU_set_sign(bits)
    local max_int = bit.lshift(1, bits - 1) - 1
    return function(value)
        if value > max_int then
            return value - (max_int + 1) * 2
        else
            return value
        end
    end
end
function RVEMU_set_sign(value, bits)
    return _RVEMU_set_sign(bits)(value)
end

-- Sets the unsigned representation of a value based on the specified number of bits.
-- @param value The value to set the unsigned representation for.
-- @param bits The number of bits to consider for the unsigned representation.
-- @return The unsigned representation of the value.
local function _RVEMU_set_unsign(bits)
    local max_uint = nil
    if bits == 32 then
        max_uint = 0x100000000
    else
        max_uint = bit.lshift(1, bits)
    end
    return function(value)
        if value < 0 then
            return value + max_uint
        else
            return value
        end
    end
end
function RVEMU_set_unsign(value, bits)
    return _RVEMU_set_unsign(bits)(value)
end

-- Loads an immediate value into a register (LUI instruction).
-- @param CPU The CPU object.
-- @param rd The destination register.
-- @param imm_value The immediate value to load.
function RVEMU_BaseInstructions_LUI(CPU, rd, imm_value)
    local registers = CPU.registers
    local CPU_StoreRegister = CPU.StoreRegister
    return function()
        CPU_StoreRegister(CPU, rd, imm_value)
        registers.pc = registers.pc + 4
    end
end

-- Adds an immediate value to the program counter and stores the result in a register (AUIPC instruction).
-- @param CPU The CPU object.
-- @param rd The destination register.
-- @param imm_value The immediate value to add to the program counter.
function RVEMU_BaseInstructions_AUIPC(CPU, rd, imm_value)
    local registers = CPU.registers
    local CPU_StoreRegister = CPU.StoreRegister
    return function()
        CPU_StoreRegister(CPU, rd, CPU.registers.pc + imm_value)
        registers.pc = registers.pc + 4
    end
end

-- Jumps to a target address and stores the return address in a register (JAL instruction).
-- @param CPU The CPU object.
-- @param rd The destination register for the return address.
-- @param imm_value The immediate value for the target address.
function RVEMU_BaseInstructions_JAL(CPU, rd, imm_value)
    local registers = CPU.registers

    local CPU_StoreRegister = CPU.StoreRegister
    return function()
        local return_address = CPU.registers.pc + 4
        if (rd ~= 0) then
            CPU_StoreRegister(CPU, rd, return_address)
        end
        registers.pc = registers.pc + imm_value
    end
end

-- Jumps to a target address computed from a register and an immediate value, and stores the return address in a register (JALR instruction).
-- @param CPU The CPU object.
-- @param rd The destination register for the return address.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the base address.
-- @param imm_value The immediate value for the address offset.
function RVEMU_BaseInstructions_JALR(CPU, rd, funct3, rs1, imm_value)
    -- assert(funct3 == 0, "funct3 is reserved for JALR")
    local registers = CPU.registers
    local CPU_StoreRegister = CPU.StoreRegister
    local CPU_LoadRegister = CPU.LoadRegister
    return function()

        local return_address = registers.pc + 4
        if (rd ~= 0) then
            CPU_StoreRegister(CPU, rd, return_address)
        end

        registers.pc = bit.band(CPU_LoadRegister(CPU, rs1) + imm_value) -- , 0xFFFFFFFE
    end
end

-- Performs a conditional branch based on the comparison of two registers (BRANCH instruction).
-- @param CPU The CPU object.
-- @param funct3 The function code for the operation.
-- @param rs1 The first source register for the comparison.
-- @param rs2 The second source register for the comparison.
-- @param imm_value The immediate value for the branch target address.
function RVEMU_BaseInstructions_BRANCH(CPU, funct3, rs1, rs2, imm_value)
    local registers = CPU.registers
    local cond = nil
    local test = bit.rshift(funct3, 1)
    local RVEMU_set_sign_32 = _RVEMU_set_sign(32)
    local CPU_LoadRegister = CPU.LoadRegister
    return function()
        local op1 = CPU_LoadRegister(CPU, rs1)
        local op2 = CPU_LoadRegister(CPU, rs2)

        if test == 0 then -- BEQ | BNE
            cond = op1 == op2
        elseif test == 2 then -- BLT | BGE
            op1 = RVEMU_set_sign_32(op1)
            op2 = RVEMU_set_sign_32(op2)
            cond = op1 < op2
        elseif test == 3 then -- BLTU | BGEU
            cond = op1 < op2
        else
            -- assert(false, "condition " .. tostring(funct3) .. " is not existed")
        end

        cond = bit.bxor(cond == true and 1 or 0, bit.band(funct3, 1))

        local pc_inc = 4
        if cond == 1 then
            pc_inc = imm_value
        end
        registers.pc = registers.pc + pc_inc

    end
end

-- Loads a value from memory into a register (LOAD instruction).
-- @param CPU The CPU object.
-- @param rd The destination register.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the base address.
-- @param imm_value The immediate value for the address offset.
function RVEMU_BaseInstructions_LOAD(CPU, rd, funct3, rs1, imm_value)
    local registers = CPU.registers
    local RVEMU_set_sign_8 = _RVEMU_set_sign(8)
    local RVEMU_set_sign_16 = _RVEMU_set_sign(16)

    local RVEMU_set_unsign_32 = _RVEMU_set_unsign(32)
    local value = nil

    local CPU_StoreRegister = CPU.StoreRegister
    local CPU_LoadRegister = CPU.LoadRegister
    local CPU_memory = CPU.memory
    local CPU_memory_Read = CPU_memory.Read
    if funct3 == 0 then -- LB
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            value = CPU_memory_Read(CPU_memory, addr, 1)
            value = RVEMU_set_unsign_32(RVEMU_set_sign_8(value))
            CPU_StoreRegister(CPU, rd, value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 1 then -- LH
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            value = CPU_memory_Read(CPU_memory, addr, 2)
            value = RVEMU_set_unsign_32(RVEMU_set_sign_16(value))
            CPU_StoreRegister(CPU, rd, value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 2 then -- LW
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            value = CPU_memory_Read(CPU_memory, addr, 4)
            CPU_StoreRegister(CPU, rd, value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 4 then -- LBU
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            value = CPU_memory_Read(CPU_memory, addr, 1)
            CPU_StoreRegister(CPU, rd, value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 5 then -- LHU
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            value = CPU_memory_Read(CPU_memory, addr, 2)
            CPU_StoreRegister(CPU, rd, value)
            registers.pc = registers.pc + 4
        end
    else
        -- assert(false, "load opcode " .. tostring(funct3) .. " is not existed")
    end

end

-- Stores a value from a register into memory (STORE instruction).
-- @param CPU The CPU object.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the base address.
-- @param rs2 The source register for the value to store.
-- @param imm_value The immediate value for the address offset.
function RVEMU_BaseInstructions_STORE(CPU, funct3, rs1, rs2, imm_value)
    local registers = CPU.registers
    local CPU_LoadRegister = CPU.LoadRegister
    local CPU_memory = CPU.memory
    local CPU_memory_Write = CPU_memory.Write

    if funct3 == 0 then -- SB
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            local value = CPU_LoadRegister(CPU, rs2)
            CPU_memory_Write(CPU_memory, addr, value, 1)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 1 then -- SH
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            local value = CPU_LoadRegister(CPU, rs2)
            CPU_memory_Write(CPU_memory, addr, value, 2)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 2 then -- SW
        return function()
            local addr = CPU_LoadRegister(CPU, rs1) + imm_value
            local value = CPU_LoadRegister(CPU, rs2)
            CPU_memory_Write(CPU_memory, addr, value, 4)
            registers.pc = registers.pc + 4

        end
    else
        -- assert(false, "store opcode " .. tostring(funct3) .. " is not existed")
    end

end

-- Performs an arithmetic or logical operation with an immediate value and stores the result in a register (OP-IMM instruction).
-- @param CPU The CPU object.
-- @param rd The destination register.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the first operand.
-- @param imm_value The immediate value for the second operand.
function RVEMU_BaseInstructions_OP_IMM(CPU, rd, funct3, rs1, imm_value)
    local registers = CPU.registers
    local result = nil
    local RVEMU_set_sign_32 = _RVEMU_set_sign(32)
    local RVEMU_set_sign_12 = _RVEMU_set_sign(12)
    local band_imm_0x1f = bit.band(imm_value, 0x1F)
    local CPU_StoreRegister = CPU.StoreRegister
    local CPU_LoadRegister = CPU.LoadRegister
    local op1 = nil
    if funct3 == 0x0 then -- ADDI
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            result = op1 + imm_value
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x2 then -- SLTI
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            result = RVEMU_set_sign_32(op1, 32) < RVEMU_set_sign_12(imm_value) and 1 or 0
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x3 then -- SLTIU
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            result = op1 < imm_value and 1 or 0
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x4 then -- XORI
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            result = bit.bxor(op1, imm_value)
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x6 then -- ORI
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            result = bit.bor(op1, imm_value)
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x7 then -- ANDI
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            result = bit.band(op1, imm_value)
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x1 then -- SLLI
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            result = bit.lshift(op1, band_imm_0x1f)
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x5 then
        return function()
            op1 = CPU_LoadRegister(CPU, rs1)
            if bit.rshift(imm_value, 10) == 0 then -- SRLI
                result = bit.rshift(op1, band_imm_0x1f)
            else -- SRAI
                result = bit.arshift(op1, band_imm_0x1f)
            end
            CPU_StoreRegister(CPU, rd, result)
            registers.pc = registers.pc + 4
        end
    else
        -- assert(false, "Unsupported OP_IMM funct3: " .. tostring(funct3))
    end

end

-- Performs an arithmetic or logical operation between two registers and stores the result in a register (OP instruction).
-- @param CPU The CPU object.
-- @param rd The destination register.
-- @param funct3 The function code for the operation.
-- @param rs1 The first source register for the operation.
-- @param rs2 The second source register for the operation.
-- @param funct7 The function code for the operation.
function RVEMU_BaseInstructions_OP(CPU, rd, funct3, rs1, rs2, funct7)
    local registers = CPU.registers
    local RVEMU_set_sign_32 = _RVEMU_set_sign(32)
    local RVEMU_set_unsign_64 = _RVEMU_set_unsign(64)
    local RVEMU_set_unsign_32 = _RVEMU_set_unsign(32)
    local CPU_StoreRegister = CPU.StoreRegister
    local CPU_LoadRegister = CPU.LoadRegister

    local result = nil

    if funct3 == 0x0 then
        if funct7 == 0x00 then -- ADD
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)

                result = bit.band(op1 + op2, 0xFFFFFFFF)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x20 then -- SUB
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)

                result = bit.band(op1 - op2, 0xFFFFFFFF)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- MUL (RV32M)
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)

                local signed_op1 = RVEMU_set_sign_32(op1)
                local signed_op2 = RVEMU_set_sign_32(op2)
                result = bit.band(signed_op1 * signed_op2, 0xFFFFFFFF)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x1 then
        if funct7 == 0x00 then -- SLL
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)

                result = bit.lshift(op1, bit.band(op2, 0x1F))
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- MULH
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)

                local signed_op1 = RVEMU_set_sign_32(op1)
                local signed_op2 = RVEMU_set_sign_32(op2)
                local full_result = signed_op1 * signed_op2
                result = math.floor(RVEMU_set_unsign_64(full_result) / 0x100000000)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x2 then
        if funct7 == 0x00 then -- SLT
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                result = bit.band(RVEMU_set_sign_32(op1) < RVEMU_set_sign_32(op2) and 1 or 0, 0xFFFFFFFF)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- MULHSU
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                local signed_op1 = RVEMU_set_sign_32(op1)
                local unsigned_op2 = op2
                local full_result = signed_op1 * unsigned_op2
                result = math.floor(RVEMU_set_unsign_64(full_result) / 0x100000000)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x3 then
        if funct7 == 0x00 then -- SLTU
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                result = bit.band(op1 < op2 and 1 or 0, 0xFFFFFFFF)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- MULHU
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                local full_result = op1 * op2
                result = math.floor(full_result / 0x100000000)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x4 then
        if funct7 == 0x00 then -- XOR
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                result = bit.bxor(op1, op2)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- DIV (RV32M)
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                if op2 == 0 then
                    result = 0xFFFFFFFF
                else
                    result = RVEMU_set_unsign_32(math.floor(RVEMU_set_sign_32(op1) / RVEMU_set_sign_32(op2)), 32)
                end
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x5 then
        if funct7 == 0x00 then -- SRL
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                result = bit.band(bit.rshift(op1, bit.band(op2, 0x1F)), 0xFFFFFFFF)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x20 then -- SRA
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                result = bit.band(bit.arshift(op1, bit.band(op2, 0x1F)), 0xFFFFFFFF)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- DIVU (RV32M)
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                if op2 == 0 then
                    result = 0xFFFFFFFF
                else
                    result = RVEMU_set_unsign_32(math.floor(op1 / op2))
                end
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x6 then
        if funct7 == 0x00 then -- OR
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                result = bit.bor(op1, op2)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- REM (RV32M)
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                if op2 == 0 then
                    result = op1
                else
                    local signed_op1 = RVEMU_set_sign_32(op1)
                    local signed_op2 = RVEMU_set_sign_32(op2)
                    result = RVEMU_set_unsign_32(signed_op1 % signed_op2)
                end
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    elseif funct3 == 0x7 then
        if funct7 == 0x00 then -- AND
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                result = bit.band(op1, op2)
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        elseif funct7 == 0x01 then -- REMU (RV32M)
            return function()
                local op1 = CPU_LoadRegister(CPU, rs1)
                local op2 = CPU_LoadRegister(CPU, rs2)
                if op2 == 0 then
                    result = op1
                else
                    result = RVEMU_set_unsign_32(op1 % op2)
                end
                CPU_StoreRegister(CPU, rd, result)
                registers.pc = registers.pc + 4
            end
        else
            -- assert(false, "Unsupported OP funct7: " .. tostring(funct7))
        end
    else
        -- assert(false, "Unsupported OP funct3: " .. tostring(funct3))
    end

end

-- Performs a memory-related operation (MISC-MEM instruction).
-- @param CPU The CPU object.
-- @param rd The destination register.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the base address.
-- @param imm_value The immediate value for the address offset.
function RVEMU_BaseInstructions_MISC_MEM(CPU, rd, funct3, rs1, imm_value)
    local registers = CPU.registers
    return function()

        --[[if funct3 == 0x0 then -- FENCE
            return nil
        elseif funct3 == 0x1 then -- FENCE.I
            return nil
        else
            --assert(false, "Unsupported MISC_MEM funct3: " .. tostring(funct3))
        end]]
        registers.pc = registers.pc + 4
    end
end
-- Performs a system-related operation (SYSTEM instruction).
-- @param CPU The CPU object.
-- @param rd The destination register.
-- @param funct3 The function code for the operation.
-- @param rs1 The source register for the operation.
-- @param imm_value The immediate value for the operation.
function RVEMU_BaseInstructions_SYSTEM(CPU, rd, funct3, rs1, imm_value)
    local registers = CPU.registers
    local CPU_StoreRegister = CPU.StoreRegister
    local CPU_LoadRegister = CPU.LoadRegister

    if funct3 == 0 then
        return function()
            if imm_value == 0 then -- ECALL
                local syscall_num = CPU_LoadRegister(CPU, 17)
                RVEMU_handle_syscall(CPU, syscall_num)
            elseif imm_value == 1 then -- EBREAK
                print("EBREAK encountered at PC: " .. tostring(CPU.registers.pc))
                CPU.is_running = 0
            else
                -- assert(false, "Unsupported SYSTEM funct12: " .. tostring(imm_value))
            end
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x1 then -- CSRRW
        return function()
            local csr_value = CPU:ReadCSR(imm_value)
            CPU:WriteCSR(imm_value, CPU_LoadRegister(CPU, rs1))
            CPU_StoreRegister(CPU, rd, csr_value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x2 then -- CSRRS
        return function()
            local csr_value = CPU:ReadCSR(imm_value)
            CPU:WriteCSR(imm_value, bit.bor(csr_value, CPU_LoadRegister(CPU, rs1)))
            CPU_StoreRegister(CPU, rd, csr_value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x3 then -- CSRRC
        return function()
            local csr_value = CPU:ReadCSR(imm_value)
            CPU:WriteCSR(imm_value, bit.band(csr_value, bit.bnot(CPU_LoadRegister(CPU, rs1))))
            CPU_StoreRegister(CPU, rd, csr_value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x5 then -- CSRRWI
        return function()
            local csr_value = CPU:ReadCSR(imm_value)
            CPU:WriteCSR(imm_value, rs1)
            CPU_StoreRegister(CPU, rd, csr_value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x6 then -- CSRRSI
        return function()
            local csr_value = CPU:ReadCSR(imm_value)
            CPU:WriteCSR(imm_value, bit.bor(csr_value, rs1))
            CPU_StoreRegister(CPU, rd, csr_value)
            registers.pc = registers.pc + 4
        end
    elseif funct3 == 0x7 then -- CSRRCI
        return function()
            local csr_value = CPU:ReadCSR(imm_value)
            CPU:WriteCSR(imm_value, bit.band(csr_value, bit.bnot(rs1)))
            CPU_StoreRegister(CPU, rd, csr_value)
            registers.pc = registers.pc + 4
        end
    else
        -- assert(0, "Unsupported SYSTEM funct3: " .. tostring(funct3))
    end

end
