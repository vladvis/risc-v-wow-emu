
function Load_Chunkrv32i_immediate_arithmetics0(CPU)
    local mem_sections = {
    
        [0x80000000] = 0x513,
        [0x80000004] = 0xa00093,
        [0x80000008] = 0x1408113,
        [0x8000000c] = 0x1e00193,
        [0x80000010] = 0x310463,
        [0x80000014] = 0xc80006f,
        [0x80000018] = 0x150513,
        [0x8000001c] = 0xa00093,
        [0x80000020] = 0x140a113,
        [0x80000024] = 0x100193,
        [0x80000028] = 0x310463,
        [0x8000002c] = 0xb00006f,
        [0x80000030] = 0x150513,
        [0x80000034] = 0xa00093,
        [0x80000038] = 0x140b113,
        [0x8000003c] = 0x100193,
        [0x80000040] = 0x310463,
        [0x80000044] = 0x980006f,
        [0x80000048] = 0x150513,
        [0x8000004c] = 0xc00093,
        [0x80000050] = 0xa0f113,
        [0x80000054] = 0x800193,
        [0x80000058] = 0x310463,
        [0x8000005c] = 0x800006f,
        [0x80000060] = 0x150513,
        [0x80000064] = 0xc00093,
        [0x80000068] = 0xa0e113,
        [0x8000006c] = 0xe00193,
        [0x80000070] = 0x310463,
        [0x80000074] = 0x680006f,
        [0x80000078] = 0x150513,
        [0x8000007c] = 0xc00093,
        [0x80000080] = 0xa0c113,
        [0x80000084] = 0x600193,
        [0x80000088] = 0x310463,
        [0x8000008c] = 0x500006f,
        [0x80000090] = 0x150513,
        [0x80000094] = 0x100093,
        [0x80000098] = 0x209113,
        [0x8000009c] = 0x400193,
        [0x800000a0] = 0x310463,
        [0x800000a4] = 0x380006f,
        [0x800000a8] = 0x150513,
        [0x800000ac] = 0x400093,
        [0x800000b0] = 0x10d113,
        [0x800000b4] = 0x200193,
        [0x800000b8] = 0x310463,
        [0x800000bc] = 0x200006f,
        [0x800000c0] = 0x150513,
        [0x800000c4] = 0xffc00093,
        [0x800000c8] = 0x4010d113,
        [0x800000cc] = 0xffe00193,
        [0x800000d0] = 0x310463,
        [0x800000d4] = 0x80006f,
        [0x800000d8] = 0x150513,
        [0x800000dc] = 0x5d00893,
        [0x800000e0] = 0x73,
        [0x0] = 0x0,
        [0x4] = 0x0,
        [0x8] = 0x0,
        [0xc] = 0x0,
        [0x10] = 0x0,
        [0x14] = 0x0,
        [0x18] = 0x0,
        [0x1c] = 0x0,
        [0x20] = 0x0,
        [0x24] = 0x0,
        [0x28] = 0x0,
        [0x2c] = 0x0,
        [0x30] = 0x0,
        [0x34] = 0x0,
        [0x38] = 0x0,
        [0x3c] = 0x0,
        [0x40] = 0x0,
        [0x44] = 0x0,
        [0x48] = 0x0,
        [0x4c] = 0x0,
        [0x50] = 0x0,
        [0x54] = 0x0,
        [0x58] = 0x0,
        [0x5c] = 0x0,
        [0x60] = 0x0,
        [0x64] = 0x0,
        [0x68] = 0x0,
        [0x6c] = 0x0,
        [0x70] = 0x0,
        [0x74] = 0x0,
        [0x78] = 0x0,
        [0x7c] = 0x0,
        [0x80] = 0x0,
        [0x84] = 0x0,
        [0x88] = 0x0,
        [0x8c] = 0x0,
        [0x90] = 0x0,
        [0x94] = 0x0,
        [0x98] = 0x0,
        [0x9c] = 0x0,
        [0xa0] = 0x0,
        [0xa4] = 0x0,
        [0xa8] = 0x0,
        [0xac] = 0x0,
        [0xb0] = 0x0,
        [0xb4] = 0x0,
        [0xb8] = 0x0,
        [0xbc] = 0x0,
        [0xc0] = 0x0,
        [0xc4] = 0x0,
        [0xc8] = 0x0,
        [0xcc] = 0x0,
        [0xd0] = 0x0,
        [0xd4] = 0x0,
        [0xd8] = 0x0,
        [0xdc] = 0x0,
        [0xe0] = 0x0,
        [0xe4] = 0x0,
        [0xe8] = 0x0,
        [0xec] = 0x0,
        [0xf0] = 0x0,
        [0xf4] = 0x0,
        [0xf8] = 0x0,
        [0xfc] = 0x0,
        [0x100] = 0x0,
        [0x104] = 0x0,
        [0x108] = 0x0,
        [0x10c] = 0x0,
        [0x110] = 0x0,
        [0x114] = 0x0,
        [0x118] = 0x0,
        [0x11c] = 0x0,
        [0x120] = 0x0,
        [0x124] = 0x0,
        [0x128] = 0x0,
        [0x12c] = 0x0,
        [0x130] = 0x0,
        [0x134] = 0x0,
        [0x138] = 0x0,
        [0x13c] = 0x0,
        [0x140] = 0x0,
        [0x144] = 0x0,
        [0x148] = 0x0,
        [0x14c] = 0x0,
        [0x150] = 0x0,
        [0x154] = 0x0,
        [0x158] = 0x0,
        [0x15c] = 0x0,
        [0x160] = 0x0,
        [0x164] = 0x0,
        [0x168] = 0x0,
        [0x16c] = 0x0,
        [0x170] = 0x0,
        [0x174] = 0x0,
        [0x178] = 0x0,
        [0x17c] = 0x0,
        [0x180] = 0x0,
        [0x184] = 0x0,
        [0x188] = 0x0,
        [0x18c] = 0x0,
        [0x190] = 0x0,
        [0x194] = 0x0,
        [0x198] = 0x0,
        [0x19c] = 0x0,
        [0x1a0] = 0x0,
        [0x1a4] = 0x0,
        [0x1a8] = 0x0,
        [0x1ac] = 0x0,
        [0x1b0] = 0x0,
        [0x1b4] = 0x0,
        [0x1b8] = 0x0,
        [0x1bc] = 0x0,
        [0x1c0] = 0x0,
        [0x1c4] = 0x0,
        [0x1c8] = 0x0,
        [0x1cc] = 0x0,
        [0x1d0] = 0x0,
        [0x1d4] = 0x0,
        [0x1d8] = 0x0,
        [0x1dc] = 0x0,
        [0x1e0] = 0x0,
        [0x1e4] = 0x0,
        [0x1e8] = 0x0,
        [0x1ec] = 0x0,
        [0x80001000] = 0x0,
    }
    CPU:SetMemory(CPU, mem_sections)
end


function Init_rv32i_immediate_arithmetics(CPU)
    CPU.entrypoint = 0x80000000
    CPU.stack_pointer = 0x7ff00000
    CPU.heap_start = 0x80001000

    
    Load_Chunkrv32i_immediate_arithmetics0(CPU)
    
    CPU:StoreRegister(2, 0x7ff00000)
    CPU.memory:InitMemoryRange(0x7ee00000, 0x7ff00004)
end