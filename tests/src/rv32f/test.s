.section .data
test_results:
    .word 0              # Store the number of successful tests

.section .text
.global _start
_start:
    # Initialize return value register (a0/x10) to 0
    li a0, 0

    # Basic Arithmetic Operations
    # ---------------------------
    
    # Test 1: FADD.S - Floating-Point Addition
    li t0, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t1, 0x40000000         # 2.0 in IEEE 754 single-precision
    li t2, 0x40400000         # 3.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 1.0 to floating-point register
    fmv.w.x ft1, t1           # Move 2.0 to floating-point register
    fadd.s ft2, ft0, ft1      # 1.0 + 2.0 = 3.0
    fmv.x.w t3, ft2           # Move result back to integer register
    beq t3, t2, fadd_pass

fadd_fail:
    j done

fadd_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 2: FSUB.S - Floating-Point Subtraction
    li t0, 0x40400000         # 3.0 in IEEE 754 single-precision
    li t1, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t2, 0x40000000         # 2.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 3.0 to floating-point register
    fmv.w.x ft1, t1           # Move 1.0 to floating-point register
    fsub.s ft2, ft0, ft1      # 3.0 - 1.0 = 2.0
    fmv.x.w t3, ft2           # Move result back to integer register
    beq t3, t2, fsub_pass

fsub_fail:
    j done

fsub_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 3: FMUL.S - Floating-Point Multiplication
    li t0, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t1, 0x40000000         # 2.0 in IEEE 754 single-precision
    li t2, 0x40000000         # 2.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 1.0 to floating-point register
    fmv.w.x ft1, t1           # Move 2.0 to floating-point register
    fmul.s ft2, ft0, ft1      # 1.0 * 2.0 = 2.0
    fmv.x.w t3, ft2           # Move result back to integer register
    beq t3, t2, fmul_pass

fmul_fail:
    j done

fmul_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 4: FDIV.S - Floating-Point Division
    li t0, 0x40000000         # 2.0 in IEEE 754 single-precision
    li t1, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t2, 0x3f800000         # 1.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 2.0 to floating-point register
    fmv.w.x ft1, t1           # Move 1.0 to floating-point register
    fdiv.s ft2, ft0, ft1      # 2.0 / 1.0 = 2.0
    fmv.x.w t3, ft2           # Move result back to integer register
    beq t3, t0, fdiv_pass

fdiv_fail:
    j done

fdiv_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 5: FSQRT.S - Floating-Point Square Root
    li t0, 0x40000000         # 2.0 in IEEE 754 single-precision
    li t1, 0x3fb504f3         # sqrt(2.0) in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 2.0 to floating-point register
    fsqrt.s ft1, ft0          # sqrt(2.0)
    fmv.x.w t3, ft1           # Move result back to integer register
    beq t3, t1, fsqrt_pass

fsqrt_fail:
    j done

fsqrt_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Fused Multiply-Add Operations
    # -----------------------------
    
    # Test 6: FMADD.S - Fused Multiply-Add
    li t0, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t1, 0x40000000         # 2.0 in IEEE 754 single-precision
    li t2, 0x40400000         # 3.0 in IEEE 754 single-precision
    li t3, 0x40800000         # 4.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 1.0 to floating-point register
    fmv.w.x ft1, t1           # Move 2.0 to floating-point register
    fmv.w.x ft2, t2           # Move 3.0 to floating-point register
    fmadd.s ft3, ft0, ft1, ft2  # 1.0 * 2.0 + 3.0 = 5.0
    fmv.x.w t4, ft3           # Move result back to integer register
    li t5, 0x40a00000         # 5.0 in IEEE 754 single-precision
    beq t4, t5, fmadd_pass

fmadd_fail:
    j done

