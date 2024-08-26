local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata("RiscVEmu", "Version") or "SVN"
local VERSION = "RiscVEmulator v" .. version .. " for World of Warcraft"

-- Resumes the execution of the CPU if it is not stopped.
-- @param CPU The CPU object to resume.
function RVEMU_Resume(CPU)
    --print("resume", CPU.counter)
    if CPU.is_stopped ~= 1 then
        CPU.is_running = 1
        CPU:Run()
    end
end

-- Initializes and returns a RISC-V core object.
-- @return A RISC-V core object with registers, memory, and instruction handling.
function RVEMU_GetCore()
    local RiscVCore = {
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

    -- Loads the value from the specified register.
    -- @param source The register index to load the value from.
    -- @return The value stored in the specified register.
    function RiscVCore:LoadRegister(source)
        --assert((source >= 0) and (source <= 31), "register x".. tostring(source) .." isn't existed (load)")
        return self.registers[source]
    end

    -- Stores a value into the specified register.
    -- @param dest The register index to store the value into.
    -- @param value The value to store in the register.
    function RiscVCore:StoreRegister(dest, value)
        if dest ~= 0 then
            --assert((dest >= 1) and (dest <= 31), "register x".. tostring(dest) .." isn't existed (store)")
            self.registers[dest] = bit.band(value, 0xffffffff)
        end
    end

    -- Stores a value into the program counter (PC) register.
    -- @param value The value to store in the PC register.
    --[[function RiscVCore:StorePC(value)
        --assert(value % 4 == 0, "pc must be aligned")
        self.jumped = true
        self.registers.pc = bit.band(value, 0xffffffff)
    end]]

    -- Sets the memory for the CPU with the given memory map.
    -- @param CPU The CPU object to set the memory for.
    -- @param mem The memory map to set.
    function RiscVCore:SetMemory(CPU, mem)
        for k, v in pairs(mem) do
            CPU.memory:Set(k, v)
        end
    end

    -- Initializes the Control and Status Registers (CSRs) for the CPU.
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
        return self:EncodeFFLAGS() + bit.lshift(self:EncodeFRM(), 5)
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
            --assert(self.csr[csr_address] ~= nil, "CSR address " .. tostring(csr_address) .. " does not exist")
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
            --assert(self.csr[csr_address] ~= nil, "CSR address " .. tostring(csr_address) .. " does not exist")
            self.csr[csr_address] = bit.band(value, 0xffffffff)
        end
    end

    -- Initializes the CPU with registers, memory, and instruction handlers.
    -- @param init_handler The initialization handler function for the CPU.
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
            handler = RVEMU_BaseInstructions_LUI
        }

        self.opcodes[bin("0010111")] = {
            name = "AUIPC",
            type = "U",
            handler = RVEMU_BaseInstructions_AUIPC
        }

        self.opcodes[bin("1101111")] = {
            name = "JAL",
            type = "J",
            handler = RVEMU_BaseInstructions_JAL
        }

        self.opcodes[bin("1100111")] = {
            name = "JALR",
            type = "I",
            handler = RVEMU_BaseInstructions_JALR
        }

        self.opcodes[bin("1100011")] = {
            name = "BRANCH",
            type = "B",
            handler = RVEMU_BaseInstructions_BRANCH
        }

        self.opcodes[bin("0000011")] = {
            name = "LOAD",
            type = "I",
            handler = RVEMU_BaseInstructions_LOAD
        }

        self.opcodes[bin("0100011")] = {
            name = "STORE",
            type = "S",
            handler = RVEMU_BaseInstructions_STORE
        }

        self.opcodes[bin("0010011")] = {
            name = "OP-IMM",
            type = "I",
            handler = RVEMU_BaseInstructions_OP_IMM
        }

        self.opcodes[bin("0110011")] = {
            name = "OP",
            type = "R",
            handler = RVEMU_BaseInstructions_OP
        }

        self.opcodes[bin("0001111")] = {
            name = "MISC-MEM",
            type = "I",
            handler = RVEMU_BaseInstructions_MISC_MEM
        }

        self.opcodes[bin("1110011")] = {
            name = "SYSTEM",
            type = "I",
            handler = RVEMU_BaseInstructions_SYSTEM
        }

        self.opcodes[bin("0000111")] = {
            name = "FLW",
            type = "I",
            handler = RVEMU_FPU_Load
        }

        self.opcodes[bin("0100111")] = {
            name = "FSW",
            type = "S",
            handler = RVEMU_FPU_Store
        }
        
        self.opcodes[bin("1000011")] = {
            name = "FMADD.S",
            type = "R4",
            handler = RVEMU_FPU_FMADD
        }
        
        self.opcodes[bin("1000111")] = {
            name = "FMSUB.S",
            type = "R4",
            handler = RVEMU_FPU_FMSUB
        }
        
        self.opcodes[bin("1001011")] = {
            name = "FNMSUB.S",
            type = "R4",
            handler = RVEMU_FPU_FNMSUB
        }
        
        self.opcodes[bin("1001111")] = {
            name = "FNMADD.S",
            type = "R4",
            handler = RVEMU_FPU_FNMADD
        }
        
        self.opcodes[bin("1010011")] = {
            name = "OP-FP",
            type = "R",
            handler = RVEMU_FPU_OP_FP
        }

        self.frame = RVEMU_GetFrame(self)

        self:InitCSR()
        self.memory = RVEMU_GetMemory()
        self.instr_cache = {}
        self.addr_cache = {}

        self.pressed_keys = {}
        self.sticky_keys = {}

        self.entrypoint = 0

        init_handler(self)

        self.registers.pc = self.entrypoint

        self.jumped = false
        self.is_running = 1
        self.is_stopped = 0
        self.counter = 0
        
        self.last_frame = GetTime()
        self.start_time = GetTime()
        self.frame_cnt = 0

    end

    function RiscVCore:DecodeInstruction(instruction)
        local bit_band = bit.band
        local bit_rshift = bit.rshift
        local bit_bor = bit.bor
        
        local opcodes = self.opcodes
        local opcode = bit_band(instruction, 0x7f)
        local opcode_info = opcodes[opcode]
        local instr_type = opcode_info.type
        local handler = opcode_info.handler
        local result = nil
        
        if instr_type == "U" then
            local rd = decode_rd(instruction)
            local imm_value = bit_band(instruction, 0xfffff000)
            result = { rd, imm_value }

        elseif instr_type == "J" then
            local rd = decode_rd(instruction)
            local imm_value = bit_band(bit_rshift(instruction, 20), 0x7fe)
            imm_value = bit_bor(imm_value, bit_band(bit_rshift(instruction, 9), 0x800))
            imm_value = bit_bor(imm_value, bit_band(instruction, 0xff000))
            imm_value = bit_bor(imm_value, bit_band(bit_rshift(instruction, 11), 0x100000))
            imm_value = RVEMU_set_sign(imm_value, 21)
            result = { rd, imm_value }

        elseif instr_type == "I" then
            local rd = decode_rd(instruction)
            local funct3 = decode_funct3(instruction)
            local rs1 = decode_rs1(instruction)
            local imm_value = bit_band(bit_rshift(instruction, 20), 0xfff)
            imm_value = RVEMU_set_sign(imm_value, 12)
            result = { rd, funct3, rs1, imm_value }

        elseif instr_type == "B" then
            local funct3 = decode_funct3(instruction)
            local rs1 = decode_rs1(instruction)
            local rs2 = decode_rs2(instruction)
            local imm_value = bit_band(bit_rshift(instruction, 7), 0x1e)
            imm_value = bit_bor(imm_value, bit_band(bit_rshift(instruction, 20), 0x7e0))
            imm_value = bit_bor(imm_value, bit_band(bit.lshift(instruction, 4), 0x800))
            imm_value = bit_bor(imm_value, bit_band(bit_rshift(instruction, 19), 0x1000))
            imm_value = RVEMU_set_sign(imm_value, 13)
            result = { funct3, rs1, rs2, imm_value }

        elseif instr_type == "S" then
            local funct3 = decode_funct3(instruction)
            local rs1 = decode_rs1(instruction)
            local rs2 = decode_rs2(instruction)
            local imm_value = bit_bor(bit.lshift(bit_rshift(instruction, 25), 5), decode_rd(instruction))
            imm_value = RVEMU_set_sign(imm_value, 12)
            result = { funct3, rs1, rs2, imm_value }

        elseif instr_type == "R" then
            local rd = decode_rd(instruction)
            local funct3 = decode_funct3(instruction)
            local rs1 = decode_rs1(instruction)
            local rs2 = decode_rs2(instruction)
            local funct7 = bit_rshift(instruction, 25)
            result = { rd, funct3, rs1, rs2, funct7 }

        elseif instr_type == "R4" then
            local rd = decode_rd(instruction)
            local funct3 = decode_funct3(instruction)
            local rs1 = decode_rs1(instruction)
            local rs2 = decode_rs2(instruction)
            local funct2 = bit_rshift(instruction, 25)
            local rs3 = decode_rs3(instruction)
            result = { rd, funct3, rs1, rs2, funct2, rs3 }
        end
        return opcodes[opcode].handler(self, unpack(result))
    end

    -- Executes a single instruction step in the CPU.
    function RiscVCore:Step()
        local counter = self.counter
        self.counter = counter - 1
        if counter == 0 then
            counter = 1000000
            self:MaybeYieldCPU()
        end

        local registers = self.registers
        local pc = registers.pc
        local addr_cache = self.addr_cache

        local decoded_instr = addr_cache[pc]
        if decoded_instr == nil then
            local instruction = self.memory:Get(pc)
            local instr_cache = self.instr_cache

            decoded_instr = instr_cache[instruction]
            if decoded_instr == nil then
                decoded_instr = self:DecodeInstruction(instruction)
                instr_cache[instruction] = decoded_instr
            end
            addr_cache[pc] = decoded_instr
        end

        decoded_instr()
    end

    -- Checks if the CPU should yield execution and schedules a resume if needed.
    function RiscVCore:MaybeYieldCPU()
        local now = time()
        if now - self.last_sleep > 2 then
            self.is_running = 0
            --C_Timer.After(0.01, function() RVEMU_Resume(self) end)
            RunNextFrame(function() RVEMU_Resume(self) end)
        end
    end

    -- Prints the values of all CPU registers to the console.
    function RiscVCore:PrintRegs()
        for i = 0, 31 do
            print(string.format("x%d = 0x%x", i, self.registers[i]))
        end
        print(string.format("pc = 0x%x", self.registers.pc))
    end

    -- Stops the execution of the CPU and hides the frame.
    function RiscVCore:Stop()
        self.frame:Hide()
        self.is_stopped = 1
        self.is_running = 0
    end

    -- Runs the CPU, executing instructions until stopped.
    function RiscVCore:Run()
        self.last_sleep = time()
        while self.is_running == 1 do
            self:Step()
        end
    end

    return RiscVCore
end
