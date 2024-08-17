function RunTests()
    tests = 
    {
        fib = { 
            init = Init_fib, 
            verify = Verify_fib
        },
        rv32i_arithmetics = {
            init = Init_rv32i_arithmetics,
            verify = Verify_rv32i_arithmetics
        },
        rv32i_immediate_arithmetics = {
            init = Init_rv32i_immediate_arithmetics,
            verify = Verify_rv32i_immediate_arithmetics
        },
        rv32i_logical = {
            init = Init_rv32i_logical,
            verify = Verify_rv32i_logical
        },
        rv32i_shift = {
            init = Init_rv32i_shift,
            verify = Verify_rv32i_shift
        }
    }

    for name, test in pairs(tests) do
        print(string.format("Starting test %s...", name))
        RiscVCore:InitCPU(test.init)
        RiscVCore:Run()
        local result = test.verify(RiscVCore)
        print(string.format("Test %s result = %s", name, tostring(result)))
    end
end

RunTests()