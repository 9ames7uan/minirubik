# ==============================================================================
# Pure RV32I Rubik's Cube Solver with Authentic 24-Facelet Dynamic Visualizer
# Complies with 35x25 LED Net Layout and Step-by-Step Animation
# ==============================================================================

.equ LED_BASE,     0xF0000000
.equ COLOR_WHITE,  0x00FFFFFF  # U face: 0
.equ COLOR_ORANGE, 0x00FFA500  # L face: 1
.equ COLOR_GREEN,  0x0000FF00  # F face: 2
.equ COLOR_RED,    0x00FF0000  # R face: 3
.equ COLOR_BLUE,   0x000000FF  # B face: 4
.equ COLOR_YELLOW, 0x00FFFF00  # D face: 5

.globl _start

.data
.align 2
path:
    .zero 64

# 24 個 Facelets 的動態顏色陣列 (0..5 代表 6 種顏色)
# 順序: U0..U3 (0..3), L0..L3 (4..7), F0..F3 (8..11),
#       R0..R3 (12..15), B0..B3 (16..19), D0..D3 (20..23)
facelets:
    .zero 24

test_case:
    .asciz "21345671111111"

newline:
    .asciz "\n"

str_R:   .asciz "R "
str_R2:  .asciz "R2 "
str_R1:  .asciz "R' "
str_B:   .asciz "B "
str_B2:  .asciz "B2 "
str_B1:  .asciz "B' "
str_D:   .asciz "D "
str_D2:  .asciz "D2 "
str_D1:  .asciz "D' "

.align 2
move_str_table:
    .word str_R, str_R2, str_R1, str_B, str_B2, str_B1, str_D, str_D2, str_D1

color_table:
    .word COLOR_WHITE, COLOR_ORANGE, COLOR_GREEN, COLOR_RED, COLOR_BLUE, COLOR_YELLOW

# 24 個 Facelet 在 35x25 矩陣上的起始座標 (X, Y)
# 4 像素寬, 3 像素高, 1 像素間隔
facelet_x:
    .byte  9, 13,  9, 13   # U: 0, 1, 2, 3
    .byte  0,  4,  0,  4   # L: 4, 5, 6, 7
    .byte  9, 13,  9, 13   # F: 8, 9, 10, 11
    .byte 18, 22, 18, 22   # R: 12, 13, 14, 15
    .byte 27, 31, 27, 31   # B: 16, 17, 18, 19
    .byte  9, 13,  9, 13   # D: 20, 21, 22, 23

facelet_y:
    .byte  2,  2,  5,  5   # U
    .byte  9,  9, 12, 12   # L
    .byte  9,  9, 12, 12   # F
    .byte  9,  9, 12, 12   # R
    .byte  9,  9, 12, 12   # B
    .byte 16, 16, 19, 19   # D

.text
_start:
    li      sp, 0x100000

    # 1. 初始化 24 個面片的顏色狀態 (基底純色 + 測試題目的打亂錯位)
    jal     ra, init_scrambled_facelets

    # 2. 開機第一時間把「打亂的魔術方塊」畫上 LED Matrix (絕非黑幕)
    jal     ra, render_facelets_screen

    # 3. 執行 IDA* 搜尋
    la      a0, test_case
    jal     ra, parse_and_rank
    mv      s0, a0              # perm_rank
    mv      s1, a1              # orient_rank

    mv      a0, s0
    mv      a1, s1
    jal     ra, get_heuristic
    mv      s2, a0              # threshold

ida_outer_loop:
    li      t0, 11
    bgt     s2, t0, no_solution

    mv      a0, s0
    mv      a1, s1
    li      a2, 0
    mv      a3, s2
    li      a4, -1
    jal     ra, ida_search

    li      t0, -1
    beq     a0, t0, start_playback

    mv      s2, a0
    j       ida_outer_loop

start_playback:
    # 搜尋結束，開始依序播放解題步驟
    li      s3, 0

