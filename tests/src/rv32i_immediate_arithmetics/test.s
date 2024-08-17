.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # Test 1: ADDI - Add immediate to a register
    li x1, 10
    addi x2, x1, 20    # x2 = x1 + 20 = 30
    li x3, 30
    beq x2, x3, addi_pass

addi_fail:
    j done

addi_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 2: SLTI - Set less than immediate (signed comparison)
    li x1, 10
    slti x2, x1, 20    # x2 = (x1 < 20) ? 1 : 0 -> 1
    li x3, 1
    beq x2, x3, slti_pass

slti_fail:
    j done

slti_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 3: SLTIU - Set less than immediate (unsigned comparison)
    li x1, 10
    sltiu x2, x1, 20    # x2 = (unsigned(x1) < 20) ? 1 : 0 -> 1
    li x3, 1
    beq x2, x3, sltiu_pass

sltiu_fail:
    j done

sltiu_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 4: ANDI - Logical AND with immediate
    li x1, 0b1100
    andi x2, x1, 0b1010  # x2 = x1 & 0b1010 = 0b1000
    li x3, 0b1000
    beq x2, x3, andi_pass

andi_fail:
    j done

andi_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 5: ORI - Logical OR with immediate
    li x1, 0b1100
    ori x2, x1, 0b1010   # x2 = x1 | 0b1010 = 0b1110
    li x3, 0b1110
    beq x2, x3, ori_pass

ori_fail:
    j done

ori_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 6: XORI - Logical XOR with immediate
    li x1, 0b1100
    xori x2, x1, 0b1010  # x2 = x1 ^ 0b1010 = 0b0110
    li x3, 0b0110
    beq x2, x3, xori_pass

xori_fail:
    j done

xori_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 7: SLLI - Shift left logical immediate
    li x1, 1
    slli x2, x1, 2       # x2 = x1 << 2 = 4
    li x3, 4
    beq x2, x3, slli_pass

slli_fail:
    j done

slli_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 8: SRLI - Shift right logical immediate
    li x1, 4
    srli x2, x1, 1       # x2 = x1 >> 1 = 2
    li x3, 2
    beq x2, x3, srli_pass

srli_fail:
    j done

srli_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 9: SRAI - Shift right arithmetic immediate
    li x1, -4
    srai x2, x1, 1       # x2 = x1 >> 1 (arithmetic) = -2
    li x3, -2
    beq x2, x3, srai_pass

srai_fail:
    j done

srai_pass:
    addi a0, a0, 1  # Increment return value if test passed

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93        # Syscall number for exit
    ecall            # Make the syscall
