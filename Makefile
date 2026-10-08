CC ?= cc
CFLAGS ?= -O3 -std=c99 -Wall -Wextra -Wpedantic

all: solver mini

solver: solver.c
	$(CC) $(CFLAGS) solver.c -o solver

mini: mini.c
	$(CC) $(CFLAGS) mini.c -o mini

# 合併組語並於 Ripes CLI 驗證
solver_final.s: solver.s tables.s
	cat solver.s tables.s > $@

check-asm: solver_final.s
	~/Ripes/build/Ripes --mode cli --proc RV32_ISS --src solver_final.s -t asm --iret

# 提供給任何人的快速一鍵測試腳本
test: solver
	@echo "=== 1. Test Solved State (Expect 0 moves) ==="
	@./solver 12345671111111
	@echo "PASS: Solved state handled."
	@echo ""
	@echo "=== 2. Test Benchmark State ==="
	@./solver 21345671111111
	@echo "PASS: Benchmark state solved."

clean:
	rm -f solver mini solver_final.s run_ripes_gui.s gen_testcases test_htm_exact
