.globl _start
.text
_start:
    li      t0, 100000
loop:
    addi    t0, t0, -1
    bnez    t0, loop

    li      a7, 10
    ecall
