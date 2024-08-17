local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata("RiscVEmu", "Version") or "SVN"

RiscVCore = {
    VERSION = "RiscVEmulator v" .. version .. " for World of Warcraft"
}

local function bin(x)
    return tonumber(x, 2)
end

local function decode_rd(instr)
    return bit.band(bit.rshift(instr, 7), 0x1f) -- (instr >> 7) & 0b11111
end

local function decode_rs1(instr)
    return bit.band(bit.rshift(instr, 15), 0x1f) -- (instr >> 15) & 0b11111
end

local function decode_rs2(instr)
    return bit.band(bit.rshift(instr, 20), 0x1f) -- (instr >> 20) & 0b11111
end

local function decode_funct3(instr)
    return bit.band(bit.rshift(instr, 12), 0x07) -- (instr >> 12) & 0b111
end

function set_sign(value, bits)
    local max_int = bit.lshift(1, bits - 1) - 1
    if value > max_int then
        return value - (max_int + 1)*2
    else
        return value
    end
end

function set_unsign(value, bits)
    local max_uint = bit.lshift(1, bits)
    if value < 0 then
        return value + max_uint
    else
        return value
    end
end

function RiscVCore:LoadRegister(source)
    assert((source >= 0) and (source <= 31), "register x".. tostring(source) .." isn't existed (load)")
    return self.registers[source]
end

function RiscVCore:StoreRegister(dest, value)
    if dest ~= 0 then
        assert((dest >= 1) and (dest <= 31), "register x".. tostring(dest) .." isn't existed (store)")
        self.registers[dest] = bit.band(value, 0xffffffff)
    end
end

function RiscVCore:StorePC(value)
    assert(value % 4 == 0, "pc must be aligned")
    self.jumped = true
    self.registers.pc = bit.band(value, 0xffffffff)
end

function RiscVCore:SetMemory(CPU, mem)
    for k, v in pairs(mem) do
        CPU.memory:Set(k, v)
    end
end

function RiscVCore:InitCSR()
    self.csr = {}

    -- Initialize commonly used CSRs (e.g., machine mode)
    self.csr[0x300] = 0x00000000 -- mstatus: Machine status register
    self.csr[0x305] = 0x00000000 -- mtvec: Machine trap-vector base-address register
    self.csr[0x341] = 0x00000000 -- mepc: Machine exception program counter
    self.csr[0x342] = 0x00000000 -- mcause: Machine cause register
    self.csr[0x343] = 0x00000000 -- mtval: Machine trap value register
    self.csr[0x344] = 0x00000000 -- mip: Machine interrupt pending
    self.csr[0x304] = 0x00000000 -- mie: Machine interrupt enable
    -- Add more CSRs as needed...
end

function RiscVCore:ReadCSR(csr_address)
    assert(self.csr[csr_address] ~= nil, "CSR address " .. tostring(csr_address) .. " does not exist")
    return self.csr[csr_address]
end

function RiscVCore:WriteCSR(csr_address, value)
    assert(self.csr[csr_address] ~= nil, "CSR address " .. tostring(csr_address) .. " does not exist")
    self.csr[csr_address] = bit.band(value, 0xffffffff)
end

function RiscVCore:InitCPU(init_handler)
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

    self.opcodes[bin("1100011")] = {
        name = "BRANCH",
        type = "B",
        handler = BaseInstructions_BRANCH
    }

    self.opcodes[bin("0000011")] = {
        name = "LOAD",
        type = "I",
        handler = BaseInstructions_LOAD
    }

    self.opcodes[bin("0100011")] = {
        name = "STORE",
        type = "S",
        handler = BaseInstructions_STORE
    }

    self.opcodes[bin("0010011")] = {
        name = "OP-IMM",
        type = "I",
        handler = BaseInstructions_OP_IMM
    }

    self.opcodes[bin("0110011")] = {
        name = "OP",
        type = "R",
        handler = BaseInstructions_OP
    }

    self.opcodes[bin("0001111")] = {
        name = "MISC-MEM",
        type = "I",
        handler = BaseInstructions_MISC_MEM
    }

    self.opcodes[bin("1110011")] = {
        name = "SYSTEM",
        type = "I",
        handler = BaseInstructions_SYSTEM
    }

    self:InitCSR()
    self.memory = RiscVMemory
    self.memory.mem = {}

    self.entrypoint = 0

    init_handler(self)

    self.registers.pc = self.entrypoint

    self.jumped = false
    self.is_running = 1
