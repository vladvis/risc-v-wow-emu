function handle_syscall(CPU, syscall_num)
    if syscall_num == 93 then -- exit
        CPU.is_running = 0
        CPU.exit_code = CPU:LoadRegister(10)
        print(string.format("Got EXIT(%d)", CPU.exit_code))
    elseif syscall_num == 64 then -- write
        local s = ""
        local fd = CPU:LoadRegister(10)
        local buf = CPU:LoadRegister(11)
        local count = CPU:LoadRegister(12)
        for i = 0, count-1 do
            s = s .. string.char(CPU.memory:Read(buf + i, 1))
        end
        if fd == 1 then -- stdout
            print(s)
        elseif fd == 2 then -- stderr
            print("\124cffff0000" .. s .. "\124r")
        else
            assert(false, "Unsupported fd")
        end
        CPU:StoreRegister(10, count)
    elseif syscall_num == 101 then -- togglewindow
        print("togglewindow was called")
        ToggleWindow()
    elseif syscall_num == 102 then -- render_framebuffer
        print("render_framebuffer was called")
        local framebuffer_addr = CPU:LoadRegister(10)
        RenderFrame(CPU, framebuffer_addr)
        CPU.is_running = 0
        C_Timer.After(0.01, Resume)
    elseif syscall_num == 103 then -- get_key_state
        print("get_key_state was called")
        local key = CPU:LoadRegister(10)
        if CPU.pressed_keys[key] then
            CPU:StoreRegister(10, 1)
        else
            CPU:StoreRegister(10, 0)
        end
    elseif syscall_num == 80 then -- newfstat
        -- local stat_addr = CPU:LoadRegister(10)
        -- CPU.memory:Write(stat_addr + 32, 512, 4) -- stat.st_blksize = 512
    elseif syscall_num == 57 then -- fclose
        -- 
    elseif syscall_num == 214 then -- brk
        local addr = CPU:LoadRegister(10)
        if addr == 0 then
            CPU:StoreRegister(10, CPU.heap_start)
        else
            for x = CPU.heap_start, addr, 4 do
                CPU.memory:Set(x, 0)
            end
            CPU:StoreRegister(10, addr)
            CPU.heap_start = addr
        end
    elseif syscall_num == 403 then -- clock_gettime
        print(CPU:LoadRegister(10))
        assert(false, "hui")
    else
        assert(false, "syscall " .. tostring(syscall_num) .. " is not implemented")
    end
end