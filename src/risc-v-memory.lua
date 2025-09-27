-- Initializes and returns a RISC-V memory object.
-- @return A RISC-V memory object with read and write capabilities.
function RVEMU_GetMemory()
    local RiscVMemory = {}

    RiscVMemory.mem = {}
    -- Precomputed 8-bit shift constants to avoid pow calls
    local SHIFT8 = {1, 256, 65536, 16777216, 4294967296}

    -- Retrieves the value stored at the specified memory address.
    -- @param addr The memory address to retrieve the value from.
    -- @return The value stored at the specified memory address.
    function RiscVMemory:Get(addr)
        return self.mem[addr] or 0
    end

    -- Sets the value at the specified memory address.
    -- @param addr The memory address to set the value at.
    -- @param value The value to set at the specified memory address.
    function RiscVMemory:Set(addr, value)
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
                -- assert(addr % 4 == 0, "addr must be aligned (read)")
                return self:Get(addr)
                -- local misalign = addr % 4
                -- if misalign == 0 then -- aligned read
                --     return self:Get(addr)
                -- else -- misaligned read
                --     print("misaligned read")
                --     local misalign = misalign
                --     local val1 = bit.rshift(self:Get(addr - misalign), misalign * 8)
                --     local val2 = (self:Get(addr + (4 - misalign)) * 2^((4 - misalign) * 8))--[[% 0x100000000]]
                --     return bit.bor(val1, val2)
                -- end
            end
        elseif vsize == 2 then
            return function(addr)
				local misalign = addr % 4
				if misalign == 0 then
					return self:Get(addr) % 0x10000
				elseif misalign == 3 then
					local part1 = math.floor(self:Get(addr - 3) / (2^24))
					local part2 = (self:Get(addr + 1) % 0x100) * 0x100
					return part1 + part2
				else
					return math.floor(self:Get(addr - misalign) / (2^(misalign * 8))) % 0x10000
				end
            end
        elseif vsize == 1 then
            return function(addr)
				local misalign = addr % 4
				return math.floor(self:Get(addr - misalign) / (2^(misalign * 8))) % 0x100
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
                -- assert(addr % 4 == 0, "addr must be aligned (write)")
                self:Set(addr, value)
                -- local misalign = bit.band(addr, 3)
                -- if misalign == 0 then -- aligned write
                --     self:Set(addr, value)
                -- else -- misaligned write
                --     print("misaligned write")
                --     local val1 = bit.band(self:Get(addr - misalign), bit.rshift(0xffffffff, 32 - misalign * 8))
                --     val1 = bit.bor(val1, (value * 2^(misalign * 8))) ----[[% 0x100000000]]
                --     self:Set(addr - misalign, val1)

                --     local val2 = bit.band(self:Get(addr + (4 - misalign)), (0xffffffff * 2^(misalign * 8)))
                --     val2 = bit.bor(val2, bit.rshift(value, (32 - misalign * 8))) ----[[% 0x100000000]]
                --     self:Set(addr + (4 - misalign), val2)
                -- end
            end
        elseif vsize == 2 then
            return function(addr, value)
				local misalign = addr % 4
                if misalign == 0 then
					local old = self:Get(addr)
					local newv = (math.floor(old / 0x10000) * 0x10000) + (value % 0x10000)
					self:Set(addr, newv)
                elseif misalign == 1 then
					local old = self:Get(addr - 1)
					local low8 = old % 0x100
					local high8 = math.floor(old / 0x1000000)
					local mid = value % 0x10000
					local newv = low8 + ((mid % 0x100) * 0x100) + (math.floor(mid / 0x100) * 0x10000) + (high8 * 0x1000000)
					self:Set(addr - 1, newv)
                elseif misalign == 2 then
					local old = self:Get(addr - 2)
					local newv = (old % 0x10000) + ((value % 0x10000) * 0x10000)
					self:Set(addr - 2, newv)
                elseif misalign == 3 then
					local old1 = self:Get(addr - 3)
					local new1 = (old1 % 0x1000000) + ((value % 0x100) * 0x1000000)
					self:Set(addr - 3, new1)
					local old2 = self:Get(addr + 1)
					local new2 = (old2 - (old2 % 0x100)) + (math.floor(value / 0x100) % 0x100)
					self:Set(addr + 1, new2)
                end
            end
        elseif vsize == 1 then
            return function(addr, value)
				local misalign = addr % 4
                if misalign == 0 then
					local old = self:Get(addr)
					local newv = (old - (old % 0x100)) + (value % 0x100)
					self:Set(addr, newv)
                elseif misalign == 1 then
					local old = self:Get(addr - 1)
					local low = old % 0x100
					local upper = math.floor(old / 0x10000) * 0x10000
					local newv = low + upper + ((value % 0x100) * 0x100)
					self:Set(addr - 1, newv)
                elseif misalign == 2 then
					local old = self:Get(addr - 2)
					local low16 = old % 0x10000
					local top = math.floor(old / 0x1000000) * 0x1000000
					local newv = low16 + top + ((value % 0x100) * 0x10000)
					self:Set(addr - 2, newv)
                else
					local old = self:Get(addr - 3)
					local newv = (old % 0x1000000) + ((value % 0x100) * 0x1000000)
					self:Set(addr - 3, newv)
                end
            end
        elseif vsize == 'float' then
            return function(addr, value)
				local misalign = addr % 4
                local int_value = RVEMU_float_to_bits(value) -- конвертируем float в 32-битное целое число
                self:Write(addr, int_value, 4)
            end
        elseif vsize == 'double' then
            return function(addr, value)
				local misalign = addr % 4
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
