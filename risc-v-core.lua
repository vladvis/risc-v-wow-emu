local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata("RiscVEmu", "Version") or "SVN"

RiscVCore = {
    VERSION = "RiscVEmulator v" .. version .. " for World of Warcraft"
}

local function bin(x)
    return tonumber(x, 2)
end

function RiscVCore:RegisterLoad(source)
    assert((dest >= 0) and (dest <= 31), "register x".. tostring(source) .." isn't existed (load)")
    return self.registers[source]
end

function RiscVCore:RegisterStore(dest, value)
    if dest ~= 0 then
        assert((dest >= 1) and (dest <= 31), "register x".. tostring(dest) .." isn't existed (store)")
        self.registers[dest] = bit.band(value, 0xffffffff)
    end
end

function RiscVCore:PCStore(value)
    assert(value % 4 == 0, "pc must be aligned")
    self.registers.pc = bit.band(value, 0xffffffff)
end


function RiscVCore:InitCPU()
    self.registers = {}
    for i=0,31 do
        self.registers[i] = 0
    end
    self.registers["pc"] = 0

    self.opcodes = {}

    self.opcodes[bin("0110111")] = {
        name = "LUI",
        type = "U",
        handler = BaseInstructions_LUI
    }

    self.opcodes[bin("0010111")] = {
        name = "AUIPC",
        type = "U",
        handler = BaseInstructions_AUIPC
    }

    self.opcodes[bin("1101111")] = {
        name = "JAL",
        type = "J",
        handler = BaseInstructions_JAL
    }

    self.opcodes[bin("1100111")] = {
        name = "JALR",
        type = "I",
        handler = BaseInstructions_JALR
    }

    self.program = {}
    self.program[0] = 5476535 -- LUI x1, 1337

    self.is_running = 1
end

function RiscVCore:Step()
    assert(self.program ~= nil, "missing program")
    local instruction = self.program[self.registers.pc]
    assert(instruction ~= nil, "out of bound execution")

    opcode = bit.band(instruction, 127)

    assert(self.opcodes[opcode], "opcode ".. tostring(opcode) .." is not implemented")

    if self.opcodes[opcode].type == "U" then
        local dest = bit.rshift(bit.band(instruction, 3968), 7) -- (instr & 0b111110000000) >> 7
        local imm_value = bit.band(instruction, 4294963200) -- instr & 0b11111111111111111111000000000000
        self.opcodes[opcode].handler(self, dest, imm_value)
    elseif self.opcodes[opcode].type == "J" then
        local offset = bit.rshift(bit.band(instruction, 4294963200), 12)*2 -- (instr & 0b11111111111111111111000000000000) >> 12
        self.opcodes[opcode].handler(self, offset)
    elseif self.opcodes[opcode].type == "I" then
        local dest = bit.rshift(bit.band(instruction, 3968), 7) -- (instr & 0b111110000000) >> 7
        local funct3 = bit.rshift(bit.band(instruction, 28672), 12) -- (instr & 0b111000000000000) >> 12
        local source = bit.rshift(bit.band(instruction, 1015808), 15) -- (instr & 0b11111000000000000000) >> 15
        local imm_value = bit.rshift(bit.band(instruction, 4293918720), 20) -- (instr & 0b11111111111100000000000000000000) >> 20
        self.opcodes[opcode].handler(self, dest, funct3, source, imm_value)
    else
        assert(0, "opcode encoding " .. tostring(self.opcodes[opcode].type) .. " is not implemented")
    end

    self.registers.pc = self.registers.pc + 4
end

function RiscVCore:PrintRegs()
    for i = 0, 31 do
        print("x" .. tostring(i) .. " = " .. tostring(self.registers[i]))
    end
    print("pc = " .. tostring(self.registers.pc))
end

RiscVCore:InitCPU()

-- while RiscVCore.is_running do
    RiscVCore:Step()
-- end

RiscVCore:PrintRegs()