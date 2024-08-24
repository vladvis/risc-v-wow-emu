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
            --assert(false, "Unsupported fd")
        end
        CPU:StoreRegister(10, count)
    elseif syscall_num == 101 then -- togglewindow
        print("togglewindow was called")
        ToggleWindow()
    elseif syscall_num == 102 then -- render_framebuffer
        local t = GetTime()
        local delta = t - CPU.last_frame
        local total_delta = t - CPU.start_time
        print(string.format("render_framebuffer was called (id %d ; frame %fs ; total %fs)", CPU.frame_cnt, delta, total_delta))
        local framebuffer_addr = CPU:LoadRegister(10)
        RenderFrame(CPU, framebuffer_addr)
        CPU.is_running = 0
        CPU.last_frame = t
        CPU.frame_cnt = CPU.frame_cnt + 1
        C_Timer.After(0.01, Resume)
    elseif syscall_num == 103 then -- get_key_state
        -- print("get_key_state was called")
        local key = CPU:LoadRegister(10)
        if CPU.pressed_keys[key] then
            CPU:StoreRegister(10, 1)
        else
            CPU:StoreRegister(10, 0)
        end
    elseif syscall_num == 104 then -- sleep
        local msec = CPU:LoadRegister(10)
        CPU.is_running = 0
        C_Timer.After(msec / 1000, Resume)
    elseif syscall_num == 105 then -- draw_column
        -- void DG_DrawColumn(uint8_t* dest, uint8_t* dc_colormap, uint8_t* dc_source, int frac, int frac_step, int count) {
        local dest = CPU:LoadRegister(10)
        local dc_colormap = CPU:LoadRegister(11)
        local dc_source = CPU:LoadRegister(12)
        local frac = CPU:LoadRegister(13)
        local frac_step = CPU:LoadRegister(14)
        local count = CPU:LoadRegister(15)

        --do { ... } while (count--);
        for i=count,0,-1 do
        -- *dest = dc_colormap[dc_source[(frac>>FRACBITS)&127]];
            local source_idx = bit.band(bit.rshift(frac, 16), 127)
            local colormap_idx =  CPU.memory:Read(dc_source + source_idx, 1)
            local pixel_value = CPU.memory:Read(dc_colormap + colormap_idx, 1)
            CPU.memory:Write(dest, pixel_value, 1)

            dest = dest + 320;
            frac = frac + frac_step
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
        local clock_id = CPU:LoadRegister(10)
        local struct_addr = CPU:LoadRegister(11)
        CPU.memory:Write(struct_addr, time(), 4)
    else
        --assert(false, "syscall " .. tostring(syscall_num) .. " is not implemented")
    end
end