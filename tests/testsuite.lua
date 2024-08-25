function RVEMU_RunTests()
    local tests = 
    {
        --[[fib = { 
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
        },
        rv32i_comparison = {
            init = Init_rv32i_comparison,
            verify = Verify_rv32i_comparison
        },
        rv32i_loadstore = {
            init = Init_rv32i_loadstore,
            verify = Verify_rv32i_loadstore
        },
        rv32i_controlflow = {
            init = Init_rv32i_controlflow,
            verify = Verify_rv32i_controlflow
        },
        rv32m = {
            init = Init_rv32m,
            verify = Verify_rv32m
        },
        rv32f = {
            init = Init_rv32f,
            verify = Verify_rv32f
        },
        simpsons_fp_integral = {
            init = Init_simpsons_fp_integral,
            verify = Verify_simpsons_fp_integral
        },
        mandelbrot = {
            init = Init_mandelbrot,
            verify = Verify_mandelbrot
        },
        cube = {
            init = Init_cube,
            verify = Verify_cube
        }, 
        malloc = {
            init = Init_malloc,
            verify = Verify_malloc
        },
        memset_short = {
            init = Init_memset_short,
            verify = Verify_memset_short
        },]]
        doom = {
            init = Init_doom,
            verify = Verify_doom
        }
    }

    for name, test in pairs(tests) do
        print(string.format("Starting test %s...", name))
        CPU = RVEMU_GetCore()
        CPU:InitCPU(test.init)
        CPU:Run()
        local result = test.verify(CPU)
        print(string.format("Test %s result = %s", name, tostring(result)))
    end
end

RVEMU_RunTests()
