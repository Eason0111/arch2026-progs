    .include "src/rubik/rubik_near5.inc"
# Port of Homework 1 commit 25321b6 with exact endgame lookup tables.
# Adapter: save registers, accept arguments, and format bounded output.
# Parsing: s0=p, s1=o, s2=input; s3-s5 are scratch.
# Search: s0/s1=state, s2=move, s3=face, s4-s7=table bases,
# s8=bound, s10=depth, s11=node. t0-t5 are scratch.
# Output: s10=length; a1=out, a2=cap, a3=cursor; t0-t6 are scratch.
# All modified saved registers are restored; no system calls or CSR reads.
# rubik_solve_asm: optimal 2x2x2 cube solver, hand-written RV32I.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
#                                   a0 = state, a1 = out, a2 = cap; result in a0
#
# RV32I only; no CSR access: no mul, div, rem, no floating point, no compressed
# instructions, no heap, no recursion. Tests: tests/trubik.c.

    .text

    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
    # Preserve saved registers and output arguments.
    addi    sp, sp, -64
    sw      s0, 0(sp)
    sw      s1, 4(sp)
    sw      s2, 8(sp)
    sw      s3, 12(sp)
    sw      s4, 16(sp)
    sw      s5, 20(sp)
    sw      s6, 24(sp)
    sw      s7, 28(sp)
    sw      s8, 32(sp)
    sw      s9, 36(sp)
    sw      s10, 40(sp)
    sw      s11, 44(sp)
    sw      a1, 48(sp)
    sw      a2, 52(sp)
    sw      ra, 56(sp)

    mv   s2, a0

    # 檢查前 7 個字元：必須是 1～7，而且不能重複
    li   s3, 0          # 字元索引
    li   s4, 0          # 已出現數字的位元遮罩

.Lhw1_input_check_p:
    add  t0, s2, s3
    lbu  t1, 0(t0)
    addi t1, t1, -49    # ASCII '1' → 數值 0

    li   t2, 7
    bgeu t1, t2, .Lhw1_invalid_input

    li   t2, 1
    sll  t2, t2, t1     # 此數字對應的 bit
    and  t3, s4, t2
    bne  t3, zero, .Lhw1_invalid_input
    or   s4, s4, t2

    addi s3, s3, 1
    li   t0, 7
    bltu s3, t0, .Lhw1_input_check_p

    # 檢查後 7 個方向
    # 同時計算方向編號：只編入前 6 個方向
    li   s3, 0
    li   s1, 0          # 方向編號 o
    li   s5, 0          # 七個方向的總和

.Lhw1_input_check_o:
    add  t0, s2, s3
    lbu  t1, 7(t0)
    addi t1, t1, -49    # '1'、'2'、'3' → 0、1、2

    li   t2, 3
    bgeu t1, t2, .Lhw1_invalid_input
    add  s5, s5, t1

    li   t2, 6
    bgeu s3, t2, .Lhw1_input_o_next

    # o = o * 3 + 目前方向
    # 乘 3 使用位移與加法
    slli t2, s1, 1
    add  s1, t2, s1
    add  s1, s1, t1

.Lhw1_input_o_next:
    addi s3, s3, 1
    li   t0, 7
    bltu s3, t0, .Lhw1_input_check_o

    # 第 15 個 byte 必須是字串結尾
    lbu  t0, 14(s2)
    bne  t0, zero, .Lhw1_invalid_input

    # 確認方向總和是 3 的倍數，不使用除法
    li   t0, 3

.Lhw1_input_sum_mod:
    bltu s5, t0, .Lhw1_input_sum_done
    addi s5, s5, -3
    j    .Lhw1_input_sum_mod

.Lhw1_input_sum_done:
    bne  s5, zero, .Lhw1_invalid_input

    # 計算位置編號，對應 C 版 rank_state：
    # p = p * (7 - i) + 右側比目前數字小的個數
    li   s0, 0          # 位置編號 p
    li   s3, 0          # i

.Lhw1_input_rank_p:
    add  t0, s2, s3
    lbu  t1, 0(t0)      # 目前位置字元
    addi s4, s3, 1      # j = i + 1
    li   s5, 0          # smaller = 0

