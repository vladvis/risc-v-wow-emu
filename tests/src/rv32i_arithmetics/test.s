.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # Test 1: ADD - Add two positive numbers
    li x1, 10
    li x2, 20
    add x3, x1, x2
    li x4, 30
    beq x3, x4, add_pass

add_fail:
    j done

add_pass:
    addi a0, a0, 1
    # Test 2: SUB - Subtract two positive numbers
    li x1, 20
    li x2, 10
    sub x3, x1, x2
    li x4, 10
    beq x3, x4, sub_pass

sub_fail:
    j done

sub_pass:
    addi a0, a0, 1  

    # Test 3: AND - Logical AND between two registers
    li x1, 0b1100
    li x2, 0b1010
    and x3, x1, x2
    li x4, 0b1000
    beq x3, x4, and_pass

and_fail:
    j done

and_pass:
    addi a0, a0, 1  

    # Test 4: OR - Logical OR between two registers
    li x1, 0b1100
    li x2, 0b1010
    or x3, x1, x2
    li x4, 0b1110
    beq x3, x4, or_pass

or_fail:
    j done

or_pass:
    addi a0, a0, 1  

    # Test 5: XOR - Logical XOR between two registers
    li x1, 0b1100
    li x2, 0b1010
    xor x3, x1, x2
    li x4, 0b0110
    beq x3, x4, xor_pass

xor_fail:
    j done

xor_pass:
    addi a0, a0, 1  

    # Test 6: SLL - Shift left logical
    li x1, 1
    li x2, 2
    sll x3, x1, x2
    li x4, 4
    beq x3, x4, sll_pass

sll_fail:
    j done

sll_pass:
    addi a0, a0, 1  

    # Test 7: SRL - Shift right logical
    li x1, 4
    li x2, 1
    srl x3, x1, x2
    li x4, 2
    beq x3, x4, srl_pass

srl_fail:
    j done

srl_pass:
    addi a0, a0, 1  

    # Test 8: SRA - Shift right arithmetic
    li x1, -4
    li x2, 1
    sra x3, x1, x2
    li x4, -2
    beq x3, x4, sra_pass

sra_fail:
    j done

sra_pass:
    addi a0, a0, 1  

    # Test 9: SLT - Set less than
    li x1, 10
    li x2, 20
    slt x3, x1, x2
    li x4, 1
    beq x3, x4, slt_pass

slt_fail:
    j done

slt_pass:
    addi a0, a0, 1  

    # Test 10: SLTU - Set less than unsigned
    li x1, 10
    li x2, 20
    sltu x3, x1, x2
    li x4, 1
    beq x3, x4, sltu_pass

sltu_fail:
    j done

sltu_pass:
    addi a0, a0, 1  

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93        # Syscall number for exit
    ecall            # Make the syscall
