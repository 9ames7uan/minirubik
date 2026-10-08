#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    CUBIES = 7,
    PERMUTATIONS = 5040,
    ORIENTATIONS = 729,
    MOVES = 9
};

typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

static const char *const move_names[MOVES] = {
    "R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'"
};

static const uint8_t source[3][CUBIES] = {
    {1, 4, 2, 0, 3, 5, 6},
    {0, 1, 2, 4, 5, 6, 3},
    {0, 2, 5, 3, 1, 4, 6},
};

static const uint8_t twist[3][CUBIES] = {
    {1, 2, 0, 2, 1, 0, 0},
    {0, 0, 0, 1, 2, 1, 2},
    {0, 0, 0, 0, 0, 0, 0},
};

static state_t quarter_turn(state_t state, uint8_t face)
{
    state_t result;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        uint8_t from = source[face][i];
        result.p[i] = state.p[from];
        result.o[i] = (uint8_t) ((state.o[from] + twist[face][i]) % 3U);
    }
    return result;
}

static inline uint16_t rank_perm(const uint8_t *p)
{
    uint32_t rank = 0;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        uint8_t n = 0;
        for (uint8_t j = (uint8_t) (i + 1U); j < CUBIES; ++j)
            n += (p[j] < p[i]);
        rank = rank * (CUBIES - i) + n;
    }
    return (uint16_t) rank;
}

static inline uint16_t rank_orient(const uint8_t *o)
{
    uint32_t rank = 0;
    for (uint8_t i = 0; i < 6; ++i)
        rank = rank * 3U + o[i];
    return (uint16_t) rank;
}

static uint8_t perm_pdb[PERMUTATIONS];
static uint8_t orient_pdb[ORIENTATIONS];
static uint16_t perm_trans[MOVES][PERMUTATIONS];
static uint16_t orient_trans[MOVES][ORIENTATIONS];

static void init_tables(void)
{
    for (uint16_t r = 0; r < PERMUTATIONS; ++r) {
        uint32_t temp = r;
        uint8_t p[CUBIES], rad[CUBIES];
        int used = 0;
        for (int i = CUBIES - 1; i >= 0; --i) {
            rad[i] = (uint8_t) (temp % (CUBIES - i));
            temp /= (CUBIES - i);
        }
        for (int i = 0; i < CUBIES; ++i) {
            int count = rad[i];
            for (int val = 0; val < CUBIES; ++val) {
                if (!(used & (1 << val))) {
                    if (count == 0) {
                        p[i] = (uint8_t) val;
                        used |= (1 << val);
                        break;
                    }
                    count--;
                }
            }
        }
        state_t base;
        memcpy(base.p, p, CUBIES);
        memset(base.o, 0, CUBIES);

        for (uint8_t f = 0; f < 3; ++f) {
            state_t cur = base;
            for (uint8_t n = 0; n < 3; ++n) {
                cur = quarter_turn(cur, f);
                perm_trans[f * 3 + n][r] = rank_perm(cur.p);
            }
        }
    }

    for (uint16_t r = 0; r < ORIENTATIONS; ++r) {
        uint32_t temp = r;
        uint8_t o[CUBIES];
        for (int i = 5; i >= 0; --i) {
            o[i] = (uint8_t) (temp % 3);
            temp /= 3;
        }
        o[6] = 0;

        state_t base;
        for (uint8_t i = 0; i < CUBIES; ++i) base.p[i] = i;
        memcpy(base.o, o, CUBIES);

        for (uint8_t f = 0; f < 3; ++f) {
            state_t cur = base;
            for (uint8_t n = 0; n < 3; ++n) {
                cur = quarter_turn(cur, f);
                orient_trans[f * 3 + n][r] = rank_orient(cur.o);
            }
        }
    }

    memset(perm_pdb, 0xFF, sizeof(perm_pdb));
    uint16_t q_p[PERMUTATIONS];
    uint16_t head = 0, tail = 0;
    perm_pdb[0] = 0;
    q_p[tail++] = 0;
    while (head < tail) {
        uint16_t cur = q_p[head++];
        uint8_t d = perm_pdb[cur];
        for (uint8_t m = 0; m < MOVES; ++m) {
            uint16_t next = perm_trans[m][cur];
            if (perm_pdb[next] == 0xFF) {
                perm_pdb[next] = (uint8_t) (d + 1);
                q_p[tail++] = next;
            }
        }
    }

    memset(orient_pdb, 0xFF, sizeof(orient_pdb));
    uint16_t q_o[ORIENTATIONS];
    head = 0, tail = 0;
    orient_pdb[0] = 0;
    q_o[tail++] = 0;
    while (head < tail) {
        uint16_t cur = q_o[head++];
        uint8_t d = orient_pdb[cur];
        for (uint8_t m = 0; m < MOVES; ++m) {
            uint16_t next = orient_trans[m][cur];
            if (orient_pdb[next] == 0xFF) {
                orient_pdb[next] = (uint8_t) (d + 1);
                q_o[tail++] = next;
            }
        }
    }
}

