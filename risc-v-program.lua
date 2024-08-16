RiscVProgram = {
    sections = {}
}

function RiscVProgram:AddSection(CPU, section_name, addr, size, mem)
    self.sections[section_name] = {
        [addr] = addr,
        [size] = size
    }
    for i=0, bit.rshift(size, 2)-1 do
        CPU.memory:Set(addr+i*4, 0)
    end

    for k, v in pairs(mem) do
        CPU.memory:Set(k, v)
    end
end

function RiscVProgram:Init(CPU)
    self.entrypoint = 0x8000

    local mem_text = {
        [0x8000] = 0xdeadbeef,
        [0x8004] = 0xcafebabe
    }
    self:AddSection(CPU, "text", 0x8000, 0x1000, mem_text)
end