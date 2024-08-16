function BaseInstructions_LUI(CPU, dest, value)
    CPU:StoreRegister(dest, value)
end

function BaseInstructions_AUIPC(CPU, dest, value)
    CPU:StoreRegister(dest, CPU.registers.pc + value)
end

function BaseInstructions_JAL(CPU, dest, offset)
    if offset > 1048576 then
        offset = offset - 2097152
    local old_pc = CPU.registers.pc
    CPU:StorePC(CPU.registers.pc + offset)

    if (dest ~= 0) then
        CPU:StoreRegister(dest, old_pc + 4)
    end

    if (dest == 1) or (dest == 5) then
        -- TODO: push stack
    end
end

function BaseInstructions_JALR(CPU, dest, funct3, source, offset)
    assert(funct3 == 0, "funct3 is reserved for JALR")
    offset = offset * 2
    if offset > 4096 then
        offset = offset - 8192
    end

    local is_dest_link = (dest == 1) or (dest == 5)
    local is_source_link = (source == 1) or (source == 5)

    if is_source_link and (not is_dest_link) then
        -- TODO: pop stack
    end

    if (not is_source_link) and is_dest_link then
        -- TODO: push stack
    end

    if is_source_link and is_dest_link then
        if dest ~= source then
            -- TODO: push stack and pop stack
        else
            -- TODO: push stack
        end
    end

    CPU:StorePC(CPU:LoadRegister(source) + offset)
end