end

function RiscVCore:Step()
    local instruction = self.memory:Get(self.registers.pc)
    assert(instruction ~= nil, "out of bound execution")

    opcode = bit.band(instruction, 0x7f)
    assert(self.opcodes[opcode], "opcode ".. tostring(opcode) .." is not implemented")

    if self.opcodes[opcode].type == "U" then
        
        local rd = decode_rd(instruction)
        local imm_value = bit.band(instruction, 0xfffff000) -- instr & 0xfffff000

        self.opcodes[opcode].handler(self, rd, imm_value)

    elseif self.opcodes[opcode].type == "J" then

        local rd = decode_rd(instruction)
        local imm_value = bit.band(bit.rshift(instruction, 20), 0x7fe)
        imm_value = bit.bor(imm_value, bit.band(bit.rshift(instruction, 9), 0x800))
        imm_value = bit.bor(imm_value, bit.band(instruction, 0xff000))
        imm_value = bit.bor(imm_value, bit.band(bit.rshift(instruction, 11), 0x100000))
        imm_value = set_sign(imm_value, 21)
        
        self.opcodes[opcode].handler(self, rd, imm_value)

    elseif self.opcodes[opcode].type == "I" then

        local rd = decode_rd(instruction)
        local funct3 = decode_funct3(instruction)
        local rs1 = decode_rs1(instruction)
        local imm_value = bit.band(bit.rshift(instruction, 20), 0xfff) -- (instr >> 20) & 0xfff
        imm_value = set_sign(imm_value, 12)
        
        self.opcodes[opcode].handler(self, rd, funct3, rs1, imm_value)

    elseif self.opcodes[opcode].type == "B" then

        local funct3 = decode_funct3(instruction)
        local rs1 = decode_rs1(instruction)
        local rs2 = decode_rs2(instruction)
        local imm_value = bit.band(bit.rshift(instruction, 7), 0x1e)
        imm_value = bit.bor(imm_value, bit.band(bit.rshift(instruction, 20), 0x7e0))
        imm_value = bit.bor(imm_value, bit.band(bit.lshift(instruction, 4), 0x800))
        imm_value = bit.bor(imm_value, bit.band(bit.rshift(instruction, 19), 0x1000))
        imm_value = set_sign(imm_value, 13)

        self.opcodes[opcode].handler(self, funct3, rs1, rs2, imm_value)

    elseif self.opcodes[opcode].type == "S" then

        local funct3 = decode_funct3(instruction)
        local rs1 = decode_rs1(instruction)
        local rs2 = decode_rs2(instruction)
        local imm_value = bit.bor(bit.lshift(bit.rshift(instruction, 25), 5), decode_rd(instruction))
        imm_value = set_sign(imm_value, 12)

        self.opcodes[opcode].handler(self, funct3, rs1, rs2, imm_value)

    elseif self.opcodes[opcode].type == "R" then

        local rd = decode_rd(instruction)
        local funct3 = decode_funct3(instruction)
        local rs1 = decode_rs1(instruction)
        local rs2 = decode_rs2(instruction)
        local funct7 = bit.rshift(instruction, 25)

        self.opcodes[opcode].handler(self, rd, funct3, rs1, rs2, funct7)

    else
        assert(false, "opcode encoding " .. tostring(self.opcodes[opcode].type) .. " is not implemented")
    end

    if self.jumped then
        self.jumped = false
    else
        self.registers.pc = self.registers.pc + 4
    end
end

function RiscVCore:PrintRegs()
    for i = 0, 31 do
        print(string.format("x%d = 0x%x", i, self.registers[i]))
    end
    print(string.format("pc = 0x%x", self.registers.pc))
end

function RiscVCore:Run()
    while RiscVCore.is_running == 1 do
        RiscVCore:Step()
    end
end