.globl _start

.data
.align 2
buffer:
    .zero 1000000

.text
_start:
    la      t0, buffer
    li      t1, 1000000
    li      t2, 0x42
write_loop:
    sb      t2, 0(t0)
    addi    t0, t0, 1
    addi    t1, t1, -1
    bnez    t1, write_loop

    li      a7, 10
    ecall