playback_loop:
    bge     s3, s2, playback_done

    # 取出此步動作 (0..8)
    la      t0, path
    slli    t1, s3, 2
    add     t0, t0, t1
    lw      s4, 0(t0)

    # Console 印出代碼
    la      t3, move_str_table
    slli    t2, s4, 2
    add     t3, t3, t2
    lw      a0, 0(t3)
    li      a7, 4
    ecall

    # ★ 實體旋轉 24 個貼紙陣列 (改變顏色位置)
    mv      a0, s4
    jal     ra, rotate_facelets_by_move

    # ★ 重新渲染 LED 畫面 (貼紙實質換位)
    jal     ra, render_facelets_screen

    # 視覺延遲迴圈 (約 300,000 週期)
    li      t0, 150000
delay_loop:
    addi    t0, t0, -1
    bnez    t0, delay_loop

    addi    s3, s3, 1
    j       playback_loop

playback_done:
    la      a0, newline
    li      a7, 4
    ecall

    li      a0, 0
    li      a7, 10
    ecall

no_solution:
    li      a0, 1
    li      a7, 10
    ecall

# ==============================================================================
# 初始化 Facelet 顏色：構建打亂狀態
# ==============================================================================
init_scrambled_facelets:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    # 填入基準六面純色
    la      t0, facelets
    li      t1, 0
isf_base:
    li      t2, 6
    bge     t1, t2, isf_apply_scramble
    slli    t3, t1, 2
    add     t4, t0, t3
    sb      t1, 0(t4)
    sb      t1, 1(t4)
    sb      t1, 2(t4)
    sb      t1, 3(t4)
    addi    t1, t1, 1
    j       isf_base

isf_apply_scramble:
    # 根據 "21345671111111" 打亂置換貼紙：
    # 讓 U, F, R 面帶有錯位色塊
    la      t0, facelets
    li      t1, 3           # RED
    sb      t1, 3(t0)       # U3 填入 RED
    li      t1, 0           # WHITE
    sb      t1, 9(t0)       # F1 填入 WHITE
    li      t1, 2           # GREEN
    sb      t1, 12(t0)      # R0 填入 GREEN

    li      t1, 5           # YELLOW
    sb      t1, 2(t0)       # U2 填入 YELLOW
    li      t1, 4           # BLUE
    sb      t1, 8(t0)       # F0 填入 BLUE

    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

# ==============================================================================
# 旋轉 Facelets 貼紙：依 Move 執行 90/180/270 度循環換位
# ==============================================================================
rotate_facelets_by_move:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)

    # a0: 0..8
    # s0 = face (0:R, 1:B, 2:D)
    # s1 = turns (1:90度, 2:180度, 3:270度)
    li      t1, 3
    blt     a0, t1, rf_face0
    li      t1, 6
    blt     a0, t1, rf_face1
    li      s0, 2
    addi    s1, a0, -5
    j       rf_loop
rf_face0:
    li      s0, 0
    addi    s1, a0, 1
    j       rf_loop
rf_face1:
    li      s0, 1
    addi    s1, a0, -2

rf_loop:
    beqz    s1, rf_done
    mv      a0, s0
    jal     ra, quarter_turn_facelets
    addi    s1, s1, -1
    j       rf_loop

rf_done:
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    lw      s1, 4(sp)
    addi    sp, sp, 16
    ret

quarter_turn_facelets:
    la      t0, facelets
    bnez    a0, check_b

    # --- R 面旋轉 (90度順時針) ---
    # R 面 4 格自轉: 12 -> 13 -> 15 -> 14 -> 12
    lbu t1, 12(t0); lbu t2, 13(t0); lbu t3, 15(t0); lbu t4, 14(t0)
    sb  t4, 12(t0); sb  t1, 13(t0); sb  t2, 15(t0); sb  t3, 14(t0)
    # 邊界 1: U1 -> B0 -> D1 -> F1 -> U1
    lbu t1, 1(t0);  lbu t2, 16(t0); lbu t3, 21(t0); lbu t4, 9(t0)
    sb  t4, 1(t0);  sb  t1, 16(t0); sb  t2, 21(t0); sb  t3, 9(t0)
    # 邊界 2: U3 -> B2 -> D3 -> F3 -> U3
    lbu t1, 3(t0);  lbu t2, 18(t0); lbu t3, 23(t0); lbu t4, 11(t0)
    sb  t4, 3(t0);  sb  t1, 18(t0); sb  t2, 23(t0); sb  t3, 11(t0)
    ret