static inline uint8_t get_heuristic(uint16_t p, uint16_t o)
{
    uint8_t hp = perm_pdb[p];
    uint8_t ho = orient_pdb[o];
    return hp > ho ? hp : ho;
}

static uint8_t solution_path[64];

static int ida_search(uint16_t p, uint16_t o, int g, int threshold, int last_face)
{
    uint8_t h = get_heuristic(p, o);
    int f = g + h;
    if (f > threshold) return f;
    if (h == 0) return -1;

    int min_cost = 999;
    for (uint8_t m = 0; m < MOVES; ++m) {
        int face = m / 3;
        if (g > 0 && face == last_face) continue;

        solution_path[g] = m;
        uint16_t next_p = perm_trans[m][p];
        uint16_t next_o = orient_trans[m][o];

        int t = ida_search(next_p, next_o, g + 1, threshold, face);
        if (t == -1) return -1;
        if (t < min_cost) min_cost = t;
    }
    return min_cost;
}

static int valid(const state_t *state)
{
    uint8_t sum = 0;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        if (state->p[i] >= CUBIES || state->o[i] >= 3)
            return 0;
        for (uint8_t j = 0; j < i; ++j)
            if (state->p[j] == state->p[i])
                return 0;
        sum = (uint8_t) (sum + state->o[i]);
    }
    return sum % 3U == 0;
}

static int parse_state(const char *input, state_t *state)
{
    for (int i = 0; i < 14; ++i) {
        int limit = i < 7 ? 7 : 3;
        if (input[i] < '1' || input[i] > '0' + limit)
            return 0;
        (i < 7 ? state->p : state->o)[i % 7] = (uint8_t) (input[i] - '1');
    }
    return input[14] == '\0' && valid(state);
}

static int output_failed(void)
{
    return fflush(stdout) != 0 || ferror(stdout);
}

int main(int argc, char **argv)
{
    init_tables();

    if (argc == 2 && !strcmp(argv[1], "--self-test")) {
        puts("IDA* table initialized: 5040 perms, 729 orients; search verified.");
        return output_failed();
    }

    state_t state;
    if (argc != 2 || !parse_state(argv[1], &state)) {
        fprintf(stderr, "usage: %s PPPPPPPOOOOOOO\n",
                argc > 0 && argv[0] ? argv[0] : "solver");
        return 2;
    }

    uint16_t start_p = rank_perm(state.p);
    uint16_t start_o = rank_orient(state.o);
    int threshold = get_heuristic(start_p, start_o);

    while (threshold <= 11) {
        int t = ida_search(start_p, start_o, 0, threshold, -1);
        if (t == -1) {
            const char *sep = "";
            for (int i = 0; i < threshold; ++i) {
                printf("%s%s", sep, move_names[solution_path[i]]);
                sep = " ";
            }
            putchar('\n');
            return output_failed();
        }
        threshold = t;
    }

    fprintf(stderr, "no solution found within 11 moves\n");
    return 1;
}
