-- Initializes and returns a RISC-V memory object.
-- @return A RISC-V memory object with read and write capabilities.
function RVEMU_GetMemory()
    local RiscVMemory = {}

    RiscVMemory.mem = {}

    -- Retrieves the value stored at the specified memory address.
    -- @param addr The memory address to retrieve the value from.
    -- @return The value stored at the specified memory address.
    function RiscVMemory:Get(addr)
        -- assert(self.mem[addr] ~= nil, string.format("addr 0x%x is not allocated", addr))
        --[[
        local hi = bit.rshift(addr, 12)
        local lo = addr % 0x1000
        return self.mem[hi][lo]
        ]]
        return self.mem[addr]
    end

    -- Sets the value at the specified memory address.
    -- @param addr The memory address to set the value at.
    -- @param value The value to set at the specified memory address.
    function RiscVMemory:Set(addr, value)
        -- assert(addr % 4 == 0, "addr must be aligned (set)")
        --[[
        local hi = bit.rshift(addr, 12)
        local lo = addr % 0x1000
        if self.mem[hi] == nil then
            self.mem[hi] = {}
        end
        self.mem[hi][lo] = value
        ]]
        self.mem[addr] = value
    end

    -- Initializes a range of memory addresses with zero values.
    -- @param addr_start The starting address of the memory range.
    -- @param addr_end The ending address of the memory range.
    function RiscVMemory:InitMemoryRange(addr_start, addr_end)
        for i = addr_start, addr_end, 4 do
            self:Set(i, 0)
        end
    end

    -- Reads a value from memory at the specified address and size.
    -- @param addr The memory address to read from.
    -- @param vsize The size of the value to read (1, 2, 4, 'float', or 'double').
    -- @return The value read from memory.
    function RiscVMemory:Read(vsize)
        if vsize == 4 then
            return function(addr)
                local misalign = addr % 4
                if misalign == 0 then -- aligned read
                    return self:Get(addr)
                else -- misaligned read
                    local misalign = misalign
                    local val1 = bit.rshift(self:Get(addr - misalign), misalign * 8)
                    local val2 = (self:Get(addr + (4 - misalign)) * 2^((4 - misalign) * 8))--[[% 0x100000000]]
                    return bit.bor(val1, val2)
                end
            end
        elseif vsize == 2 then
            return function(addr)
                local misalign = addr % 4
                if misalign == 0 then
                    return self:Get(addr) % 0x10000
                elseif misalign == 3 then
                    local val1 = bit.rshift(self:Get(addr - 3), 24)
                    local val2 = bit.band((self:Get(addr + 1) * 0x100)--[[% 0x100000000]], 0xff00)
                    return bit.bor(val1, val2)
                else
                    return bit.rshift(self:Get(addr - misalign), misalign * 8) % 0x10000
                end
            end
        elseif vsize == 1 then
            return function(addr)
                local misalign = addr % 4
                return bit.rshift(self:Get(addr - misalign), misalign * 8) % 0x100
            end
        elseif vsize == 'float' then
            return function(addr)
                local int_value = self:Read(addr, 4)
                return RVEMU_bits_to_float(int_value) -- конвертируем 32-битное целое число в float
            end
        elseif vsize == 'double' then
            return function(addr)
                local lo = self:Read(addr, 4)
                local hi = self:Read(addr + 4, 4)
                return RVEMU_bits_to_double(hi, lo) -- конвертируем 64-битное целое число в double
            end
        else
            -- assert(false, "vsize " .. tostring(vsize) .. " is not supported")
        end

    end

    -- Writes a value to memory at the specified address and size.
    -- @param addr The memory address to write to.
    -- @param value The value to write to memory.
    -- @param vsize The size of the value to write (1, 2, 4, 'float', or 'double').
    function RiscVMemory:Write(vsize)

        if vsize == 4 then
            return function(addr, value)
                local misalign = bit.band(addr, 3)
                if misalign == 0 then -- aligned write
                    self:Set(addr, value)
                else -- misaligned write
                    local val1 = bit.band(self:Get(addr - misalign), bit.rshift(0xffffffff, 32 - misalign * 8))
                    val1 = bit.bor(val1, (value * 2^(misalign * 8))) ----[[% 0x100000000]]
                    self:Set(addr - misalign, val1)

                    local val2 = bit.band(self:Get(addr + (4 - misalign)), (0xffffffff * 2^(misalign * 8)))
                    val2 = bit.bor(val2, bit.rshift(value, (32 - misalign * 8))) ----[[% 0x100000000]]
                    self:Set(addr + (4 - misalign), val2)
                end
            end
        elseif vsize == 2 then
            return function(addr, value)
                local misalign = bit.band(addr, 3)
                if misalign == 0 then
                    local val = bit.band(self:Get(addr), 0xffff0000)
                    val = bit.bor(val, value % 0x10000)
                    self:Set(addr, val)
                elseif misalign == 1 then
                    local val = bit.band(self:Get(addr - 1), 0xff0000ff)
                    val = bit.bor(val, bit.band((value * 0x100), 0x00ffff00))
                    self:Set(addr - 1, val)
                elseif misalign == 2 then
                    local val = self:Get(addr - 2) % 0x10000
                    val = bit.bor(val, bit.band((value * 0x10000), 0xffff0000))
                    self:Set(addr - 2, val)
                elseif misalign == 3 then
                    local val1 = self:Get(addr - 3) % 0x1000000
                    val1 = bit.bor(val1, bit.band((value * 0x1000000), 0xff000000))
                    self:Set(addr - 3, val1)

                    local val2 = bit.band(self:Get(addr + 1), 0xffffff00)
                    val2 = bit.bor(val2, bit.rshift(value, 8) % 0x100)
                    self:Set(addr + 1, val2)
                end
            end
        elseif vsize == 1 then
            return function(addr, value)
                local misalign = bit.band(addr, 3)
                if misalign == 0 then
                    local val = bit.band(self:Get(addr), 0xffffff00)
                    val = bit.bor(val, value % 0x100)
                    self:Set(addr, val)
                elseif misalign == 1 then
                    local val = bit.band(self:Get(addr - 1), 0xffff00ff)
                    val = bit.bor(val, bit.band((value * 0x100), 0x0000ff00))
                    self:Set(addr - 1, val)
                elseif misalign == 2 then
                    local val = bit.band(self:Get(addr - 2), 0xff00ffff)
                    val = bit.bor(val, bit.band((value * 0x10000), 0x00ff0000))
                    self:Set(addr - 2, val)
                else
                    local val = self:Get(addr - 3) % 0x1000000
                    val = bit.bor(val, bit.band((value * 0x1000000), 0xff000000))
                    self:Set(addr - 3, val)
                end
            end
        elseif vsize == 'float' then
            return function(addr, value)
                local misalign = bit.band(addr, 3)
                local int_value = RVEMU_float_to_bits(value) -- конвертируем float в 32-битное целое число
                self:Write(addr, int_value, 4)
            end
        elseif vsize == 'double' then
            return function(addr, value)
                local misalign = bit.band(addr, 3)
                local hi, lo = RVEMU_double_to_bits(value) -- конвертируем double в 64-битное целое число
                self:Write(addr, lo, 4)
                self:Write(addr + 4, hi, 4)
            end
        else
            -- assert(false, "vsize " .. tostring(vsize) .. " is not supported")
        end
    end

    return RiscVMemory
end