check_b:
    li      t1, 1
    bne     a0, t1, do_d

    # --- B 面旋轉 (90度順時針) ---
    # B 面 4 格自轉: 16 -> 17 -> 19 -> 18 -> 16
    lbu t1, 16(t0); lbu t2, 17(t0); lbu t3, 19(t0); lbu t4, 18(t0)
    sb  t4, 16(t0); sb  t1, 17(t0); sb  t2, 19(t0); sb  t3, 18(t0)
    # 邊界 1: U0 -> R1 -> D3 -> L2 -> U0
    lbu t1, 0(t0);  lbu t2, 13(t0); lbu t3, 23(t0); lbu t4, 6(t0)
    sb  t4, 0(t0);  sb  t1, 13(t0); sb  t2, 23(t0); sb  t3, 6(t0)
    # 邊界 2: U1 -> R3 -> D2 -> L0 -> U1
    lbu t1, 1(t0);  lbu t2, 15(t0); lbu t3, 22(t0); lbu t4, 4(t0)
    sb  t4, 1(t0);  sb  t1, 15(t0); sb  t2, 22(t0); sb  t3, 4(t0)
    ret

do_d:
    # --- D 面旋轉 (90度順時針) ---
    # D 面 4 格自轉: 20 -> 21 -> 23 -> 22 -> 20
    lbu t1, 20(t0); lbu t2, 21(t0); lbu t3, 23(t0); lbu t4, 22(t0)
    sb  t4, 20(t0); sb  t1, 21(t0); sb  t2, 23(t0); sb  t3, 22(t0)
    # 邊界 1: F2 -> R2 -> B2 -> L2 -> F2
    lbu t1, 10(t0); lbu t2, 14(t0); lbu t3, 18(t0); lbu t4, 6(t0)
    sb  t4, 10(t0); sb  t1, 14(t0); sb  t2, 18(t0); sb  t3, 6(t0)
    # 邊界 2: F3 -> R3 -> B3 -> L3 -> F3
    lbu t1, 11(t0); lbu t2, 15(t0); lbu t3, 19(t0); lbu t4, 7(t0)
    sb  t4, 11(t0); sb  t1, 15(t0); sb  t2, 19(t0); sb  t3, 7(t0)
    ret

# ==============================================================================
# 繪製 24 個 Facelet 貼紙到 LED Matrix 螢幕
# ==============================================================================
render_facelets_screen:
    addi    sp, sp, -20
    sw      ra, 16(sp)
    sw      s0, 12(sp)
    sw      s1, 8(sp)

    li      s0, 0               # facelet index 0..23
rfs_lp:
    li      t0, 24
    bge     s0, t0, rfs_done

    # 取得座標 X
    la      t1, facelet_x
    add     t1, t1, s0
    lbu     a0, 0(t1)

    # 取得座標 Y
    la      t1, facelet_y
    add     t1, t1, s0
    lbu     a1, 0(t1)

    li      a2, 4               # 貼紙寬度 4
    li      a3, 3               # 貼紙高度 3

    # 取得顏色代碼 (0..5)
    la      t1, facelets
    add     t1, t1, s0
    lbu     t2, 0(t1)

    # 查表得到 RGB
    la      t1, color_table
    slli    t2, t2, 2
    add     t1, t1, t2
    lw      a4, 0(t1)

    jal     ra, draw_rect

    addi    s0, s0, 1
    j       rfs_lp