.Lhw1_input_count_smaller:
    li   t0, 7
    bgeu s4, t0, .Lhw1_input_rank_accumulate

    add  t0, s2, s4
    lbu  t2, 0(t0)
    bgeu t2, t1, .Lhw1_input_count_next
    addi s5, s5, 1

.Lhw1_input_count_next:
    addi s4, s4, 1
    j    .Lhw1_input_count_smaller

.Lhw1_input_rank_accumulate:
    # 用重複加法計算 p * (7 - i)
    # 只在輸入初始化時執行
    li   t2, 7
    sub  t2, t2, s3
    mv   t3, s0
    li   s0, 0

.Lhw1_input_rank_multiply:
    add  s0, s0, t3
    addi t2, t2, -1
    bne  t2, zero, .Lhw1_input_rank_multiply

    add  s0, s0, s5

    addi s3, s3, 1
    li   t0, 7
    bltu s3, t0, .Lhw1_input_rank_p

    # 把解析完成的 p、o 放入根節點
    la   s11, search_stack
    sh   s0, 0(s11)
    sh   s1, 2(s11)
    sb   zero, 4(s11)

    # 初始搜尋上限 = max(position_dist[p],
    #                       orientation_dist[o])
    la   t0, position_dist
    add  t0, t0, s0
    lbu  s8, 0(t0)

    la   t0, orientation_dist
    add  t0, t0, s1
    lbu  t1, 0(t0)

    bgeu s8, t1, .Ldistance11_lookup
    mv   s8, t1

.Ldistance11_lookup:
    # Exact membership raises the initial bound without skipping a shorter
    # solution. The key packs p and o; no multiply instruction is needed.
    slli t0, s0, 10
    or   t0, t0, s1
    li   t1, 0
    li   t2, 2644
    la   t6, .Ldistance11_keys
.Ldistance11_loop:
    # Binary search over the half-open interval [t1, t2).
    bgeu t1, t2, .Lhw1_new_bound
    add  t3, t1, t2
    srli t3, t3, 1
    slli t4, t3, 2
    add  t4, t6, t4
    lw   t5, 0(t4)
    beq  t0, t5, .Ldistance11_found
    bltu t0, t5, .Ldistance11_left
    addi t1, t3, 1
    j    .Ldistance11_loop
.Ldistance11_left:
    mv   t2, t3
    j    .Ldistance11_loop
.Ldistance11_found:
    li   s8, 11
    j    .Lhw1_new_bound

.Lhw1_new_bound:
    # 常用表格起點：每次搜尋上限開始時載入一次
    # s4=move_face，s5=position_dist，s6=orientation_dist
    # s7=move_turns；搜尋期間保留這四個暫存器
    la   s4, move_face
    la   s5, position_dist
    la   s6, orientation_dist
    la   s7, move_turns
    # 每次增加上限，都從根節點重新搜尋
    li   s10, 0
    la   s11, search_stack
    sb   zero, 4(s11)

.Lhw1_search_loop:
    # 載入目前節點
    lhu  s0, 0(s11)
    lhu  s1, 2(s11)

    # 先檢查是否已解，允許在上限那一層找到解答
    or   t0, s0, s1
    beq  t0, zero, .Lhw1_solved

    # Within five remaining moves, an exact table replaces further search.
    sub t0, s8, s10
    li t1, 5
    bgeu t1, t0, .Lnear5_finish

    # 已達深度上限，退回
    bgeu s10, s8, .Lhw1_backtrack

    # 取出目前節點尚未嘗試的動作
    lbu  s2, 4(s11)
    li   t0, 9
    bgeu s2, t0, .Lhw1_backtrack

    # 先保存進度，之後退回才不會重複同一動作
    addi t0, s2, 1
    sb   t0, 4(s11)

    # 查出這個動作的面向
    add  t0, s4, s2
    lbu  s3, 0(t0)

    # 根節點沒有上一個動作
    beq  s10, zero, .Lhw1_get_turns

    # 跳過連續轉動相同面的動作
    la   t0, search_path
    addi t1, s10, -1
    add  t0, t0, t1
    lbu  t1, 0(t0)

    add  t0, s4, t1
    lbu  t1, 0(t0)
    beq  s3, t1, .Lhw1_search_loop