fmadd_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 7: FMSUB.S - Fused Multiply-Subtract
    fmsub.s ft3, ft0, ft1, ft2  # 1.0 * 2.0 - 3.0 = -1.0
    fmv.x.w t4, ft3           # Move result back to integer register
    li t5, 0xbf800000         # -1.0 in IEEE 754 single-precision
    beq t4, t5, fmsub_pass

fmsub_fail:
    j done

fmsub_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 8: FNMADD.S - Negative Multiply-Add
    fnmadd.s ft3, ft0, ft1, ft2  # -(1.0 * 2.0) + 3.0 = 1.0
    fmv.x.w t4, ft3           # Move result back to integer register
    li t5, 0xc0a00000         # 1.0 in IEEE 754 single-precision
    beq t4, t5, fnmadd_pass

fnmadd_fail:
    j done

fnmadd_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 9: FNMSUB.S - Negative Multiply-Subtract
    fnmsub.s ft3, ft0, ft1, ft2  # -(1.0 * 2.0) + 3.0 = 1.0
    fmv.x.w t4, ft3           # Move result back to integer register
    li t5, 0x3f800000         # 1.0 in IEEE 754 single-precision
    beq t4, t5, fnmsub_pass

fnmsub_fail:
    j done

fnmsub_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Floating-Point Conversion Operations
    # ------------------------------------
    
    # Test 10: FCVT.W.S - Convert Floating-Point to Signed Integer
    li t0, 0x41a00000         # 20.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 20.0 to floating-point register
    fcvt.w.s t1, ft0          # Convert 20.0 to signed integer
    li t2, 20
    beq t1, t2, fcvt_w_s_pass

fcvt_w_s_fail:
    j done

fcvt_w_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 11: FCVT.S.W - Convert Signed Integer to Floating-Point
    li t0, 20
    fcvt.s.w ft0, t0          # Convert 20 to floating-point
    fmv.x.w t1, ft0           # Move result back to integer register
    li t2, 0x41a00000         # 20.0 in IEEE 754 single-precision
    beq t1, t2, fcvt_s_w_pass

fcvt_s_w_fail:
    j done

fcvt_s_w_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 12: FCVT.WU.S - Convert Floating-Point to Unsigned Integer
    li t0, 0x41a00000         # 20.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 20.0 to floating-point register
    fcvt.wu.s t1, ft0         # Convert 20.0 to unsigned integer
    li t2, 20
    beq t1, t2, fcvt_wu_s_pass

fcvt_wu_s_fail:
    j done

fcvt_wu_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 13: FCVT.S.WU - Convert Unsigned Integer to Floating-Point
    li t0, 20
    fcvt.s.wu ft0, t0         # Convert 20 to floating-point
    fmv.x.w t1, ft0           # Move result back to integer register
    li t2, 0x41a00000         # 20.0 in IEEE 754 single-precision
    beq t1, t2, fcvt_s_wu_pass

fcvt_s_wu_fail:
    j done

fcvt_s_wu_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Floating-Point Comparison Operations
    # ------------------------------------
    
    # Test 14: FEQ.S - Floating-Point Equality
    li t0, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t1, 0x3f800000         # 1.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 1.0 to floating-point register
    fmv.w.x ft1, t1           # Move 1.0 to floating-point register
    feq.s t2, ft0, ft1        # Compare ft0 and ft1
    li t3, 1                  # Expected result is 1 (true)
    beq t2, t3, feq_s_pass

feq_s_fail:
    j done

feq_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 15: FLT.S - Floating-Point Less Than
    li t0, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t1, 0x40000000         # 2.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 1.0 to floating-point register
    fmv.w.x ft1, t1           # Move 2.0 to floating-point register
    flt.s t2, ft0, ft1        # Compare ft0 < ft1
    li t3, 1                  # Expected result is 1 (true)
    beq t2, t3, flt_s_pass

flt_s_fail:
    j done

