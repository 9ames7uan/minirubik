.globl _start

.data
.align 2
path:
    .zero 64

# -------------------------------------------------------------
# Test Cases (as explicitly required by specification)
# 1. Solved state (0 moves)
# 2. Short scramble (1 move: R -> solved by R')
# 3. Distance-11 benchmark state (11 moves)
# -------------------------------------------------------------
test_case_0:  .asciz "12345671111111"
test_case_1:  .asciz "25314672313211"
test_case_11: .asciz "21345671111111"

newline:     .asciz "\n"
str_case0:   .asciz "Case 0 (Solved): "
str_case1:   .asciz "Case 1 (Short): "
str_case11:  .asciz "Case 2 (Dist-11): "

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

.text
_start:
    li      sp, 0x100000

    # ---------------------------------------------------------
    # Execute Benchmark Test Case (test_case_11) for CLI evaluation
    # ---------------------------------------------------------
    la      a0, test_case_11
    jal     ra, solve_cube

    li      a0, 0
    li      a7, 10
    ecall

# =============================================================
# Subroutine: solve_cube
# Input: a0 = pointer to 14-char state string
# =============================================================
solve_cube:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)
    sw      s2, 0(sp)

    jal     ra, parse_and_rank
    mv      s0, a0              # perm_rank
    mv      s1, a1              # orient_rank

    mv      a0, s0
    mv      a1, s1
    jal     ra, get_heuristic
    mv      s2, a0              # threshold

ida_outer_loop:
    li      t0, 11
    bgt     s2, t0, solve_failed

    mv      a0, s0
    mv      a1, s1
    li      a2, 0
    mv      a3, s2
    li      a4, -1
    jal     ra, ida_search

    li      t0, -1
    beq     a0, t0, solve_success

    mv      s2, a0
    j       ida_outer_loop

solve_success:
    li      s3, 0
print_loop:
    bge     s3, s2, print_done
    la      t0, path
    slli    t1, s3, 2
    add     t0, t0, t1
    lw      t2, 0(t0)

    la      t3, move_str_table
    slli    t2, t2, 2
    add     t3, t3, t2
    lw      a0, 0(t3)
    li      a7, 4
    ecall

    addi    s3, s3, 1
    j       print_loop

print_done:
    la      a0, newline
    li      a7, 4
    ecall

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    lw      s1, 4(sp)
    lw      s2, 0(sp)
    addi    sp, sp, 16
    ret

solve_failed:
    li      a0, 1
    li      a7, 10
    ecall

# =============================================================
# IDA* Search Core & Heuristics
# =============================================================
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

    # perm_trans: (m * 5040 + p) * 2
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

    # orient_trans: (m * 729 + o) * 2
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

# =============================================================
# Parse 14-char string and calculate factoradic / base-3 ranks
# =============================================================
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