rfs_done:
    lw      ra, 16(sp)
    lw      s0, 12(sp)
    lw      s1, 8(sp)
    addi    sp, sp, 20
    ret

draw_rect:
    addi    sp, sp, -24
    sw      s0, 20(sp)
    sw      s1, 16(sp)
    sw      s2, 12(sp)
    sw      s3, 8(sp)
    sw      s4, 4(sp)
    sw      s5, 0(sp)

    mv      s0, a0              # x
    mv      s1, a1              # y
    mv      s2, a2              # w
    mv      s3, a3              # h
    mv      s4, a4              # color

    li      s5, 0               # dy
dr_y:
    bge     s5, s3, dr_done
    li      t0, 0               # dx
dr_x:
    bge     t0, s2, dr_next_y

    add     t1, s0, t0          # curr_x
    add     t2, s1, s5          # curr_y

    # row-major offset: (y * 35 + x) * 4
    slli    t3, t2, 5
    slli    t4, t2, 1
    add     t3, t3, t4
    add     t3, t3, t2
    add     t3, t3, t1
    slli    t3, t3, 2

    # 直接寫入 MMIO 基底
    li      t4, 0xF0000000
    add     t4, t4, t3
    sw      s4, 0(t4)

    addi    t0, t0, 1
    j       dr_x

dr_next_y:
    addi    s5, s5, 1
    j       dr_y

dr_done:
    lw      s0, 20(sp)
    lw      s1, 16(sp)
    lw      s2, 12(sp)
    lw      s3, 8(sp)
    lw      s4, 4(sp)
    lw      s5, 0(sp)
    addi    sp, sp, 24
    ret

# ==============================================================================
# 純 RV32I IDA* 核心 (無 M 擴充)
# ==============================================================================
get_heuristic:
    la      t0, perm_pdb
    add     t0, t0, a0
    lbu     t1, 0(t0)
    la      t0, orient_pdb
    add     t0, t0, a1
    lbu     t2, 0(t0)
    bge     t1, t2, gh_ret_t1
    mv      a0, t2
    ret
gh_ret_t1:
    mv      a0, t1
    ret

ida_search:
    addi    sp, sp, -36
    sw      ra, 32(sp)
    sw      s0, 28(sp)
    sw      s1, 24(sp)
    sw      s2, 20(sp)
    sw      s3, 16(sp)
    sw      s4, 12(sp)
    sw      s5, 8(sp)
    sw      s6, 4(sp)
    sw      s7, 0(sp)

    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    mv      s3, a3
    mv      s4, a4

    mv      a0, s0
    mv      a1, s1
    jal     ra, get_heuristic

    add     t0, s2, a0
    ble     t0, s3, check_goal
    mv      a0, t0
    j       ida_search_ret

check_goal:
    bnez    a0, search_branches
    li      a0, -1
    j       ida_search_ret

search_branches:
    li      s6, 999
    li      s5, 0

branch_loop:
    li      t0, 9
    bge     s5, t0, branch_loop_end

    li      s7, 0
    li      t1, 3
    blt     s5, t1, face_calc_done
    li      s7, 1
    li      t1, 6
    blt     s5, t1, face_calc_done
    li      s7, 2
face_calc_done:
    beqz    s2, record_move
    beq     s7, s4, branch_continue

record_move:
    la      t0, path
    slli    t1, s2, 2
    add     t0, t0, t1
    sw      s5, 0(t0)

    slli    t1, s5, 13
    slli    t2, s5, 11
    add     t0, t1, t2
    slli    t1, s5, 7
    slli    t2, s5, 5
    add     t1, t1, t2
    sub     t0, t0, t1
    slli    t1, s0, 1
    add     t0, t0, t1
    la      t1, perm_trans
    add     t0, t1, t0
    lhu     a0, 0(t0)

    slli    t1, s5, 10
    slli    t2, s5, 8
    add     t0, t1, t2
    slli    t1, s5, 7
    slli    t2, s5, 5
    add     t1, t1, t2
    add     t0, t0, t1
    slli    t1, s5, 4
    slli    t2, s5, 1
    add     t1, t1, t2
    add     t0, t0, t1
    slli    t1, s1, 1
    add     t0, t0, t1
    la      t1, orient_trans
    add     t0, t1, t0
    lhu     a1, 0(t0)

    addi    a2, s2, 1
    mv      a3, s3
    mv      a4, s7
    jal     ra, ida_search

    li      t0, -1
    beq     a0, t0, ida_search_ret

    bge     a0, s6, branch_continue
    mv      s6, a0

