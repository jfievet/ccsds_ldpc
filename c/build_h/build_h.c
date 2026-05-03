#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    uint32_t row;
    uint32_t col;
} Entry;

typedef struct {
    int rows;
    int cols;
    size_t nnz;
    size_t cap;
    Entry *data;
} SparseBin;

static void die(const char *msg) {
    fprintf(stderr, "Error: %s\n", msg);
    exit(EXIT_FAILURE);
}

static void *xmalloc(size_t size) {
    void *ptr = malloc(size);
    if (!ptr) {
        die("out of memory");
    }
    return ptr;
}

static void *xrealloc(void *ptr, size_t size) {
    void *next = realloc(ptr, size);
    if (!next) {
        die("out of memory");
    }
    return next;
}

static void sparse_init(SparseBin *mat, int rows, int cols, size_t initial_cap) {
    mat->rows = rows;
    mat->cols = cols;
    mat->nnz = 0;
    mat->cap = initial_cap ? initial_cap : 1024;
    mat->data = (Entry *)xmalloc(mat->cap * sizeof(Entry));
}

static void sparse_push(SparseBin *mat, uint32_t row, uint32_t col) {
    if (mat->nnz == mat->cap) {
        mat->cap *= 2;
        mat->data = (Entry *)xrealloc(mat->data, mat->cap * sizeof(Entry));
    }
    mat->data[mat->nnz].row = row;
    mat->data[mat->nnz].col = col;
    mat->nnz++;
}

static void sparse_free(SparseBin *mat) {
    free(mat->data);
    mat->data = NULL;
    mat->nnz = 0;
    mat->cap = 0;
}

static int entry_cmp_col_row(const void *a, const void *b) {
    const Entry *ea = (const Entry *)a;
    const Entry *eb = (const Entry *)b;

    if (ea->col < eb->col) return -1;
    if (ea->col > eb->col) return 1;
    if (ea->row < eb->row) return -1;
    if (ea->row > eb->row) return 1;
    return 0;
}

static void toggle_col(uint32_t *cols, int *count, uint32_t col) {
    int i;
    for (i = 0; i < *count; i++) {
        if (cols[i] == col) {
            cols[i] = cols[*count - 1];
            (*count)--;
            return;
        }
    }
    cols[*count] = col;
    (*count)++;
}

static void add_identity_block(SparseBin *H, uint32_t global_row, uint32_t block_col_offset, uint32_t local_row) {
    sparse_push(H, global_row, block_col_offset + local_row);
}

static void add_xor_perm_block(
    SparseBin *H,
    uint32_t global_row,
    uint32_t block_col_offset,
    uint32_t local_row,
    int include_identity,
    const int *perm_indices,
    int perm_count,
    uint32_t **Pi
) {
    uint32_t cols[4];
    int count = 0;
    int i;

    if (include_identity) {
        toggle_col(cols, &count, local_row);
    }

    for (i = 0; i < perm_count; i++) {
        toggle_col(cols, &count, Pi[perm_indices[i]][local_row]);
    }

    for (i = 0; i < count; i++) {
        sparse_push(H, global_row, block_col_offset + cols[i]);
    }
}

static void make_rate_tag(const char *rate, char out[4]) {
    out[0] = rate[0];
    out[1] = '_';
    out[2] = rate[2];
    out[3] = '\0';
}

static int tuple_column_for_M(int M) {
    static const int supported_M[] = {128, 256, 512, 1024, 2048, 4096, 8192};
    int i;
    for (i = 0; i < 7; i++) {
        if (supported_M[i] == M) {
            return i;
        }
    }
    return -1;
}

static int determine_M(const char *rate, int block_length) {
    if (strcmp(rate, "1/2") == 0) {
        if (block_length == 1024) return 512;
        if (block_length == 4096) return 2048;
        if (block_length == 16384) return 8192;
        die("unsupported block length for rate 1/2");
    } else if (strcmp(rate, "2/3") == 0) {
        if (block_length == 1024) return 256;
        if (block_length == 4096) return 1024;
        if (block_length == 16384) return 4096;
        die("unsupported block length for rate 2/3");
    } else if (strcmp(rate, "4/5") == 0) {
        if (block_length == 1024) return 128;
        if (block_length == 4096) return 512;
        if (block_length == 16384) return 2048;
        die("unsupported block length for rate 4/5");
    }

    die("unsupported rate");
    return 0;
}

