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
    else
        assert(0, "vsize " .. tostring(vsize) .. " is not supported")
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
    else
        assert(0, "vsize " .. tostring(vsize) .. " is not supported")
    end
end

function RiscVMemory:DebugPrintMem()
    for k, v in pairs(self.mem) do
        print(string.format("mem[0x%x] = 0x%x", k, v))
    end
end

function RiscVMemory:Test()
    init_mem = {
        [0x8000] = 0xdeadbeef,
        [0x8004] = 0xcafebabe,
        [0x8008] = 0x12345678,
        [0x800c] = 0x01020304,
        [0x8010] = 0x04030201,
        [0x8014] = 0x11111111
    }
    for k, v in pairs(init_mem) do
        self:Set(k, v)
    end

    print(string.format("Read(0x8000, 1) = 0x%x", self:Read(0x8000, 1)))
    print(string.format("Read(0x8001, 1) = 0x%x", self:Read(0x8001, 1)))
    print(string.format("Read(0x8002, 1) = 0x%x", self:Read(0x8002, 1)))
    print(string.format("Read(0x8003, 1) = 0x%x", self:Read(0x8003, 1)))
    print(string.format("Read(0x8004, 1) = 0x%x", self:Read(0x8004, 1)))

    print(string.format("Read(0x8000, 2) = 0x%x", self:Read(0x8000, 2)))
    print(string.format("Read(0x8001, 2) = 0x%x", self:Read(0x8001, 2)))
    print(string.format("Read(0x8002, 2) = 0x%x", self:Read(0x8002, 2)))
    print(string.format("Read(0x8003, 2) = 0x%x", self:Read(0x8003, 2)))
    print(string.format("Read(0x8004, 2) = 0x%x", self:Read(0x8004, 2)))

    print(string.format("Read(0x8000, 4) = 0x%x", self:Read(0x8000, 4)))
    print(string.format("Read(0x8001, 4) = 0x%x", self:Read(0x8001, 4)))
    print(string.format("Read(0x8002, 4) = 0x%x", self:Read(0x8002, 4)))
    print(string.format("Read(0x8003, 4) = 0x%x", self:Read(0x8003, 4)))
    print(string.format("Read(0x8004, 4) = 0x%x", self:Read(0x8004, 4)))
    
    self:Write(0x8000, 0x55667788, 4)
    self:Write(0x8005, 0xaabbccdd, 4)
    self:Write(0x800a, 0x00112233, 4)
    self:Write(0x800f, 0xffee4499, 4)

    assert(self:Read(0x8000, 4) == 0x55667788, "test failed")
    assert(self:Read(0x8005, 4) == 0xaabbccdd, "test failed")
    print(string.format("Read(0x8005, 4) = 0x%x", self:Read(0x8005, 4)))
    print(string.format("Read(0x800a, 4) = 0x%x", self:Read(0x800a, 4)))
    print(string.format("Read(0x800f, 4) = 0x%x", self:Read(0x800f, 4)))

    self:Write(0x8000, 0xaabb, 2)
    self:Write(0x8005, 0xccdd, 2)
    self:Write(0x800a, 0xeeff, 2)
    self:Write(0x800f, 0x2233, 2)

    print(string.format("Read(0x8000, 2) = 0x%x", self:Read(0x8000, 2)))
    print(string.format("Read(0x8005, 2) = 0x%x", self:Read(0x8005, 2)))
    print(string.format("Read(0x800a, 2) = 0x%x", self:Read(0x800a, 2)))
    print(string.format("Read(0x800f, 2) = 0x%x", self:Read(0x800f, 2)))

    self:Write(0x8000, 0x12, 1)
    self:Write(0x8005, 0x34, 1)
    self:Write(0x800a, 0x56, 1)
    self:Write(0x800f, 0x78, 1)

    print(string.format("Read(0x8000, 1) = 0x%x", self:Read(0x8000, 1)))
    print(string.format("Read(0x8005, 1) = 0x%x", self:Read(0x8005, 1)))
    print(string.format("Read(0x800a, 1) = 0x%x", self:Read(0x800a, 1)))
    print(string.format("Read(0x800f, 1) = 0x%x", self:Read(0x800f, 1)))

    self:DebugPrintMem()
end