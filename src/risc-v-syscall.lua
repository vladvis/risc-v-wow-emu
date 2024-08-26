function RVEMU_handle_syscall(CPU, syscall_num)
    local registers = CPU.registers
    if syscall_num == 93 then -- exit
        CPU.is_running = 0
        CPU.exit_code = registers[10]
        print(string.format("Got EXIT(%d)", CPU.exit_code))
    elseif syscall_num == 64 then -- write
        local s = ""
        local fd = registers[10]
        local buf = registers[11]
        local count = registers[12]
        for i = 0, count-1 do
            s = s .. string.char(CPU.memory:Read(1)(buf + i))
        end
        if fd == 1 then -- stdout
            print(s)
        elseif fd == 2 then -- stderr
            print("\124cffff0000" .. s .. "\124r")
        else
            --assert(false, "Unsupported fd")
        end
        CPU:StoreRegister(10, count)
        CPU.is_running = 0
        RunNextFrame(function() RVEMU_Resume(CPU) end)
    elseif syscall_num == 101 then -- togglewindow
        print("togglewindow was called")
        CPU.frame:ToggleWindow()
    elseif syscall_num == 102 then -- render_framebuffer
        local t = GetTime()
        local delta = t - CPU.last_frame
        local total_delta = t - CPU.start_time
        print(string.format("render_framebuffer was called (id %d ; frame %fs ; total %fs)", CPU.frame_cnt, delta, total_delta))
        local framebuffer_addr = registers[10]
        CPU.frame:RenderFrame(framebuffer_addr)
        CPU.is_running = 0
        CPU.last_frame = t
        CPU.frame_cnt = CPU.frame_cnt + 1
        -- C_Timer.After(0.01, function() RVEMU_Resume(CPU) end)
        RunNextFrame(function() RVEMU_Resume(CPU) end)
    elseif syscall_num == 103 then -- get_key_state
        -- print("get_key_state was called")
        local key = registers[10]
        if CPU.pressed_keys[key] or CPU.sticky_keys[key] then
            CPU.sticky_keys[key] = false
            CPU:StoreRegister(10, 1)
        else
            CPU:StoreRegister(10, 0)
        end
    elseif syscall_num == 104 then -- sleep
        local msec = registers[10]
        -- print(msec)
        CPU.is_running = 0
        C_Timer.After(msec / 1000, function() RVEMU_Resume(CPU) end)
    elseif syscall_num == 105 then -- draw_column
        -- void DG_DrawColumn(uint8_t* dest, uint8_t* dc_colormap, uint8_t* dc_source, int frac, int frac_step, int count) {
        local dest = registers[10]
        local dc_colormap = registers[11]
        local dc_source = registers[12]
        local frac = registers[13]
        local frac_step = registers[14]
        local count = registers[15]
        local write1 = CPU.memory:Write(1)
        local read1 = CPU.memory:Read(1)
        --do { ... } while (count--);
        for i=count,0,-1 do
        -- *dest = dc_colormap[dc_source[(frac>>FRACBITS)&127]];
            local source_idx = bit.band(bit.rshift(frac, 16), 127)
            local colormap_idx =  read1(dc_source + source_idx)
            local pixel_value = read1(dc_colormap + colormap_idx)
            write1(dest, pixel_value)

            dest = dest + 320;
            frac = frac + frac_step
        end

    elseif syscall_num == 106 then -- draw_span
        local dest = registers[10]
        local ds_colormap = registers[11]
        local ds_source = registers[12]
        local position = registers[13]
        local step = registers[14]
        local count = registers[15]
        local write1 = CPU.memory:Write(1)
        local read1 = CPU.memory:Read(1)
        
        for i = 0, count do
            local ytemp = bit.band(bit.rshift(position, 4), 0x0fc0)
            local xtemp = bit.rshift(position, 26)
            local spot = bit.bor(xtemp, ytemp)

            local source_val = read1(ds_source + spot)
            local val = read1(ds_colormap + source_val)
            write1(dest, val)

            dest = dest + 1
            position = position + step
        end
        
    elseif syscall_num == 80 then -- newfstat
        -- local stat_addr = registers[10]
        -- CPU.memory:Write(stat_addr + 32, 512, 4) -- stat.st_blksize = 512
    elseif syscall_num == 57 then -- fclose
        -- 
    elseif syscall_num == 214 then -- brk
        local addr = registers[10]
        if addr == 0 then
            CPU:StoreRegister(10, CPU.heap_start)
        else
            for x = CPU.heap_start, addr, 4 do
                CPU.memory:Set(x, 0)
            end
            CPU:StoreRegister(10, addr)
            CPU.heap_start = addr
        end

    else
        --assert(false, "syscall " .. tostring(syscall_num) .. " is not implemented")
    end
end