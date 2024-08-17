function Verify_fib(CPU)
    local valid = true
    local valid_fib = 
    {
        [0] = 0,
        [1] = 1,
        [2] = 1,
        [3] = 2,
        [4] = 3,
        [5] = 5,
        [6] = 8,
        [7] = 13,
        [8] = 21,
        [9] = 34
    }

    local res_addr = 0x1118c

    for i = 0, 9 do
        if CPU.memory:Get(res_addr + i*4) ~= valid_fib[i] then
            valid = false
            break
        end
    end

    return valid
end
