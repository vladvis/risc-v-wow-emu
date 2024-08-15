local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata("WowLua", "Version") or "SVN"

RiskVCore = {
    VERSION = "RiskVEmulator v" .. version .. " for World of Warcraft"
}

function RiskVCore:ParseInstruction(instruction)
    assert(type(instruction) == "number", "instruction not a number")

    opcode = bit.band(instruction, 127)

    message(opcode)
end

RiskVCore:ParseInstruction("nope")