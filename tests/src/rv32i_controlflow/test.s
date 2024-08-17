.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # Test 1: BEQ - Branch if Equal
    li x1, 10
    li x2, 10
    beq x1, x2, beq_pass  # Branch should occur
    j beq_fail

beq_pass:
    addi a0, a0, 1         # Increment return value if test passed
    j next_test

beq_fail:
    j done

next_test:

    # Test 2: BNE - Branch if Not Equal
    li x1, 10
    li x2, 20
    bne x1, x2, bne_pass  # Branch should occur
    j bne_fail

bne_pass:
    addi a0, a0, 1         # Increment return value if test passed
    j next_test2

bne_fail:
    j done

next_test2:

    # Test 3: BLT - Branch if Less Than
    li x1, 10
    li x2, 20
    blt x1, x2, blt_pass  # Branch should occur
    j blt_fail

blt_pass:
    addi a0, a0, 1         # Increment return value if test passed
    j next_test3

blt_fail:
    j done

next_test3:

    # Test 4: BGE - Branch if Greater Than or Equal
    li x1, 20
    li x2, 10
    bge x1, x2, bge_pass  # Branch should occur
    j bge_fail

bge_pass:
    addi a0, a0, 1         # Increment return value if test passed
    j next_test4

bge_fail:
    j done

next_test4:

    # Test 5: BLTU - Branch if Less Than Unsigned
    li x1, 10
    li x2, 20
    bltu x1, x2, bltu_pass  # Branch should occur
    j bltu_fail

bltu_pass:
    addi a0, a0, 1          # Increment return value if test passed
    j next_test5

bltu_fail:
    j done

next_test5:

    # Test 6: BGEU - Branch if Greater Than or Equal Unsigned
    li x1, 20
    li x2, 10
    bgeu x1, x2, bgeu_pass  # Branch should occur
    j bgeu_fail

bgeu_pass:
    addi a0, a0, 1          # Increment return value if test passed
    j next_test6

bgeu_fail:
    j done

next_test6:

    # Test 7: JAL - Jump and Link
    jal x1, jal_pass         # Jump should occur, x1 = PC+4
    j jal_fail

jal_pass:
    addi a0, a0, 1          # Increment return value if test passed
    j next_test7

jal_fail:
    j done

next_test7:

    # Test 8: JALR - Jump and Link Register
    la x1, jalr_target
    jalr x2, 0(x1)          # Jump to jalr_target
    j jalr_fail

jalr_target:
    addi a0, a0, 1          # Increment return value if test passed
    j done

jalr_fail:
    j done

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93              # Syscall number for exit
    ecall                  # Make the syscall
