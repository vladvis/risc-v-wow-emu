function RunTests()
    tests = 
    {
        [1] = { 
            init = Init_Test1, 
            verify = Verify_Test1
        }
    }

    for i = 1, table.getn(tests) do
        local test = tests[i]
        print(string.format("Starting test #%d...", i))
        RiscVCore:InitCPU(test.init)
        RiscVCore:Run()
        local result = test.verify(RiscVCore)
        print(string.format("Test #%d result = %s", i, tostring(result)))
    end
end

RunTests()