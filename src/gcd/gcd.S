# Binary GCD, RV32I.
# a0 = a, a1 = b; result in a0.
    .text
    .globl gcd_u32_asm
    .type gcd_u32_asm, @function
    .align 2
gcd_u32_asm:
    beq     a0, zero, .Lgcd_return_b
    beq     a1, zero, .Lgcd_return
    li      t0, 0

.Lgcd_common:
    or      t1, a0, a1
    andi    t1, t1, 1
    bne     t1, zero, .Lgcd_check_a
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    t0, t0, 1
    j       .Lgcd_common

.Lgcd_check_a:
    andi    t1, a0, 1
    bne     t1, zero, .Lgcd_check_b
.Lgcd_shift_a:
    srli    a0, a0, 1
    andi    t1, a0, 1
    beq     t1, zero, .Lgcd_shift_a

.Lgcd_check_b:
    andi    t1, a1, 1
    bne     t1, zero, .Lgcd_order
.Lgcd_shift_b:
    srli    a1, a1, 1
    andi    t1, a1, 1
    beq     t1, zero, .Lgcd_shift_b

.Lgcd_order:
    bgeu    a1, a0, .Lgcd_subtract
    mv      t1, a0
    mv      a0, a1
    mv      a1, t1

.Lgcd_subtract:
    sub     a1, a1, a0
    # Both operands were odd: a nonzero difference is even.
    bne     a1, zero, .Lgcd_shift_b
    sll     a0, a0, t0

.Lgcd_return:
    ret

.Lgcd_return_b:
    mv      a0, a1
    ret
    .size gcd_u32_asm, .-gcd_u32_asm