.Lhw1_get_turns:
    add  t0, s7, s2
    lbu  t3, 0(t0)

    # 選擇轉移表
    beq  s3, zero, .Lhw1_select_r
    li   t0, 1
    beq  s3, t0, .Lhw1_select_b
    j    .Lhw1_select_d

.Lhw1_select_r:
    la   t4, perm_R
    la   t5, orient_R
    j    .Lhw1_start_turns

.Lhw1_select_b:
    la   t4, perm_B
    la   t5, orient_B
    j    .Lhw1_start_turns

.Lhw1_select_d:
    la   t4, perm_D
    la   t5, orient_D

.Lhw1_start_turns:
.Lhw1_turn_loop:
    # 第一次轉動
    slli t1, s0, 1
    add  t0, t4, t1
    lhu  s0, 0(t0)
    slli t1, s1, 1
    add  t0, t5, t1
    lhu  s1, 0(t0)
    li   t0, 1
    beq  t3, t0, .Lhw1_evaluate_child

    # 第二次轉動
    slli t1, s0, 1
    add  t0, t4, t1
    lhu  s0, 0(t0)
    slli t1, s1, 1
    add  t0, t5, t1
    lhu  s1, 0(t0)
    li   t0, 2
    beq  t3, t0, .Lhw1_evaluate_child

    # 第三次轉動；直接接到子節點評估
    slli t1, s0, 1
    add  t0, t4, t1
    lhu  s0, 0(t0)
    slli t1, s1, 1
    add  t0, t5, t1
    lhu  s1, 0(t0)

.Lhw1_evaluate_child:
    # 使用已保留的距離表起點
    add  t0, s5, s0
    lbu  t0, 0(t0)
    add  t1, s6, s1
    lbu  t1, 0(t1)

    # t2=max(hp, ho)，保留 s4～s7 的表格起點
    mv   t2, t0
    bgeu t0, t1, .Lhw1_h_ready
    mv   t2, t1

.Lhw1_h_ready:
    # 子節點深度 + h > bound：剪枝
    addi t0, s10, 1
    add  t1, t0, t2
    bltu s8, t1, .Lhw1_search_loop

    # 確認子節點不會超出堆疊容量
    li   t1, 12
    bgeu t0, t1, .Lhw1_capacity_error

    # 記錄這一步的動作
    la   t1, search_path
    add  t1, t1, s10
    sb   s2, 0(t1)

    # 進入子節點
    addi s10, s10, 1
    addi s11, s11, 8
    sh   s0, 0(s11)
    sh   s1, 2(s11)
    sb   zero, 4(s11)

    # 繼續探索子節點，不再立即手動退回
    j    .Lhw1_search_loop

.Lhw1_backtrack:
    # 根節點也走完：此上限內無解
    beq  s10, zero, .Lhw1_limit_exhausted

    # 退回父節點，繼續它尚未試過的動作
    addi s10, s10, -1
    addi s11, s11, -8
    j    .Lhw1_search_loop

.Lhw1_limit_exhausted:
    li   t0, 11
    bgeu s8, t0, .Lhw1_search_failed

    addi s8, s8, 1
    j    .Lhw1_new_bound


.Lhw1_solved:
    # Determine the entire output size before writing any bytes.
    li      t0, 0
    li      t6, 1
    la      t1, search_path
    la      t2, move_names
.Lformat_count:
    beq     t0, s10, .Lformat_check
    add     t3, t1, t0
    lbu     t3, 0(t3)
    slli    t3, t3, 2
    add     t3, t2, t3
    lbu     t4, 1(t3)
    snez    t4, t4
    addi    t4, t4, 1
    add     t6, t6, t4
    beq     t0, zero, .Lformat_next
    addi    t6, t6, 1
.Lformat_next:
    addi    t0, t0, 1
    j       .Lformat_count
.Lformat_check:
    lw      a1, 48(sp)
    lw      a2, 52(sp)
    bltu    a2, t6, .Lbuffer_small
    mv      a3, a1
    li      t0, 0
.Lformat_write:
    beq     t0, s10, .Lformat_done
    beq     t0, zero, .Lformat_name
    li      t4, 32
    sb      t4, 0(a3)
    addi    a3, a3, 1