static void set_configuration_from_selection(int selection, char rate[4], int *block_length) {
    switch (selection) {
        case 1: strcpy(rate, "1/2"); *block_length = 1024; break;
        case 2: strcpy(rate, "1/2"); *block_length = 4096; break;
        case 3: strcpy(rate, "1/2"); *block_length = 16384; break;
        case 4: strcpy(rate, "2/3"); *block_length = 1024; break;
        case 5: strcpy(rate, "2/3"); *block_length = 4096; break;
        case 6: strcpy(rate, "2/3"); *block_length = 16384; break;
        case 7: strcpy(rate, "4/5"); *block_length = 1024; break;
        case 8: strcpy(rate, "4/5"); *block_length = 4096; break;
        case 9: strcpy(rate, "4/5"); *block_length = 16384; break;
        default: die("invalid selection; choose an integer from 1 to 9");
    }
}

static void choose_configuration(char rate[4], int *block_length) {
    int selection;

    printf("Select CCSDS LDPC configuration:\n");
    printf("  1. rate 1/2, block length 1024\n");
    printf("  2. rate 1/2, block length 4096\n");
    printf("  3. rate 1/2, block length 16384\n");
    printf("  4. rate 2/3, block length 1024\n");
    printf("  5. rate 2/3, block length 4096\n");
    printf("  6. rate 2/3, block length 16384\n");
    printf("  7. rate 4/5, block length 1024\n");
    printf("  8. rate 4/5, block length 4096\n");
    printf("  9. rate 4/5, block length 16384\n");
    printf("Enter a number from 1 to 9: ");

    if (scanf("%d", &selection) != 1) {
        die("invalid selection input");
    }

    set_configuration_from_selection(selection, rate, block_length);
}

static void save_octave_sparse_mat(const char *filename, SparseBin *H) {
    FILE *fp;
    time_t now;
    struct tm *tm_utc;
    char timestamp[64];

    qsort(H->data, H->nnz, sizeof(H->data[0]), entry_cmp_col_row);

    fp = fopen(filename, "w");
    if (!fp) {
        die("could not open output .mat file for writing");
    }

    now = time(NULL);
    tm_utc = gmtime(&now);
    if (tm_utc && strftime(timestamp, sizeof(timestamp), "%a %b %d %H:%M:%S %Y UTC", tm_utc) > 0) {
        fprintf(fp, "# Created by build_h.c, %s\n", timestamp);
    } else {
        fprintf(fp, "# Created by build_h.c\n");
    }

    fprintf(fp, "# name: H\n");
    fprintf(fp, "# type: sparse matrix\n");
    fprintf(fp, "# nnz: %zu\n", H->nnz);
    fprintf(fp, "# rows: %d\n", H->rows);
    fprintf(fp, "# columns: %d\n", H->cols);

    for (size_t i = 0; i < H->nnz; i++) {
        fprintf(fp, "%u %u 1\n", H->data[i].row + 1, H->data[i].col + 1);
    }

    fclose(fp);
}

