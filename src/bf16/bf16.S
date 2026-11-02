# BF16 operations using integer RV32I instructions only.
# Leaf functions use only caller-saved registers.
    .text
    .globl bf16_from_f32_asm
    .type bf16_from_f32_asm, @function
    .align 2
bf16_from_f32_asm:
    li t0, 0x7f800000
    and t1, a0, t0
    beq t1, t0, .Lf32_top
    srli t1, a0, 16
    andi t1, t1, 1
    li t0, 0x7fff
    add a0, a0, t0
    add a0, a0, t1
.Lf32_top:
    srli a0, a0, 16
    ret
    .size bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl bf16_mul_asm
    .type bf16_mul_asm, @function
    .align 2
bf16_mul_asm:
    xor a2, a0, a1
    li t0, 0x8000
    and a2, a2, t0
    srli a3, a0, 7
    andi a3, a3, 255
    srli a4, a1, 7
    andi a4, a4, 255
    andi a5, a0, 127
    andi a6, a1, 127
    li t0, 255
    beq a3, t0, .Lmul_special_a
    beq a4, t0, .Lmul_special_b
    or t0, a3, a5
    beq t0, zero, .Lmul_zero
    or t0, a4, a6
    beq t0, zero, .Lmul_zero
    beq a3, zero, .Lmul_denorm_a
    ori a5, a5, 128
    j .Lmul_normal_b
.Lmul_denorm_a:
    li a3, 1
.Lmul_shift_a:
    slli a5, a5, 1
    addi a3, a3, -1
    sltiu t0, a5, 128
    bne t0, zero, .Lmul_shift_a
.Lmul_normal_b:
    beq a4, zero, .Lmul_denorm_b
    ori a6, a6, 128
    j .Lmul_product
.Lmul_denorm_b:
    li a4, 1
.Lmul_shift_b:
    slli a6, a6, 1
    addi a4, a4, -1
    sltiu t0, a6, 128
    bne t0, zero, .Lmul_shift_b
.Lmul_product:
    add a3, a3, a4
    addi a3, a3, -127
    li a7, 0
.Lmul_bits:
    andi t0, a6, 1
    beq t0, zero, .Lmul_next
    add a7, a7, a5
.Lmul_next:
    srli a6, a6, 1
    slli a5, a5, 1
    bne a6, zero, .Lmul_bits
    srli t0, a7, 15
    beq t0, zero, .Lmul_low_product
    srli a7, a7, 8
    addi a3, a3, 1
    j .Lmul_pack
.Lmul_low_product:
    srli a7, a7, 7
.Lmul_pack:
    li t0, 255
    bge a3, t0, .Lmul_inf
    andi a7, a7, 127
    bge zero, a3, .Lmul_underflow
    slli a3, a3, 7
    or a0, a2, a3
    or a0, a0, a7
    ret
.Lmul_underflow:
    li t0, -6
    blt a3, t0, .Lmul_zero
    li t0, 1
    sub t0, t0, a3
    srl a7, a7, t0
    or a0, a2, a7
    ret
.Lmul_special_a:
    bne a5, zero, .Lmul_return
    or t0, a4, a6
    beq t0, zero, .Lmul_nan
    j .Lmul_inf
.Lmul_special_b:
    bne a6, zero, .Lmul_return_b
    or t0, a3, a5
    beq t0, zero, .Lmul_nan
.Lmul_inf:
    li t0, 0x7f80
    or a0, a2, t0
    ret
.Lmul_zero:
    mv a0, a2
.Lmul_return:
    ret
.Lmul_return_b:
    mv a0, a1
    ret
.Lmul_nan:
    li a0, 0x7fc0
    ret
    .size bf16_mul_asm, .-bf16_mul_asm

    .globl bf16_sqrt_asm
    .type bf16_sqrt_asm, @function
    .align 2
bf16_sqrt_asm:
    srli t1, a0, 7
    andi t1, t1, 255
    andi t2, a0, 127
    li t0, 255
    beq t1, t0, .Lsqrt_special
    or t0, t1, t2
    beq t0, zero, .Lsqrt_zero
    srli t0, a0, 15
    bne t0, zero, .Lsqrt_nan
    beq t1, zero, .Lsqrt_zero
    ori t3, t2, 128
    addi t1, t1, -127
    andi t0, t1, 1
    beq t0, zero, .Lsqrt_even
    slli t3, t3, 1
    addi t1, t1, -1
.Lsqrt_even:
    srai t1, t1, 1
    addi t1, t1, 127
    # floor(mid*mid/128) <= m iff mid*mid <= 128*(m+1)-1.
    addi t3, t3, 1
    slli t3, t3, 7
    addi t3, t3, -1
    # Restoring integer square root, one base-four digit per iteration.
    li t4, 0
    li t5, 16384
.Lsqrt_digit:
    add t6, t4, t5
    bltu t3, t6, .Lsqrt_skip
    sub t3, t3, t6
    srli t4, t4, 1
    add t4, t4, t5
    j .Lsqrt_next
.Lsqrt_skip:
    srli t4, t4, 1
.Lsqrt_next:
    srli t5, t5, 2
    bne t5, zero, .Lsqrt_digit
    # Normal inputs yield a root in [128,255] and exponent in [64,190].
    andi t4, t4, 127
    slli t1, t1, 7
    or a0, t1, t4
    ret
.Lsqrt_special:
    bne t2, zero, .Lsqrt_return
    srli t0, a0, 15
    beq t0, zero, .Lsqrt_return
.Lsqrt_nan:
    li a0, 0x7fc0
.Lsqrt_return:
    ret
.Lsqrt_zero:
    li a0, 0
    ret
    .size bf16_sqrt_asm, .-bf16_sqrt_asm
