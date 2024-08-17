.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # Test 1: SLT - Set less than (signed comparison)
    li x1, 10
    li x2, 20
    slt x3, x1, x2    # x3 = (x1 < x2) ? 1 : 0 = 1
    li x4, 1
    beq x3, x4, slt_pass

slt_fail:
    j done

slt_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 2: SLTU - Set less than unsigned (unsigned comparison)
    li x1, 10
    li x2, 20
    sltu x3, x1, x2   # x3 = (unsigned(x1) < unsigned(x2)) ? 1 : 0 = 1
    li x4, 1
    beq x3, x4, sltu_pass

sltu_fail:
    j done

sltu_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 3: SLT (negative comparison)
    li x1, -10
    li x2, 20
    slt x3, x1, x2    # x3 = (x1 < x2) ? 1 : 0 = 1
    li x4, 1
    beq x3, x4, slt_neg_pass

slt_neg_fail:
    j done

slt_neg_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 4: SLTU (comparison of equal values)
    li x1, 20
    li x2, 20
    sltu x3, x1, x2   # x3 = (unsigned(x1) < unsigned(x2)) ? 1 : 0 = 0
    li x4, 0
    beq x3, x4, sltu_equal_pass

sltu_equal_fail:
    j done

sltu_equal_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 5: SLT (comparison of equal values)
    li x1, 15
    li x2, 15
    slt x3, x1, x2    # x3 = (x1 < x2) ? 1 : 0 = 0
    li x4, 0
    beq x3, x4, slt_equal_pass

slt_equal_fail:
    j done

slt_equal_pass:
    addi a0, a0, 1  # Increment return value if test passed

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93        # Syscall number for exit
    ecall            # Make the syscall