flt_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 16: FLE.S - Floating-Point Less Than or Equal
    li t0, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t1, 0x40000000         # 2.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 1.0 to floating-point register
    fmv.w.x ft1, t1           # Move 2.0 to floating-point register
    fle.s t2, ft0, ft1        # Compare ft0 <= ft1
    li t3, 1                  # Expected result is 1 (true)
    beq t2, t3, fle_s_pass

fle_s_fail:
    j done

fle_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Floating-Point Sign Manipulation
    # --------------------------------
    
    # Test 17: FSGNJ.S - Sign Injection
    li t0, 0x3f800000         # 1.0 in IEEE 754 single-precision
    li t1, 0xbf800000         # -1.0 in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move 1.0 to floating-point register
    fmv.w.x ft1, t1           # Move -1.0 to floating-point register
    fsgnj.s ft2, ft0, ft1     # Copy sign from ft1 to ft0
    fmv.x.w t2, ft2           # Move result back to integer register
    beq t2, t1, fsgnj_s_pass

fsgnj_s_fail:
    j done

fsgnj_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 18: FSGNJN.S - Sign Injection Negated
    fsgnjn.s ft2, ft0, ft1    # Negate sign of ft1 and copy to ft0
    fmv.x.w t2, ft2           # Move result back to integer register
    beq t2, t0, fsgnjn_s_pass # Result should be +1.0 (0x3f800000)

fsgnjn_s_fail:
    j done

fsgnjn_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 19: FSGNJX.S - Sign Injection XOR
    fsgnjx.s ft2, ft0, ft1    # XOR signs of ft0 and ft1
    fmv.x.w t2, ft2           # Move result back to integer register
    li t3, 0xbf800000         # Expected result is -1.0 (0xbf800000)
    beq t2, t3, fsgnjx_s_pass

fsgnjx_s_fail:
    j done

fsgnjx_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Floating-Point Maximum and Minimum Operations
    # ---------------------------------------------
    
    # Test 20: FMIN.S - Floating-Point Minimum
    fmin.s ft2, ft0, ft1      # Get minimum of ft0 and ft1
    fmv.x.w t2, ft2           # Move result back to integer register
    beq t2, t1, fmin_s_pass   # Result should be -1.0 (0xbf800000)

fmin_s_fail:
    j done

fmin_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 21: FMAX.S - Floating-Point Maximum
    fmax.s ft2, ft0, ft1      # Get maximum of ft0 and ft1
    fmv.x.w t2, ft2           # Move result back to integer register
    beq t2, t0, fmax_s_pass   # Result should be +1.0 (0x3f800000)

fmax_s_fail:
    j done

fmax_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Floating-Point Classification and Move Operations
    # -------------------------------------------------
    
    # Test 22: FCLASS.S - Floating-Point Classify
    li t0, 0x7f800000         # +Infinity in IEEE 754 single-precision
    fmv.w.x ft0, t0           # Move +Infinity to floating-point register
    fclass.s t1, ft0          # Classify the floating-point number
    li t2, 0x80               # Class for +Infinity
    beq t1, t2, fclass_s_pass

fclass_s_fail:
    j done

fclass_s_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 23: FMV.X.W - Move Floating-Point to Integer
    fmv.x.w t1, ft0           # Move the bit pattern of ft0 to integer register
    beq t1, t0, fmv_x_w_pass  # Result should be the bit pattern of +Infinity

fmv_x_w_fail:
    j done

fmv_x_w_pass:
    addi a0, a0, 1            # Increment return value if test passed

    # Test 24: FMV.W.X - Move Integer to Floating-Point
    fmv.w.x ft1, t0           # Move the bit pattern to floating-point register
    fmv.x.w t1, ft1           # Move the bit pattern back to integer register
    beq t1, t0, fmv_w_x_pass  # Result should be the bit pattern of +Infinity

fmv_w_x_fail:
    j done

fmv_w_x_pass:
    addi a0, a0, 1            # Increment return value if test passed

done:
    # Exit the program with a0 (x10) as the return code
    li a7, 93               # Syscall number for exit
    ecall                   # Make the syscall

