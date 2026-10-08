#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CUBIES 7
#define MOVES 9
#define PERM_STATES 5040
#define ORIENT_STATES 729

static uint8_t perm_dist[PERM_STATES];
static uint8_t orient_dist[ORIENT_STATES];
static uint16_t perm_trans[MOVES][PERM_STATES];
static uint16_t orient_trans[MOVES][ORIENT_STATES];

static const char *move_names[MOVES] = {
    "R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'"
};

/* Move history stack */
static int path[16];
static unsigned long long expanded_nodes = 0;

/* Admissible Heuristic */
static inline int get_heuristic(uint16_t p, uint16_t o) {
    int hp = perm_dist[p];
    int ho = orient_dist[o];
    return (hp > ho) ? hp : ho;
}

/* Recursive Depth-First Search with Branch-and-Bound */
static int ida_search(uint16_t p, uint16_t o, int g, int bound, int last_face) {
    expanded_nodes++;
    int h = get_heuristic(p, o);
    int f = g + h;
    if (f > bound) return f;
    if (h == 0) return -1; /* Found optimal solution */

    int min_next = 999;

    for (int m = 0; m < MOVES; m++) {
        int face = m / 3;
        /* Face pruning: Do not move the same face consecutively */
        if (g > 0 && face == last_face) continue;

        uint16_t next_p = perm_trans[m][p];
        uint16_t next_o = orient_trans[m][o];

        path[g] = m;
        int t = ida_search(next_p, next_o, g + 1, bound, face);
        if (t == -1) return -1; /* Solved */
        if (t < min_next) min_next = t;
    }
    return min_next;
}

static uint16_t parse_and_rank_perm(const char *s) {
    uint8_t p[CUBIES];
    for (int i = 0; i < CUBIES; i++) p[i] = s[i] - '1';
    uint16_t r = 0;
    for (int i = 0; i < CUBIES; i++) {
        uint16_t c = 0;
        for (int j = i + 1; j < CUBIES; j++) {
            if (p[j] < p[i]) c++;
        }
        r = r * (CUBIES - i) + c;
    }
    return r;
}

static uint16_t parse_and_rank_orient(const char *s) {
    uint16_t r = 0;
    for (int i = 0; i < 6; i++) {
        r = r * 3 + (s[CUBIES + i] - '1');
    }
    return r;
}

int main(int argc, char **argv) {
    const char *scramble = (argc > 1) ? argv[1] : "21345671111111";

    /* 1. Load PDB and transition tables */
    FILE *fp = fopen("perm_pdb.bin", "rb");
    if (!fp || fread(perm_dist, 1, PERM_STATES, fp) != PERM_STATES) {
        fprintf(stderr, "Error loading perm_pdb.bin\n");
        return 1;
    }
    fclose(fp);

    fp = fopen("orient_pdb.bin", "rb");
    if (!fp || fread(orient_dist, 1, ORIENT_STATES, fp) != ORIENT_STATES) {
        fprintf(stderr, "Error loading orient_pdb.bin\n");
        return 1;
    }
    fclose(fp);

    fp = fopen("perm_trans.bin", "rb");
    if (!fp || fread(perm_trans, sizeof(uint16_t), MOVES * PERM_STATES, fp) != MOVES * PERM_STATES) {
        fprintf(stderr, "Error loading perm_trans.bin\n");
        return 1;
    }
    fclose(fp);

    fp = fopen("orient_trans.bin", "rb");
    if (!fp || fread(orient_trans, sizeof(uint16_t), MOVES * ORIENT_STATES, fp) != MOVES * ORIENT_STATES) {
        fprintf(stderr, "Error loading orient_trans.bin\n");
        return 1;
    }
    fclose(fp);

    /* 2. Parse initial state */
    uint16_t p0 = parse_and_rank_perm(scramble);
    uint16_t o0 = parse_and_rank_orient(scramble);

    printf("Solving vector: %s\n", scramble);
    printf("Initial rank: perm=%u (h=%u), orient=%u (h=%u)\n", 
           p0, perm_dist[p0], o0, orient_dist[o0]);

    /* 3. IDA* Outer Loop */
    int bound = get_heuristic(p0, o0);
    expanded_nodes = 0;

    while (bound <= 11) {
        printf("Iteration bound = %d ...\n", bound);
        int t = ida_search(p0, o0, 0, bound, -1);
        if (t == -1) {
            printf("\n>>> Solution found at depth %d! <<<\n", bound);
            printf("Move sequence: ");
            for (int i = 0; i < bound; i++) {
                printf("%s ", move_names[path[i]]);
            }
            printf("\nTotal expanded nodes: %llu\n", expanded_nodes);
            return 0;
        }
        bound = t;
    }

    printf("No solution within 11 moves.\n");
    return 1;
}
