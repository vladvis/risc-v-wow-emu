.section .data
test_data:
    .word 0x00000000       # Space to store intermediate results

.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # MUL Instruction Tests
    # ---------------------
    
    # Test 1: Basic MUL - Multiply two positive numbers
    li a1, 6
    li a2, 7
    mul a3, a1, a2          # a3 = a1 * a2 = 42
    li a4, 42
    beq a3, a4, mul_pass

mul_fail:
    j done

mul_pass:
    addi a0, a0, 1          # Increment return value if test passed

    # Test 2: MUL Overflow - Multiply two large positive numbers
    li a1, 0x7FFFFFFF       # Largest positive signed integer
    li a2, 2
    mul a3, a1, a2          # a3 = a1 * a2, expect overflow
    li a4, 0xFFFFFFFE       # Expected lower 32 bits of the result
    beq a3, a4, mul_overflow_pass

mul_overflow_fail:
    j done

mul_overflow_pass:
    addi a0, a0, 1          # Increment return value if test passed


    # MULH Instruction Tests
    # ----------------------
    
    # Test 3: Basic MULH - Multiply two positive numbers
    li a1, 0x00010000
    li a2, 0x00010000
    mulh a3, a1, a2         # a3 = (a1 * a2)[63:32] = 1
    li a4, 1
    beq a3, a4, mulh_pass

mulh_fail:
    j done

mulh_pass:
    addi a0, a0, 1          # Increment return value if test passed

    # Test 4: MULH with Overflow - Large numbers
    li a1, 0x7FFFFFFF
    li a2, 0x7FFFFFFF
    mulh a3, a1, a2         # a3 = (a1 * a2)[63:32], expect overflow handling
    li a4, 0x3FFFFFFF       # Expected upper 32 bits of the result
    beq a3, a4, mulh_overflow_pass

mulh_overflow_fail:
    j done

mulh_overflow_pass:
    addi a0, a0, 1          # Increment return value if test passed


    # MULHSU Instruction Tests
    # ------------------------
    
    # Test 5: MULHSU - Signed * Unsigned multiplication
    li a1, -2               # -2 (signed)
    li a2, 3                # 3 (unsigned)
    mulhsu a3, a1, a2       # a3 = (a1 * a2)[63:32] = -1
    li a4, -1
    beq a3, a4, mulhsu_pass

mulhsu_fail:
    j done

mulhsu_pass:
    addi a0, a0, 1          # Increment return value if test passed


    # MULHU Instruction Tests
    # -----------------------
    
    # Test 6: Basic MULHU - Unsigned multiplication
    li a1, 0xFFFFFFFF       # Largest unsigned 32-bit value
    li a2, 0xFFFFFFFF
    mulhu a3, a1, a2        # a3 = (a1 * a2)[63:32] = 0xFFFFFFFE
    li a4, 0xFFFFFFFE
    beq a3, a4, mulhu_pass

mulhu_fail:
    j done

mulhu_pass:
    addi a0, a0, 1          # Increment return value if test passed


    # DIV Instruction Tests
    # ---------------------
    
    # Test 7: Basic DIV - Divide two positive numbers
    li a1, 42
    li a2, 7
    div a3, a1, a2          # a3 = a1 / a2 = 6
    li a4, 6
    beq a3, a4, div_pass

div_fail:
    j done

div_pass:
    addi a0, a0, 1          # Increment return value if test passed

    # Test 8: DIV Overflow - Divide by zero
    li a1, 42
    li a2, 0
    div a3, a1, a2          # a3 = a1 / a2, expect -2^31
    li a4, -1
    beq a3, a4, div_overflow_pass

div_overflow_fail:
    j done

div_overflow_pass:
    addi a0, a0, 1          # Increment return value if test passed


    # DIVU Instruction Tests
    # ----------------------
    
    # Test 9: Basic DIVU - Unsigned division
    li a1, 42
    li a2, 7
    divu a3, a1, a2         # a3 = a1 / a2 = 6
    li a4, 6
    beq a3, a4, divu_pass

divu_fail:
    j done

divu_pass:
    addi a0, a0, 1          # Increment return value if test passed

    # Test 10: DIVU Overflow - Divide by zero
    li a1, 42
    li a2, 0
    divu a3, a1, a2         # a3 = a1 / a2, expect 0xFFFFFFFF
    li a4, 0xFFFFFFFF       # Maximum unsigned value (2^32 - 1)
    beq a3, a4, divu_overflow_pass

divu_overflow_fail:
    j done

divu_overflow_pass:
    addi a0, a0, 1          # Increment return value if test passed


    # REM Instruction Tests
    # ---------------------
    
    # Test 11: Basic REM - Remainder of division
    li a1, 43
    li a2, 7
    rem a3, a1, a2          # a3 = a1 % a2 = 1
    li a4, 1
    beq a3, a4, rem_pass

rem_fail:
    j done

rem_pass:
    addi a0, a0, 1          # Increment return value if test passed

    # Test 12: REM Overflow - Divide by zero
    li a1, 43
    li a2, 0
    rem a3, a1, a2          # a3 = a1 % a2, expect a1 (since remainder undefined)
    li a4, 43               # Remainder should be a1 itself
    beq a3, a4, rem_overflow_pass

rem_overflow_fail:
    j done

rem_overflow_pass:
    addi a0, a0, 1          # Increment return value if test passed


    # REMU Instruction Tests
    # ----------------------
    
    # Test 13: Basic REMU - Unsigned remainder of division
    li a1, 43
    li a2, 7
    remu a3, a1, a2         # a3 = a1 % a2 = 1
    li a4, 1
    beq a3, a4, remu_pass

remu_fail:
    j done

remu_pass:
    addi a0, a0, 1          # Increment return value if test passed

    # Test 14: REMU Overflow - Divide by zero
    li a1, 43
    li a2, 0
    remu a3, a1, a2         # a3 = a1 % a2, expect a1 (since remainder undefined)
    li a4, 43               # Remainder should be a1 itself
    beq a3, a4, remu_overflow_pass

remu_overflow_fail:
    j done

remu_overflow_pass:
    addi a0, a0, 1          # Increment return value if test passed

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93               # Syscall number for exit
    ecall                   # Make the syscall