static void build_permutations(int M, int tuple_column, uint32_t **Pi) {
    static const int theta[26] = {
        3, 0, 1, 2, 2, 3, 0, 1, 0, 1, 2, 0, 2, 3, 0, 1, 2, 0, 1, 2, 0, 1, 2, 1, 2, 3
    };

    static const int phi0[26][7] = {
        { 1, 59, 16, 160, 108, 226, 1148 },
        { 22, 18, 103, 241, 126, 618, 2032 },
        { 0, 52, 105, 185, 238, 404, 249 },
        { 26, 23, 0, 251, 481, 32, 1807 },
        { 0, 11, 50, 209, 96, 912, 485 },
        { 10, 7, 29, 103, 28, 950, 1044 },
        { 5, 22, 115, 90, 59, 534, 717 },
        { 18, 25, 30, 184, 225, 63, 873 },
        { 3, 27, 92, 248, 323, 971, 364 },
        { 22, 30, 78, 12, 28, 304, 1926 },
        { 3, 43, 70, 111, 386, 409, 1241 },
        { 8, 14, 66, 66, 305, 708, 1769 },
        { 25, 46, 39, 173, 34, 719, 532 },
        { 25, 62, 84, 42, 510, 176, 768 },
        { 2, 44, 79, 157, 147, 743, 1138 },
        { 27, 12, 70, 174, 199, 759, 965 },
        { 7, 38, 29, 104, 347, 674, 141 },
        { 7, 47, 32, 144, 391, 958, 1527 },
        { 15, 1, 45, 43, 165, 984, 505 },
        { 10, 52, 113, 181, 414, 11, 1312 },
        { 4, 61, 86, 250, 97, 413, 1840 },
        { 19, 10, 1, 202, 158, 925, 709 },
        { 7, 55, 42, 68, 86, 687, 1427 },
        { 9, 7, 118, 177, 168, 752, 989 },
        { 26, 12, 33, 170, 506, 867, 1925 },
        { 17, 2, 126, 89, 489, 323, 270 }
    };

    static const int phi1[26][7] = {
        { 0, 0, 0, 0, 0, 0, 0 },
        { 27, 32, 53, 182, 375, 767, 1822 },
        { 30, 21, 74, 249, 436, 227, 203 },
        { 28, 36, 45, 65, 350, 247, 882 },
        { 7, 30, 47, 70, 260, 284, 1989 },
        { 1, 29, 0, 141, 84, 370, 957 },
        { 8, 44, 59, 237, 318, 482, 1705 },
        { 20, 29, 102, 77, 382, 273, 1083 },
        { 26, 39, 25, 55, 169, 886, 1072 },
        { 24, 14, 3, 12, 213, 634, 354 },
        { 4, 22, 88, 227, 67, 762, 1942 },
        { 12, 15, 65, 42, 313, 184, 446 },
        { 23, 48, 62, 52, 242, 696, 1456 },
        { 15, 55, 68, 243, 188, 413, 1940 },
        { 15, 39, 91, 179, 1, 854, 1660 },
        { 22, 11, 70, 250, 306, 544, 1661 },
        { 31, 1, 115, 247, 397, 864, 587 },
        { 3, 50, 31, 164, 80, 82, 708 },
        { 29, 40, 121, 17, 33, 1009, 1466 },
        { 21, 62, 45, 31, 7, 437, 433 },
        { 2, 27, 56, 149, 447, 36, 1345 },
        { 5, 38, 54, 105, 336, 562, 867 },
        { 11, 40, 108, 183, 424, 816, 1551 },
        { 26, 15, 14, 153, 134, 452, 2041 },
        { 9, 11, 30, 177, 152, 290, 1383 },
        { 17, 18, 116, 19, 492, 778, 1790 }
    };

    static const int phi2[26][7] = {
        { 0, 0, 0, 0, 0, 0, 0 },
        { 12, 46, 8, 35, 219, 254, 318 },
        { 30, 45, 119, 167, 16, 790, 494 },
        { 18, 27, 89, 214, 263, 642, 1467 },
        { 10, 48, 31, 84, 415, 248, 757 },
        { 16, 37, 122, 206, 403, 899, 1085 },
        { 13, 41, 1, 122, 184, 328, 1630 },
        { 9, 13, 69, 67, 279, 518, 64 },
        { 7, 9, 92, 147, 198, 477, 689 },
        { 15, 49, 47, 54, 307, 404, 1300 },
        { 16, 36, 11, 23, 432, 698, 148 },
        { 18, 10, 31, 93, 240, 160, 777 },
        { 4, 11, 19, 20, 454, 497, 1431 },
        { 23, 18, 66, 197, 294, 100, 659 },
        { 5, 54, 49, 46, 479, 518, 352 },
        { 3, 40, 81, 162, 289, 92, 1177 },
        { 29, 27, 96, 101, 373, 464, 836 },
        { 11, 35, 38, 76, 104, 592, 1572 },
        { 4, 25, 83, 78, 141, 198, 348 },
        { 8, 46, 42, 253, 270, 856, 1040 },
        { 2, 24, 58, 124, 439, 235, 779 },
        { 11, 33, 24, 143, 333, 134, 476 },
        { 11, 18, 25, 63, 399, 542, 191 },
        { 3, 37, 92, 41, 14, 545, 1393 },
        { 15, 35, 38, 214, 277, 777, 1752 },
        { 13, 21, 120, 70, 412, 483, 1627 }
    };

    static const int phi3[26][7] = {
        { 0, 0, 0, 0, 0, 0, 0 },
        { 13, 44, 35, 162, 312, 285, 1189 },
        { 19, 51, 97, 7, 503, 554, 458 },
        { 14, 12, 112, 31, 388, 809, 460 },
        { 15, 15, 64, 164, 48, 185, 1039 },
        { 20, 12, 93, 11, 7, 49, 1000 },
        { 17, 4, 99, 237, 185, 101, 1265 },
        { 4, 7, 94, 125, 328, 82, 1223 },
        { 4, 2, 103, 133, 254, 898, 874 },
        { 11, 30, 91, 99, 202, 627, 1292 },
        { 17, 53, 3, 105, 285, 154, 1491 },
        { 20, 23, 6, 17, 11, 65, 631 },
        { 8, 29, 39, 97, 168, 81, 464 },
        { 22, 37, 113, 91, 127, 823, 461 },
        { 19, 42, 92, 211, 8, 50, 844 },
        { 15, 48, 119, 128, 437, 413, 392 },
        { 5, 4, 74, 82, 475, 462, 922 },
        { 21, 10, 73, 115, 85, 175, 256 },
        { 17, 18, 116, 248, 419, 715, 1986 },
        { 9, 56, 31, 62, 459, 537, 19 },
        { 20, 9, 127, 26, 468, 722, 266 },
        { 18, 11, 98, 140, 209, 37, 471 },
        { 31, 23, 23, 121, 311, 488, 1166 },
        { 13, 8, 38, 12, 211, 179, 1300 },
        { 2, 7, 18, 41, 510, 430, 1033 },
        { 18, 24, 62, 249, 320, 264, 1606 }
    };

    int quarter_M;
    int k;
    int i;

    if ((M % 4) != 0) {
        die("Section 7.4 requires M divisible by 4");
    }

    quarter_M = M / 4;

    for (k = 0; k < 26; k++) {
        const int phi_values[4] = {
            phi0[k][tuple_column],
            phi1[k][tuple_column],
            phi2[k][tuple_column],
            phi3[k][tuple_column]
        };

        for (i = 0; i < M; i++) {
            int j = (4 * i) / M;
            int pi_value =
                quarter_M * ((theta[k] + j) % 4) +
                ((phi_values[j] + i) % quarter_M);
            Pi[k][i] = (uint32_t)pi_value;
        }
    }
}