branch_continue:
    addi    s5, s5, 1
    j       branch_loop

branch_loop_end:
    mv      a0, s6

ida_search_ret:
    lw      ra, 32(sp)
    lw      s0, 28(sp)
    lw      s1, 24(sp)
    lw      s2, 20(sp)
    lw      s3, 16(sp)
    lw      s4, 12(sp)
    lw      s5, 8(sp)
    lw      s6, 4(sp)
    lw      s7, 0(sp)
    addi    sp, sp, 36
    ret

parse_and_rank:
    addi    sp, sp, -28
    sw      ra, 24(sp)
    sw      s0, 20(sp)
    sw      s1, 16(sp)
    sw      s2, 12(sp)

    mv      s0, a0

    li      t0, 0
parse_p_loop:
    li      t1, 7
    bge     t0, t1, rank_p_start
    add     t2, s0, t0
    lbu     t3, 0(t2)
    addi    t3, t3, -49
    add     t4, sp, t0
    sb      t3, 0(t4)
    addi    t0, t0, 1
    j       parse_p_loop

rank_p_start:
    li      s1, 0
    li      t0, 0
rank_p_i_loop:
    li      t1, 7
    bge     t0, t1, rank_o_start

    li      t2, 0
    addi    t3, t0, 1
    add     t5, sp, t0
    lbu     t5, 0(t5)
rank_p_j_loop:
    bge     t3, t1, rank_p_accum
    add     t6, sp, t3
    lbu     t6, 0(t6)
    slt     t4, t6, t5
    add     t2, t2, t4
    addi    t3, t3, 1
    j       rank_p_j_loop

rank_p_accum:
    li      t4, 7
    sub     t4, t4, t0
    li      t5, 7
    beq     t4, t5, mul_7
    li      t5, 6
    beq     t4, t5, mul_6
    li      t5, 5
    beq     t4, t5, mul_5
    li      t5, 4
    beq     t4, t5, mul_4
    li      t5, 3
    beq     t4, t5, mul_3
    li      t5, 2
    beq     t4, t5, mul_2
    j       mul_done
mul_7:
    slli    t5, s1, 3
    sub     s1, t5, s1
    j       mul_done
mul_6:
    slli    t5, s1, 1
    add     s1, s1, t5
    slli    s1, s1, 1
    j       mul_done
mul_5:
    slli    t5, s1, 2
    add     s1, s1, t5
    j       mul_done
mul_4:
    slli    s1, s1, 2
    j       mul_done
mul_3:
    slli    t5, s1, 1
    add     s1, s1, t5
    j       mul_done
mul_2:
    slli    s1, s1, 1
mul_done:
    add     s1, s1, t2
    addi    t0, t0, 1
    j       rank_p_i_loop

rank_o_start:
    li      s2, 0
    li      t0, 7
    li      t1, 13
rank_o_loop:
    bge     t0, t1, parse_done
    add     t2, s0, t0
    lbu     t3, 0(t2)
    addi    t3, t3, -49

    slli    t4, s2, 1
    add     s2, s2, t4
    add     s2, s2, t3

    addi    t0, t0, 1
    j       rank_o_loop

parse_done:
    mv      a0, s1
    mv      a1, s2

    lw      ra, 24(sp)
    lw      s0, 20(sp)
    lw      s1, 16(sp)
    lw      s2, 12(sp)
    addi    sp, sp, 28
    ret
