RiscVMemory = {
    mem = {}
}

function RiscVMemory:Get(addr)
    assert(self.mem[addr] ~= nil, string.format("addr 0x%x is not allocated", addr))
    return self.mem[addr]
end

function RiscVMemory:Read(addr, vsize)
    if vsize == 4 then
        if addr % 4 == 0 then -- aligned access
            return self:Get(addr)
        else -- misaligned access
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
            return bit.band(bit.rshift(self:Get(addr), misalign*8), 0xffff)
        end
    elseif vsize == 1 then
        local misalign = addr % 4
        return bit.band(bit.rshift(self:Get(addr), misalign*8), 0xff)
    end     
end