static SparseBin build_H(const char *rate, int M, uint32_t **Pi) {
    SparseBin H;
    uint32_t r;

    static const int S1[]  = {0};
    static const int S2[]  = {1, 2, 3};
    static const int S3[]  = {4, 5};
    static const int S4[]  = {6, 7};
    static const int S5[]  = {8, 9, 10};
    static const int S6[]  = {11, 12, 13};
    static const int S7[]  = {14, 15, 16};
    static const int S8[]  = {17, 18, 19};
    static const int S9[]  = {20, 21, 22};
    static const int S10[] = {23, 24, 25};

    if (strcmp(rate, "1/2") == 0) {
        sparse_init(&H, 3 * M, 5 * M, (size_t)(12 * M));

        for (r = 0; r < (uint32_t)M; r++) {
            add_identity_block(&H, r, 2u * M, r);
            add_xor_perm_block(&H, r, 4u * M, r, 1, S1, 1, Pi);
        }

        for (r = 0; r < (uint32_t)M; r++) {
            uint32_t row = (uint32_t)M + r;
            add_identity_block(&H, row, 0u * M, r);
            add_identity_block(&H, row, 1u * M, r);
            add_identity_block(&H, row, 3u * M, r);
            add_xor_perm_block(&H, row, 4u * M, r, 0, S2, 3, Pi);
        }

        for (r = 0; r < (uint32_t)M; r++) {
            uint32_t row = 2u * M + r;
            add_identity_block(&H, row, 0u * M, r);
            add_xor_perm_block(&H, row, 1u * M, r, 0, S3, 2, Pi);
            add_xor_perm_block(&H, row, 3u * M, r, 0, S4, 2, Pi);
            add_identity_block(&H, row, 4u * M, r);
        }

        return H;
    }

    if (strcmp(rate, "2/3") == 0) {
        sparse_init(&H, 3 * M, 7 * M, (size_t)(18 * M));

        for (r = 0; r < (uint32_t)M; r++) {
            add_identity_block(&H, r, 4u * M, r);
            add_xor_perm_block(&H, r, 6u * M, r, 1, S1, 1, Pi);
        }

        for (r = 0; r < (uint32_t)M; r++) {
            uint32_t row = (uint32_t)M + r;
            add_xor_perm_block(&H, row, 0u * M, r, 0, S5, 3, Pi);
            add_identity_block(&H, row, 1u * M, r);
            add_identity_block(&H, row, 2u * M, r);
            add_identity_block(&H, row, 3u * M, r);
            add_identity_block(&H, row, 5u * M, r);
            add_xor_perm_block(&H, row, 6u * M, r, 0, S2, 3, Pi);
        }

        for (r = 0; r < (uint32_t)M; r++) {
            uint32_t row = 2u * M + r;
            add_identity_block(&H, row, 0u * M, r);
            add_xor_perm_block(&H, row, 1u * M, r, 0, S6, 3, Pi);
            add_identity_block(&H, row, 2u * M, r);
            add_xor_perm_block(&H, row, 3u * M, r, 0, S3, 2, Pi);
            add_xor_perm_block(&H, row, 5u * M, r, 0, S4, 2, Pi);
            add_identity_block(&H, row, 6u * M, r);
        }

        return H;
    }

    if (strcmp(rate, "4/5") == 0) {
        sparse_init(&H, 3 * M, 11 * M, (size_t)(36 * M));

        for (r = 0; r < (uint32_t)M; r++) {
            add_identity_block(&H, r, 8u * M, r);
            add_xor_perm_block(&H, r, 10u * M, r, 1, S1, 1, Pi);
        }

        for (r = 0; r < (uint32_t)M; r++) {
            uint32_t row = (uint32_t)M + r;
            add_xor_perm_block(&H, row, 0u * M, r, 0, S9, 3, Pi);
            add_xor_perm_block(&H, row, 1u * M, r, 0, S7, 3, Pi);
            add_xor_perm_block(&H, row, 2u * M, r, 0, S5, 3, Pi);
            add_xor_perm_block(&H, row, 3u * M, r, 0, S6, 3, Pi);
            add_identity_block(&H, row, 4u * M, r);
            add_identity_block(&H, row, 5u * M, r);
            add_identity_block(&H, row, 6u * M, r);
            add_identity_block(&H, row, 7u * M, r);
            add_identity_block(&H, row, 9u * M, r);
            add_xor_perm_block(&H, row, 10u * M, r, 0, S2, 3, Pi);
        }

        for (r = 0; r < (uint32_t)M; r++) {
            uint32_t row = 2u * M + r;
            add_xor_perm_block(&H, row, 0u * M, r, 0, S10, 3, Pi);
            add_xor_perm_block(&H, row, 1u * M, r, 0, S8, 3, Pi);
            add_identity_block(&H, row, 4u * M, r);
            add_identity_block(&H, row, 5u * M, r);
            add_identity_block(&H, row, 6u * M, r);
            add_xor_perm_block(&H, row, 7u * M, r, 0, S3, 2, Pi);
            add_xor_perm_block(&H, row, 9u * M, r, 0, S4, 2, Pi);
            add_identity_block(&H, row, 10u * M, r);
        }

        return H;
    }

    die("unsupported rate");
    sparse_init(&H, 0, 0, 0);
    return H;
}

