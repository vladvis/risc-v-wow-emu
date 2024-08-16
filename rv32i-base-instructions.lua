function BaseInstructions_LUI(CPU, dest, value)
    CPU:StoreRegister(dest, value)
end

function BaseInstructions_AUIPC(CPU, dest, value)
    CPU:StoreRegister(dest, CPU.registers.pc + value)
end

function BaseInstructions_JAL(CPU, dest, offset)
    local return_address = CPU.registers.pc + 4
    CPU:StorePC(CPU.registers.pc + offset)

    if (dest ~= 0) then
        CPU:StoreRegister(dest, return_address)
    end
end

function BaseInstructions_JALR(CPU, dest, funct3, source, offset)
    assert(funct3 == 0, "funct3 is reserved for JALR")

    local return_address = CPU.registers.pc + 4
    if (dest ~= 0) then
        CPU:StoreRegister(dest, return_address)
    end

    CPU:StorePC(bit.band(CPU:LoadRegister(source) + offset), 0xFFFFFFFE)
end