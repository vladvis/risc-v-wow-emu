.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # Test 1: SLL - Shift left logical
    li x1, 1
    li x2, 2
    sll x3, x1, x2    # x3 = x1 << x2 = 4
    li x4, 4
    beq x3, x4, sll_pass

sll_fail:
    j done

sll_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 2: SRL - Shift right logical
    li x1, 4
    li x2, 1
    srl x3, x1, x2    # x3 = x1 >> x2 (logical) = 2
    li x4, 2
    beq x3, x4, srl_pass

srl_fail:
    j done

srl_pass:
    addi a0, a0, 1  # Increment return value if test passed

    # Test 3: SRA - Shift right arithmetic
    li x1, -4
    li x2, 1
    sra x3, x1, x2    # x3 = x1 >> x2 (arithmetic) = -2
    li x4, -2
    beq x3, x4, sra_pass

sra_fail:
    j done

sra_pass:
    addi a0, a0, 1  # Increment return value if test passed

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93        # Syscall number for exit
    ecall            # Make the syscall