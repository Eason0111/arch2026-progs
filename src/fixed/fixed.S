# RV32I leaf functions; only caller-saved registers are modified.
    .text
    .globl op1_asm
    .type op1_asm, @function
    .align 2
op1_asm:
    li t0, 0
    beq a1, zero, .Lop1_done
.Lop1_loop:
    and t1, a0, a1
    xor a0, a0, a1
    slli a1, t1, 1
    addi t0, t0, 1
    bne a1, zero, .Lop1_loop
.Lop1_done:
    sw t0, 0(a2)
    ret
    .size op1_asm, .-op1_asm

    .globl op2_asm
    .type op2_asm, @function
    .align 2
op2_asm:
    sub a0, a0, a1
    ret
    .size op2_asm, .-op2_asm

    .globl op3_asm
    .type op3_asm, @function
    .align 2
op3_asm:
    and t0, a0, a1
    xor a0, a0, a1
    srli a0, a0, 1
    add a0, a0, t0
    ret
    .size op3_asm, .-op3_asm

    .globl q_mul_asm
    .type q_mul_asm, @function
    .align 2
q_mul_asm:
    beq a0, zero, .Lqm_return
    beq a1, zero, .Lqm_zero
    xor a5, a0, a1
    bge a0, zero, .Lqm_abs_b
    sub a0, zero, a0
.Lqm_abs_b:
    bge a1, zero, .Lqm_order
    sub a1, zero, a1
.Lqm_order:
    # Iterate over the smaller magnitude to reduce the number of bit steps.
    bgeu a0, a1, .Lqm_init
    mv t0, a0
    mv a0, a1
    mv a1, t0
.Lqm_init:
    li a2, 0
    li a3, 0
    li a4, 0
.Lqm_loop:
    andi t0, a1, 1
    beq t0, zero, .Lqm_shift
    add t1, a3, a0
    sltu t2, t1, a3
    add a4, a4, a2
    add a4, a4, t2
    mv a3, t1
.Lqm_shift:
    srli a1, a1, 1
    beq a1, zero, .Lqm_sign
    srli t0, a0, 31
    slli a2, a2, 1
    or a2, a2, t0
    slli a0, a0, 1
    j .Lqm_loop
.Lqm_sign:
    bge a5, zero, .Lqm_round
    sub a3, zero, a3
    not a4, a4
    seqz t0, a3
    add a4, a4, t0
.Lqm_round:
    li t0, 0x80000
    add t1, a3, t0
    sltu t2, t1, a3
    add a4, a4, t2
    srli t1, t1, 20
    slli a4, a4, 12
    or a0, a4, t1
.Lqm_return:
    ret
.Lqm_zero:
    li a0, 0
    ret
    .size q_mul_asm, .-q_mul_asm
