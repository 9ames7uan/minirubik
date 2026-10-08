#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CUBIES 7
#define FACES 3
#define MOVES 9
#define PERM_STATES 5040
#define ORIENT_STATES 729

/* 
 * Corner mapping aligned with minirubik report.md:
 * Faces: 0: R, 1: B, 2: D
 * Cubie indices 0..6 represent physical positions 1..7 (corner 0 is fixed at UFL)
 */
static const uint8_t source[FACES][CUBIES] = {
    {1, 4, 2, 0, 3, 5, 6}, /* R: 1->4, 4->5, 5->2, 2->1 (internal 0-based) */
    {0, 1, 2, 6, 3, 4, 5}, /* B: 4->7, 7->6, 6->5, 5->4 (internal 0-based) */
    {0, 4, 1, 3, 5, 2, 6}  /* D: 2->5, 5->6, 6->3, 3->2 (internal 0-based) */
};

static const uint8_t twist[FACES][CUBIES] = {
    {2, 1, 0, 1, 2, 0, 0}, /* R: delta twists */
    {0, 0, 0, 2, 1, 2, 1}, /* B: delta twists */
    {0, 0, 0, 0, 0, 0, 0}  /* D: twists remain in-plane */
};

/* --- Permutation Lehmer Ranking --- */
static uint16_t rank_perm(const uint8_t p[CUBIES]) {
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

static void unrank_perm(uint16_t r, uint8_t p[CUBIES]) {
    uint8_t avail[CUBIES];
    for (int i = 0; i < CUBIES; i++) avail[i] = i;
    for (int i = 0; i < CUBIES; i++) {
        int fact = 1;
        for (int k = 1; k < CUBIES - i; k++) fact *= k;
        int digit = r / fact;
        r %= fact;
        p[i] = avail[digit];
        for (int j = digit; j < CUBIES - 1 - i; j++) {
            avail[j] = avail[j + 1];
        }
    }
}

/* --- Orientation Base-3 Ranking --- */
static uint16_t rank_orient(const uint8_t o[CUBIES]) {
    uint16_t r = 0;
    for (int i = 0; i < 6; i++) {
        r = r * 3 + o[i];
    }
    return r;
}

static void unrank_orient(uint16_t r, uint8_t o[CUBIES]) {
    int sum = 0;
    for (int i = 5; i >= 0; i--) {
        o[i] = r % 3;
        sum += o[i];
        r /= 3;
    }
    o[6] = (3 - (sum % 3)) % 3;
}

int main(void) {
    uint16_t perm_trans[MOVES][PERM_STATES];
    uint16_t orient_trans[MOVES][ORIENT_STATES];
    uint8_t perm_dist[PERM_STATES];
    uint8_t orient_dist[ORIENT_STATES];

    /* 1. Build quarter-turn base transitions */
    for (uint16_t r = 0; r < PERM_STATES; r++) {
        uint8_t p[CUBIES], p_next[CUBIES];
        unrank_perm(r, p);
        for (int f = 0; f < FACES; f++) {
            for (int i = 0; i < CUBIES; i++) p_next[i] = p[source[f][i]];
            perm_trans[f * 3][r] = rank_perm(p_next);
        }
    }

    for (uint16_t r = 0; r < ORIENT_STATES; r++) {
        uint8_t o[CUBIES], o_next[CUBIES];
        unrank_orient(r, o);
        for (int f = 0; f < FACES; f++) {
            for (int i = 0; i < CUBIES; i++) {
                o_next[i] = (o[source[f][i]] + twist[f][i]) % 3;
            }
            orient_trans[f * 3][r] = rank_orient(o_next);
        }
    }

    /* 2. Synthesize half turns and inverse turns */
    for (int f = 0; f < FACES; f++) {
        int m90 = f * 3, m180 = f * 3 + 1, m270 = f * 3 + 2;
        for (int r = 0; r < PERM_STATES; r++) {
            perm_trans[m180][r] = perm_trans[m90][perm_trans[m90][r]];
            perm_trans[m270][r] = perm_trans[m90][perm_trans[m180][r]];
        }
        for (int r = 0; r < ORIENT_STATES; r++) {
            orient_trans[m180][r] = orient_trans[m90][orient_trans[m90][r]];
            orient_trans[m270][r] = orient_trans[m90][orient_trans[m180][r]];
        }
    }

    /* 3. BFS for Permutation PDB */
    memset(perm_dist, 0xFF, sizeof(perm_dist));
    uint16_t q_perm[PERM_STATES];
    int head = 0, tail = 0;
    perm_dist[0] = 0;
    q_perm[tail++] = 0;

    while (head < tail) {
        uint16_t u = q_perm[head++];
        uint8_t d = perm_dist[u];
        for (int m = 0; m < MOVES; m++) {
            uint16_t v = perm_trans[m][u];
            if (perm_dist[v] == 0xFF) {
                perm_dist[v] = d + 1;
                q_perm[tail++] = v;
            }
        }
    }

    /* 4. BFS for Orientation PDB */
    memset(orient_dist, 0xFF, sizeof(orient_dist));
    uint16_t q_orient[ORIENT_STATES];
    head = 0; tail = 0;
    orient_dist[0] = 0;
    q_orient[tail++] = 0;

    while (head < tail) {
        uint16_t u = q_orient[head++];
        uint8_t d = orient_dist[u];
        for (int m = 0; m < MOVES; m++) {
            uint16_t v = orient_trans[m][u];
            if (orient_dist[v] == 0xFF) {
                orient_dist[v] = d + 1;
                q_orient[tail++] = v;
            }
        }
    }

    /* 5. Validation (Correctness Gate H2) */
    uint8_t max_p = 0, max_o = 0;
    for (int i = 0; i < PERM_STATES; i++) if (perm_dist[i] > max_p) max_p = perm_dist[i];
    for (int i = 0; i < ORIENT_STATES; i++) if (orient_dist[i] > max_o) max_o = orient_dist[i];

    printf("=== Gate H2 Validation ===\n");
    printf("Permutation PDB: size = %d entries, max distance = %u, solved = %u\n",
           PERM_STATES, max_p, perm_dist[0]);
    printf("Orientation PDB: size = %d entries, max distance = %u, solved = %u\n",
           ORIENT_STATES, max_o, orient_dist[0]);

    /* 6. Export Binary Artifacts */
    FILE *fp = fopen("perm_pdb.bin", "wb");
    fwrite(perm_dist, 1, sizeof(perm_dist), fp);
    fclose(fp);

    fp = fopen("orient_pdb.bin", "wb");
    fwrite(orient_dist, 1, sizeof(orient_dist), fp);
    fclose(fp);

    fp = fopen("perm_trans.bin", "wb");
    fwrite(perm_trans, sizeof(uint16_t), MOVES * PERM_STATES, fp);
    fclose(fp);

    fp = fopen("orient_trans.bin", "wb");
    fwrite(orient_trans, sizeof(uint16_t), MOVES * ORIENT_STATES, fp);
    fclose(fp);

    printf("Generated: perm_pdb.bin (5040 B), orient_pdb.bin (729 B)\n");
    return 0;
}
