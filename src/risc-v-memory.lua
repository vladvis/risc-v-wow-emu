RiscVMemory = {
}

function RiscVMemory:Get(addr)
    assert(self.mem[addr] ~= nil, string.format("addr 0x%x is not allocated", addr))
    return self.mem[addr]
end

function RiscVMemory:Set(addr, value)
    assert(addr % 4 == 0, "addr must be aligned (set)")
    self.mem[addr] = value
end

function RiscVMemory:InitMemoryRange(addr_start, addr_end)
    for i = addr_start, addr_end, 4 do
        self:Set(i, 0)
    end
end

function RiscVMemory:Read(addr, vsize)
    if vsize == 4 then
        if addr % 4 == 0 then -- aligned read
            return self:Get(addr)
        else -- misaligned read
            local misalign = addr % 4
            local val1 = bit.rshift(self:Get(addr - misalign), misalign*8)
            local val2 = bit.band(bit.lshift(self:Get(addr + (4 - misalign)), (4 - misalign)*8), 0xffffffff)
            return bit.bor(val1, val2)
        end
    elseif vsize == 2 then
        if addr % 4 == 0 then
            return bit.band(self:Get(addr), 0xffff)
        elseif addr % 4 == 3 then
            local val1 = bit.rshift(self:Get(addr - 3), 24)
            local val2 = bit.band(bit.lshift(self:Get(addr + 1), 8), 0xff00)
            return bit.bor(val1, val2)
        else
            local misalign = addr % 4
            return bit.band(bit.rshift(self:Get(addr - misalign), misalign*8), 0xffff)
        end
    elseif vsize == 1 then
        local misalign = addr % 4
        return bit.band(bit.rshift(self:Get(addr - misalign), misalign*8), 0xff)
    elseif vsize == 'float' then
        local int_value = self:Read(addr, 4)
        return bits_to_float(int_value) -- конвертируем 32-битное целое число в float
    elseif vsize == 'double' then
        local lo = self:Read(addr, 4)
        local hi = self:Read(addr + 4, 4)
        return bits_to_double(hi, lo) -- конвертируем 64-битное целое число в double
    else
        assert(false, "vsize " .. tostring(vsize) .. " is not supported")
    end     
end

function RiscVMemory:Write(addr, value, vsize)
    local misalign = bit.band(addr, 3)
    if vsize == 4 then
        if misalign == 0 then -- aligned write
            self:Set(addr, value)
        else -- misaligned write
            local val1 = bit.band(self:Get(addr - misalign), bit.rshift(0xffffffff, 32 - misalign*8))
            val1 = bit.band(bit.bor(val1, bit.lshift(value, misalign*8)), 0xffffffff)
            self:Set(addr - misalign, val1)

            local val2 = bit.band(self:Get(addr + (4 - misalign)), bit.lshift(0xffffffff, misalign*8))
            val2 = bit.band(bit.bor(val2, bit.rshift(value, (32 - misalign*8))), 0xffffffff)
            self:Set(addr + (4 - misalign), val2)
        end
    elseif vsize == 2 then
        if misalign == 0 then
            local val = bit.band(self:Get(addr), 0xffff0000)
            val = bit.bor(val, bit.band(value, 0x0000ffff))
            self:Set(addr, val)
        elseif misalign == 1 then
            local val = bit.band(self:Get(addr - 1), 0xff0000ff)
            val = bit.bor(val, bit.band(bit.lshift(value, 8), 0x00ffff00))
            self:Set(addr - 1, val)
        elseif misalign == 2 then
            local val = bit.band(self:Get(addr - 2), 0x0000ffff)
            val = bit.bor(val, bit.band(bit.lshift(value, 16), 0xffff0000))
            self:Set(addr - 2, val)
        elseif misalign == 3 then
            local val1 = bit.band(self:Get(addr - 3), 0x00ffffff)
            val1 = bit.bor(val1, bit.band(bit.lshift(value, 24), 0xff000000))
            self:Set(addr - 3, val1)

            local val2 = bit.band(self:Get(addr + 1), 0xffffff00)
            val2 = bit.bor(val2, bit.band(bit.rshift(value, 8), 0x000000ff))
            self:Set(addr + 1, val2)
        end
    elseif vsize == 1 then
        if misalign == 0 then
            local val = bit.band(self:Get(addr), 0xffffff00)
            val = bit.bor(val, bit.band(value, 0x000000ff))
            self:Set(addr, val)
        elseif misalign == 1 then
            local val = bit.band(self:Get(addr - 1), 0xffff00ff)
            val = bit.bor(val, bit.band(bit.lshift(value, 8), 0x0000ff00))
            self:Set(addr - 1, val)
        elseif misalign == 2 then
            local val = bit.band(self:Get(addr - 2), 0xff00ffff)
            val = bit.bor(val, bit.band(bit.lshift(value, 16), 0x00ff0000))
            self:Set(addr - 2, val)
        else
            local val = bit.band(self:Get(addr - 3), 0x00ffffff)
            val = bit.bor(val, bit.band(bit.lshift(value, 24), 0xff000000))
            self:Set(addr - 3, val)
        end
    elseif vsize == 'float' then
        local int_value = float_to_bits(value) -- конвертируем float в 32-битное целое число
        self:Write(addr, int_value, 4)
    elseif vsize == 'double' then
        local hi, lo = double_to_bits(value) -- конвертируем double в 64-битное целое число
        self:Write(addr, lo, 4)
        self:Write(addr + 4, hi, 4)
    else
        assert(false, "vsize " .. tostring(vsize) .. " is not supported")
    end
end