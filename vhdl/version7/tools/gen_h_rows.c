/*
 * gen_h_rows.c
 *
 * Generates a synthesizable VHDL package containing 3 ROMs holding
 * CCSDS LDPC H row adjacency for rate 1/2, block length 1024.
 *
 * Input:  ../../../c/build_h/H_1_2_1024.mat (Octave sparse text format)
 * Output: ../src/h_row_rom_pkg.vhd
 *
 * Each row is padded to 6 indices; indices are 1-based, 0 means unused.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

enum { M = 1536, N = 2560, ROW_MAX_DEG = 6, IDX_W = 12 };

static void die(const char *msg) {
    fprintf(stderr, "Error: %s\n", msg);
    exit(1);
}

static void *xmalloc(size_t n) {
    void *p = malloc(n);
    if (!p) die("out of memory");
    return p;
}

int main(void) {
    const char *in_path = "..\\..\\c\\build_h\\H_1_2_1024.mat";
    const char *out_path = "src\\h_row_rom_pkg.vhd";

    FILE *fp = fopen(in_path, "r");
    if (!fp) die("cannot open input H_1_2_1024.mat");

    int rows = 0, cols = 0;
    unsigned long long nnz = 0;

    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (sscanf(line, "# rows: %d", &rows) == 1) continue;
        if (sscanf(line, "# columns: %d", &cols) == 1) continue;
        if (line[0] == '#' && line[1] == ' ' && line[2] == 'n' && line[3] == 'n' && line[4] == 'z') {
            char *p = line;
            while (*p && *p != ':') p++;
            if (*p == ':') nnz = strtoull(p + 1, NULL, 10);
            continue;
        }
        if (line[0] >= '0' && line[0] <= '9') break;
    }

    if (rows != M || cols != N || nnz == 0) die("unexpected matrix size");

    /* Collect up to 6 entries per row. */
    uint16_t (*row_idx)[ROW_MAX_DEG] = xmalloc(sizeof(uint16_t) * M * ROW_MAX_DEG);
    int *row_count = xmalloc(sizeof(int) * M);

    for (int r = 0; r < M; r++) {
        row_count[r] = 0;
        for (int k = 0; k < ROW_MAX_DEG; k++) row_idx[r][k] = 0;
    }

    /* First data line already in 'line' if it starts with digit, else read loop */
    do {
        int r1 = 0, c1 = 0, v = 0;
        if (sscanf(line, "%d %d %d", &r1, &c1, &v) == 3) {
            if (v == 1) {
                int r = r1 - 1;
                int c = c1 - 1;
                if (r >= 0 && r < M && c >= 0 && c < N) {
                    int n = row_count[r];
                    if (n < ROW_MAX_DEG) {
                        row_idx[r][n] = (uint16_t)(c + 1); /* 1-based */
                        row_count[r] = n + 1;
                    }
                }
            }
        }
    } while (fgets(line, sizeof(line), fp));

    fclose(fp);

    FILE *out = fopen(out_path, "w");
    if (!out) die("cannot open output h_row_rom_pkg.vhd");

    fprintf(out, "library ieee;\n");
    fprintf(out, "use ieee.std_logic_1164.all;\n");
    fprintf(out, "use ieee.numeric_std.all;\n\n");
    fprintf(out, "package h_row_rom_pkg is\n");
    fprintf(out, "  constant C_M : integer := %d;\n", M);
    fprintf(out, "  constant C_IDX_W : integer := %d;\n", IDX_W);
    fprintf(out, "  subtype rom_word_t is std_logic_vector(2*C_IDX_W-1 downto 0);\n");
    fprintf(out, "  type rom_t is array(0 to C_M-1) of rom_word_t;\n\n");

    fprintf(out, "  constant H_ROM0 : rom_t := (\n");
    for (int r = 0; r < M; r++) {
        uint16_t a = row_idx[r][0];
        uint16_t b = row_idx[r][1];
        fprintf(out, "    %d => x\"%03X%03X\"%s\n", r, (unsigned)a, (unsigned)b, (r == M-1) ? "" : ",");
    }
    fprintf(out, "  );\n\n");

    fprintf(out, "  constant H_ROM1 : rom_t := (\n");
    for (int r = 0; r < M; r++) {
        uint16_t a = row_idx[r][2];
        uint16_t b = row_idx[r][3];
        fprintf(out, "    %d => x\"%03X%03X\"%s\n", r, (unsigned)a, (unsigned)b, (r == M-1) ? "" : ",");
    }
    fprintf(out, "  );\n\n");

    fprintf(out, "  constant H_ROM2 : rom_t := (\n");
    for (int r = 0; r < M; r++) {
        uint16_t a = row_idx[r][4];
        uint16_t b = row_idx[r][5];
        fprintf(out, "    %d => x\"%03X%03X\"%s\n", r, (unsigned)a, (unsigned)b, (r == M-1) ? "" : ",");
    }
    fprintf(out, "  );\n\n");

    fprintf(out, "end package;\n");

    fclose(out);
    free(row_idx);
    free(row_count);
    return 0;
}
