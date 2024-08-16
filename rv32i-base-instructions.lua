function BaseInstructions_LUI(CPU, dest, value)
    CPU:RegisterStore(dest, value)
end

function BaseInstructions_AUIPC(CPU, dest, value)
    CPU:RegisterStore(dest, CPU.registers.pc + value)
end

function BaseInstructions_JAL(CPU, dest, offset)
    local old_pc = CPU.registers.pc
    CPU:PCStore(CPU.registers.pc + offset)

    if (dest == 1) or (dest == 5) then
        CPU:RegisterStore(dest, old_pc + 4)
    end
end