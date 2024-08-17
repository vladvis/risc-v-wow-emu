function RunTests()
    tests = 
    {
        fib = { 
            init = Init_fib, 
            verify = Verify_fib
        }
        rv32i_arithmetics = {
            init = Init_rv32i_arithmetics,
            verify = Verify_rv32i_arithmetics
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