int main(int argc, char **argv) {
    char rate[4];
    char rate_tag[4];
    char mat_filename[64];
    int block_length;
    int M;
    int tuple_column;
    uint32_t **Pi;
    SparseBin H;

    if (argc >= 2) {
        char *endptr = NULL;
        long selection = strtol(argv[1], &endptr, 10);

        if (argv[1][0] == '\0' || *endptr != '\0') {
            die("argument must be an integer from 1 to 9");
        }

        set_configuration_from_selection((int)selection, rate, &block_length);
    } else {
        choose_configuration(rate, &block_length);
    }

    M = determine_M(rate, block_length);
    tuple_column = tuple_column_for_M(M);
    if (tuple_column < 0) {
        die("unsupported submatrix size M");
    }

    Pi = (uint32_t **)xmalloc(26 * sizeof(*Pi));
    for (int k = 0; k < 26; k++) {
        Pi[k] = (uint32_t *)xmalloc((size_t)M * sizeof(**Pi));
    }

    build_permutations(M, tuple_column, Pi);
    H = build_H(rate, M, Pi);

    printf("Built CCSDS LDPC H for rate %s, block length %d.\n", rate, block_length);
    printf("H size: %d x %d\n", H.rows, H.cols);
    printf("Submatrix size M: %d\n", M);
    printf("Last %d columns are the punctured columns defined by Section 7.4.2.5.\n", M);

    make_rate_tag(rate, rate_tag);
    snprintf(mat_filename, sizeof(mat_filename), "H_%s_%d.mat", rate_tag, block_length);

    save_octave_sparse_mat(mat_filename, &H);
    printf("Saved H matrix to %s\n", mat_filename);

    sparse_free(&H);
    for (int k = 0; k < 26; k++) {
        free(Pi[k]);
    }
    free(Pi);

    return 0;
}