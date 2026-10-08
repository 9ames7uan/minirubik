#include <stdio.h>
#include <stdint.h>

void dump_bytes(const char *bin_fn, const char *label, FILE *out) {
    FILE *in = fopen(bin_fn, "rb");
    if (!in) { perror(bin_fn); return; }
    fprintf(out, "%s:\n", label);
    uint8_t b;
    int col = 0;
    while (fread(&b, 1, 1, in) == 1) {
        if (col == 0) fprintf(out, "    .byte %u", b);
        else fprintf(out, ", %u", b);
        col++;
        if (col == 16) { fprintf(out, "\n"); col = 0; }
    }
    if (col != 0) fprintf(out, "\n");
    fclose(in);
}

void dump_halfs(const char *bin_fn, const char *label, FILE *out) {
    FILE *in = fopen(bin_fn, "rb");
    if (!in) { perror(bin_fn); return; }
    fprintf(out, "%s:\n", label);
    uint16_t h;
    int col = 0;
    while (fread(&h, 2, 1, in) == 1) {
        if (col == 0) fprintf(out, "    .half %u", h);
        else fprintf(out, ", %u", h);
        col++;
        if (col == 8) { fprintf(out, "\n"); col = 0; }
    }
    if (col != 0) fprintf(out, "\n");
    fclose(in);
}

int main(void) {
    FILE *out = fopen("tables.s", "w");
    if (!out) return 1;
    dump_bytes("perm_pdb.bin", "perm_pdb", out);
    dump_bytes("orient_pdb.bin", "orient_pdb", out);
    dump_halfs("perm_trans.bin", "perm_trans", out);
    dump_halfs("orient_trans.bin", "orient_trans", out);
    fclose(out);
    printf("Successfully generated tables.s\n");
    return 0;
}
