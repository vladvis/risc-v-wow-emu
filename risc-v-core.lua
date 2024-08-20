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

local function decode_funct2(instr)
    return bit.band(bit.rshift(instr, 25), 0x03) -- (instr >> 25) & 0b11
end

local function decode_rs3(instr)
    return bit.band(bit.rshift(instr, 27), 0x1f) -- (instr >> 27) & 0b11111
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
    self.csr[0xc00] = 0x00000000 -- cycle
    self.csr[0xc01] = 0x00000000 -- time
    self.csr[0xc02] = 0x00000000 -- instret
    self.csr[0xc80] = 0x00000000 -- cycleh
    self.csr[0xc81] = 0x00000000 -- timeh
    self.csr[0xc82] = 0x00000000 -- instreth
    -- Add more CSRs as needed...
end

function RiscVCore:EncodeFRM()
    return self.fcsr.rm
end

function RiscVCore:EncodeFFLAGS()
    local result = 0
    result = result + (self.fcsr.nx and 0x01 or 0x0)
    result = result + (self.fcsr.uf and 0x02 or 0x0)
    result = result + (self.fcsr.of and 0x04 or 0x0)
    result = result + (self.fcsr.dz and 0x08 or 0x0)
    result = result + (self.fcsr.nv and 0x10 or 0x0)
    return result
end

function RiscVCore:EncodeFCSR()
    return self:EncodeFFLAGS + bit.lshift(self:EncodeFRM(), 5)
end

function RiscVCore:DecodeFRM(value)
    self.fcsr.rm = value
end

function RiscVCore:DecodeFFLAGS(value)
    self.fcsr.nx = (bit.band(value, 0x01) ~= 0) and true or false
    self.fcsr.uf = (bit.band(value, 0x02) ~= 0) and true or false
    self.fcsr.of = (bit.band(value, 0x04) ~= 0) and true or false
    self.fcsr.dz = (bit.band(value, 0x08) ~= 0) and true or false
    self.fcsr.nv = (bit.band(value, 0x10) ~= 0) and true or false
end

function RiscVCore:DecodeFCSR(value)
    local v1 = bit.band(value, 0x1f)
    local v2 = bit.band(bit.rshift(value, 5), 0x7)
    self:DecodeFFLAGS(v1)
    self:DecodeFRM(v2)
end

function RiscVCore:ReadCSR(csr_address)
    if csr_address == 0x001 then
        return self:EncodeFFLAGS()
    elseif csr_address == 0x002 then
        return self:EncodeFRM()
    elseif csr_address == 0x003 then
        return self:EncodeFCSR()
    else
        assert(self.csr[csr_address] ~= nil, "CSR address " .. tostring(csr_address) .. " does not exist")
        return self.csr[csr_address]
    end
end

function RiscVCore:WriteCSR(csr_address, value)
    if csr_address == 0x001 then
        self:DecodeFFLAGS(value)
    elseif csr_address == 0x002 then
        self:DecodeFRM(value)
    elseif csr_address == 0x003 then
        self:DecodeFCSR(value)
    else
        assert(self.csr[csr_address] ~= nil, "CSR address " .. tostring(csr_address) .. " does not exist")
        self.csr[csr_address] = bit.band(value, 0xffffffff)
    end
end

function RiscVCore:InitCPU(init_handler)
    self.registers = {}
    self.fregisters = {}
    for i=0,31 do
        self.registers[i] = 0
        self.fregisters[i] = { flen = 32, value = 0 }
    end
    self.fcsr = {
        rm = 0, -- rounding mode
        nv = false, -- invalid operation
        dz = false, -- divide by zero
        of = false, -- overflow
        uf = false, -- underflow
        nx = false -- inexact
    }
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

    self.opcodes[bin("0000111")] = {
        name = "FLW",
        type = "I",
        handler = FPU_Load
    }

    self.opcodes[bin("0100111")] = {
        name = "FSW",
        type = "S",
        handler = FPU_Store
    }
    
    self.opcodes[bin("1000011")] = {
        name = "FMADD.S",
        type = "R4",
        handler = FPU_FMADD
    }
    
    self.opcodes[bin("1000111")] = {
        name = "FMSUB.S",
        type = "R4",
        handler = FPU_FMSUB
    }
    
    self.opcodes[bin("1001011")] = {
        name = "FNMSUB.S",
        type = "R4",
        handler = FPU_FNMSUB
    }
    
    self.opcodes[bin("1001111")] = {
        name = "FNMADD.S",
        type = "R4",
        handler = FPU_FNMADD
    }
    
    self.opcodes[bin("1010011")] = {
        name = "OP-FP",
        type = "R",
        handler = FPU_OP_FP
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

    elseif self.opecodes[opcode].type == "R4" then

        local rd = decode_rd(instruction)
        local funct3 = decode_funct3(instruction)
        local rs1 = decode_rs1(instruction)
        local rs2 = decode_rs2(instruction)
        local funct2 = bit.rshift(instruction, 25)
        local rs3 = decode_rs3(instruction) 

        self.opcodes[opcode].handler(self, rd, funct3, rs1, rs2, funct2, rs3)

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