.Lformat_name:
    add     t3, t1, t0
    lbu     t3, 0(t3)
    slli    t3, t3, 2
    add     t3, t2, t3
    lbu     t4, 0(t3)
    sb      t4, 0(a3)
    addi    a3, a3, 1
    lbu     t4, 1(t3)
    beq     t4, zero, .Lformat_written
    sb      t4, 0(a3)
    addi    a3, a3, 1
.Lformat_written:
    addi    t0, t0, 1
    j       .Lformat_write
.Lformat_done:
    sb      zero, 0(a3)
    mv      a0, s10
    j       .Lrubik_return
.Lbuffer_small:
    beq     a2, zero, .Lbuffer_return
    sb      zero, 0(a1)
.Lbuffer_return:
    li      a0, -2
    j       .Lrubik_return
.Lhw1_invalid_input:
.Lhw1_capacity_error:
.Lhw1_search_failed:
    li      a0, -1
    j       .Lrubik_return
.Lrubik_return:
    lw      s0, 0(sp)
    lw      s1, 4(sp)
    lw      s2, 8(sp)
    lw      s3, 12(sp)
    lw      s4, 16(sp)
    lw      s5, 20(sp)
    lw      s6, 24(sp)
    lw      s7, 28(sp)
    lw      s8, 32(sp)
    lw      s9, 36(sp)
    lw      s10, 40(sp)
    lw      s11, 44(sp)
    lw      ra, 56(sp)
    addi    sp, sp, 64
    ret
# The table stores one shortest next move for every state within five moves.
.Lnear5_finish:
    slli a0, s0, 10
    or a0, a0, s1
    call .Lnear5_lookup
    li t0, -1
    beq a0, t0, .Lhw1_backtrack
    srli t0, a0, 4
    andi t0, t0, 7
    sub t1, s8, s10
    bltu t1, t0, .Lhw1_backtrack
    beq t0, zero, .Lhw1_solved
    andi s2, a0, 15
    la t0, search_path
    add t0, t0, s10
    sb s2, 0(t0)
    addi s10, s10, 1
    add t0, s4, s2
    lbu t1, 0(t0)
    add t0, s7, s2
    lbu t2, 0(t0)
    beq t1, zero, .Lnear5_r
    li t0, 1
    beq t1, t0, .Lnear5_b
    la t3, perm_D
    la t4, orient_D
    j .Lnear5_turn
.Lnear5_r:
    la t3, perm_R
    la t4, orient_R
    j .Lnear5_turn
.Lnear5_b:
    la t3, perm_B
    la t4, orient_B
.Lnear5_turn:
    slli t0, s0, 1
    add t0, t3, t0
    lhu s0, 0(t0)
    slli t0, s1, 1
    add t0, t4, t0
    lhu s1, 0(t0)
    addi t2, t2, -1
    bne t2, zero, .Lnear5_turn
    j .Lnear5_finish

# a0 = key; returns packed record, or -1. Clobbers only t0-t6 and a0.
.Lnear5_lookup:
    li t0, 0
    li t1, RUBIK_NEAR5_COUNT
    la t2, .Lnear5_table
.Lnear5_binary:
    bgeu t0, t1, .Lnear5_missing
    add t3, t0, t1
    srli t3, t3, 1
    slli t4, t3, 2
    add t4, t2, t4
    lw t5, 0(t4)
    srli t6, t5, 7
    beq a0, t6, .Lnear5_found
    bltu a0, t6, .Lnear5_left
    addi t0, t3, 1
    j .Lnear5_binary
.Lnear5_left:
    mv t1, t3
    j .Lnear5_binary
.Lnear5_found:
    mv a0, t5
    ret
.Lnear5_missing:
    li a0, -1
    ret

    .size   rubik_solve_asm, .-rubik_solve_asm

    .include "src/rubik/rubik_tables.inc"
    .include "src/rubik/rubik_distance11.inc"
    .section .rodata
    .balign 4
move_names:
    .byte 82,0,0,0, 82,50,0,0, 82,39,0,0
    .byte 66,0,0,0, 66,50,0,0, 66,39,0,0
    .byte 68,0,0,0, 68,50,0,0, 68,39,0,0
    .section .bss
    .balign 4
search_stack:
    .space 96
search_path:
    .space 11
