.section .data
test_data:
    .byte 0x12         # Byte 0
    .byte 0x34         # Byte 1
    .byte 0x56         # Byte 2
    .byte 0x78         # Byte 3
    .word 0x12345678   # Word at byte 4

store_data:
    .word 0x00000000       # Space to store a word

combined_data:
    .word 0x00000000       # Space to store a word

.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # Load Instruction Tests
    # ----------------------
    
    # Test 1: LB - Load Byte
    la x1, test_data
    lb x2, 0(x1)           # Load byte from address x1
    li x3, 0x12            # Expected result
    beq x2, x3, lb_pass

lb_fail:
    j done

lb_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 2: LH - Load Halfword
    lh x2, 1(x1)           # Load halfword starting from address x1 + 1
    li x3, 0x5634          # Expected result (Little Endian)
    beq x2, x3, lh_pass

lh_fail:
    j done

lh_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 3: LW - Load Word
    lw x2, 4(x1)           # Load word starting from address x1 + 4
    li x3, 0x12345678      # Expected result
    beq x2, x3, lw_pass

lw_fail:
    j done

lw_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 4: LBU - Load Byte Unsigned
    lbu x2, 2(x1)          # Load byte (unsigned) from address x1 + 2
    li x3, 0x56            # Expected result
    beq x2, x3, lbu_pass

lbu_fail:
    j done

lbu_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 5: LHU - Load Halfword Unsigned
    lhu x2, 1(x1)          # Load halfword (unsigned) starting from address x1 + 1
    li x3, 0x5634          # Expected result
    beq x2, x3, lhu_pass

lhu_fail:
    j done

lhu_pass:
    addi a0, a0, 1         # Increment return value if test passed


    # Store Instruction Tests
    # -----------------------
    
    # Test 6: SB - Store Byte
    la x1, store_data
    li x2, 0xAB
    sb x2, 0(x1)           # Store byte at address x1
    lbu x3, 0(x1)           # Load it back to verify
    beq x2, x3, sb_pass

sb_fail:
    j done

sb_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 7: SH - Store Halfword
    li x2, 0xCDEF
    sh x2, 0(x1)           # Store halfword at address x1
    lhu x3, 0(x1)           # Load it back to verify
    beq x2, x3, sh_pass

sh_fail:
    j done

sh_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 8: SW - Store Word
    li x2, 0x12345678
    sw x2, 0(x1)           # Store word at address x1
    lw x3, 0(x1)           # Load it back to verify
    beq x2, x3, sw_pass

sw_fail:
    j done

sw_pass:
    addi a0, a0, 1         # Increment return value if test passed


    # Load and Store Interaction Tests (Expanded)
    # -------------------------------------------
    
    # Test 9: SB and LB - Store Byte and Load Byte
    la x1, combined_data
    li x2, 0xAB
    sb x2, 0(x1)           # Store byte at address x1
    lbu x3, 0(x1)           # Load byte back to verify
    beq x2, x3, sb_lb_pass

sb_lb_fail:
    j done

sb_lb_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 10: SH and LH - Store Halfword and Load Halfword
    li x2, 0xCDEF
    sh x2, 0(x1)           # Store halfword at address x1
    lhu x3, 0(x1)           # Load halfword back to verify
    beq x2, x3, sh_lh_pass

sh_lh_fail:
    j done

sh_lh_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 11: SW and LW - Store Word and Load Word
    li x2, 0x12345678
    sw x2, 0(x1)           # Store word at address x1
    lw x3, 0(x1)           # Load word back to verify
    beq x2, x3, sw_lw_pass

sw_lw_fail:
    j done

sw_lw_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 12: Store Word, Load Byte (SW and LB)
    li x2, 0x12345678
    sw x2, 0(x1)           # Store word at address x1
    lb x3, 0(x1)           # Load byte (should be 0x78 in Little Endian)
    li x4, 0x78
    beq x3, x4, sw_lb_pass

sw_lb_fail:
    j done

sw_lb_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 13: Store Word, Load Halfword (SW and LH)
    lh x3, 0(x1)           # Load halfword (should be 0x5678 in Little Endian)
    li x4, 0x5678
    beq x3, x4, sw_lh_pass

sw_lh_fail:
    j done

sw_lh_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 14: Store Word, Load Byte Unsigned (SW and LBU)
    lbu x3, 1(x1)          # Load byte (should be 0x56 from the second byte)
    li x4, 0x56
    beq x3, x4, sw_lbu_pass

sw_lbu_fail:
    j done

sw_lbu_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 15: Store Halfword, Load Byte (SH and LB)
    li x2, 0xABCD
    sh x2, 0(x1)           # Store halfword at address x1
    lbu x3, 0(x1)           # Load byte (should be 0xCD in Little Endian)
    li x4, 0xCD
    beq x3, x4, sh_lb_pass

sh_lb_fail:
    j done

sh_lb_pass:
    addi a0, a0, 1         # Increment return value if test passed

    # Test 16: Store Halfword, Load Byte Unsigned (SH and LBU)
    lbu x3, 1(x1)          # Load byte (should be 0xAB from the second byte)
    li x4, 0xAB
    beq x3, x4, sh_lbu_pass

sh_lbu_fail:
    j done

sh_lbu_pass:
    addi a0, a0, 1         # Increment return value if test passed

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93              # Syscall number for exit
    ecall                  # Make the syscall
