#include "ldpc_decoder.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct {
    int row;
    int col;
} edge_t;

static void *checked_malloc(size_t size) {
    void *p = malloc(size);
    if (!p) {
        fprintf(stderr, "malloc failed\n");
        exit(EXIT_FAILURE);
    }
    return p;
}

static int edge_compare(const void *a, const void *b) {
    const edge_t *ea = (const edge_t *)a;
    const edge_t *eb = (const edge_t *)b;
    if (ea->row < eb->row) return -1;
    if (ea->row > eb->row) return 1;
    if (ea->col < eb->col) return -1;
    if (ea->col > eb->col) return 1;
    return 0;
}

int ldpc_load_mat(const char *filename, ldpc_matrix_t *H) {
    FILE *fp;
    char line[256];
    int rows = 0, cols = 0, nnz = 0;
    edge_t *edges = NULL;

    fp = fopen(filename, "r");
    if (!fp) {
        fprintf(stderr, "cannot open %s\n", filename);
        return -1;
    }

    while (fgets(line, sizeof(line), fp)) {
        if (sscanf(line, "# rows: %d", &rows) == 1) continue;
        if (sscanf(line, "# columns: %d", &cols) == 1) continue;
        if (sscanf(line, "# nnz: %d", &nnz) == 1) continue;
        if (line[0] >= '0' && line[0] <= '9') break;
    }

    if (rows <= 0 || cols <= 0 || nnz <= 0) {
        fprintf(stderr, "invalid .mat header\n");
        fclose(fp);
        return -1;
    }

    edges = (edge_t *)checked_malloc((size_t)nnz * sizeof(edge_t));

    int r, c, v;
    if (sscanf(line, "%d %d %d", &r, &c, &v) != 3) {
        free(edges);
        fclose(fp);
        return -1;
    }
    edges[0].row = r - 1;
    edges[0].col = c - 1;

    for (int i = 1; i < nnz; i++) {
        if (!fgets(line, sizeof(line), fp)) {
            fprintf(stderr, "unexpected EOF\n");
            free(edges);
            fclose(fp);
            return -1;
        }
        if (sscanf(line, "%d %d %d", &r, &c, &v) != 3) {
            free(edges);
            fclose(fp);
            return -1;
        }
        edges[i].row = r - 1;
        edges[i].col = c - 1;
    }
    fclose(fp);

    qsort(edges, (size_t)nnz, sizeof(edge_t), edge_compare);

    H->M = rows;
    H->N = cols;
    H->E = nnz;
    H->row_ptr = (int *)checked_malloc((size_t)(rows + 1) * sizeof(int));
    H->col_idx = (int *)checked_malloc((size_t)nnz * sizeof(int));

    int edge_index = 0;
    H->row_ptr[0] = 0;
    for (int row = 0; row < rows; row++) {
        while (edge_index < nnz && edges[edge_index].row == row) edge_index++;
        H->row_ptr[row + 1] = edge_index;
    }
    for (int i = 0; i < nnz; i++) H->col_idx[i] = edges[i].col;

    free(edges);
    return 0;
}

void ldpc_free(ldpc_matrix_t *H) {
    free(H->row_ptr);
    free(H->col_idx);
    H->row_ptr = NULL;
    H->col_idx = NULL;
    H->M = 0;
    H->N = 0;
    H->E = 0;
}

static int ldpc_check_syndrome(const ldpc_matrix_t *H, const uint8_t *bits) {
    for (int m = 0; m < H->M; m++) {
        int parity = 0;
        for (int e = H->row_ptr[m]; e < H->row_ptr[m + 1]; e++) {
            int vn = H->col_idx[e];
            parity ^= bits[vn];
        }
        if (parity) return 0;
    }
    return 1;
}

int ldpc_decode_layered_oms(
    const ldpc_matrix_t *H,
    const float *llr_in,
    uint8_t *bits_out,
    int max_iterations,
    float offset
) {
    float *llr = (float *)checked_malloc((size_t)H->N * sizeof(float));
    float *cn_msg = (float *)checked_malloc((size_t)H->E * sizeof(float));

    memcpy(llr, llr_in, (size_t)H->N * sizeof(float));
    memset(cn_msg, 0, (size_t)H->E * sizeof(float));

    for (int iter = 0; iter < max_iterations; iter++) {
        for (int m = 0; m < H->M; m++) {
            int start = H->row_ptr[m];
            int end = H->row_ptr[m + 1];

            float min1 = 1e30f;
            float min2 = 1e30f;
            int min1_edge = -1;
            int sign_product = 0;

            for (int e = start; e < end; e++) {
                int vn = H->col_idx[e];
                float v2c = llr[vn] - cn_msg[e];
                float av = fabsf(v2c);
                if (av < min1) {
                    min2 = min1;
                    min1 = av;
                    min1_edge = e;
                } else if (av < min2) {
                    min2 = av;
                }
                if (v2c < 0.0f) sign_product ^= 1;
            }

            min1 -= offset;
            min2 -= offset;
            if (min1 < 0.0f) min1 = 0.0f;
            if (min2 < 0.0f) min2 = 0.0f;

            for (int e = start; e < end; e++) {
                int vn = H->col_idx[e];
                float old_msg = cn_msg[e];
                float v2c = llr[vn] - old_msg;

                float magnitude = (e == min1_edge) ? min2 : min1;
                int sign = sign_product;
                if (v2c < 0.0f) sign ^= 1;

                float new_msg = sign ? -magnitude : magnitude;
                cn_msg[e] = new_msg;
                llr[vn] = v2c + new_msg;
            }
        }

        for (int n = 0; n < H->N; n++) bits_out[n] = (llr[n] < 0.0f) ? 1u : 0u;
        if (ldpc_check_syndrome(H, bits_out)) {
            free(llr);
            free(cn_msg);
            return iter + 1;
        }
    }

    free(llr);
    free(cn_msg);
    return max_iterations;
}

static int clamp_q(int x, int qmax) {
    if (x > qmax) return qmax;
    if (x < -qmax) return -qmax;
    return x;
}

static int quantize_to_q(float x, int qmax, float clip) {
    if (!(clip > 0.0f)) return 0;
    if (x > clip) x = clip;
    if (x < -clip) x = -clip;
    float scaled = x * ((float)qmax / clip);
    int qi = (int)lrintf(scaled);
    return clamp_q(qi, qmax);
}

int ldpc_decode_layered_oms_quant(
    const ldpc_matrix_t *H,
    const float *llr_in,
    uint8_t *bits_out,
    int max_iterations,
    float offset,
    int llr_width_bits,
    float llr_clip,
    int accumulate_vn_llr
) {
    if (llr_width_bits == 0) {
        return ldpc_decode_layered_oms(H, llr_in, bits_out, max_iterations, offset);
    }
    if (llr_width_bits < 3 || llr_width_bits > 6) {
        return ldpc_decode_layered_oms(H, llr_in, bits_out, max_iterations, offset);
    }
    if (!(llr_clip > 0.0f)) return -1;

    /* Base quantization (message units). All internal integer values share this LSB. */
    int qmax_msg = (1 << (llr_width_bits - 1)) - 1;
    float scale_msg = (float)qmax_msg / llr_clip;
    int offset_q = (int)ceilf(offset * scale_msg);
    if (offset_q < 0) offset_q = 0;
    if (offset > 0.0f && offset_q == 0) offset_q = 1;
    if (offset_q > qmax_msg) offset_q = qmax_msg;

    /* Use guard bits for VN a-posteriori LLRs.
       When accumulate_vn_llr=1, widen further to reduce saturation risk. */
    int guard_bits = accumulate_vn_llr ? 8 : 3;
    int32_t qmax_acc = (int32_t)qmax_msg << guard_bits;
    if (qmax_acc < qmax_msg) qmax_acc = qmax_msg; /* overflow safety */

    int32_t *llr = (int32_t *)checked_malloc((size_t)H->N * sizeof(int32_t));
    int16_t *cn_msg = (int16_t *)checked_malloc((size_t)H->E * sizeof(int16_t));

    for (int i = 0; i < H->N; i++) llr[i] = (int32_t)quantize_to_q(llr_in[i], qmax_msg, llr_clip);
    memset(cn_msg, 0, (size_t)H->E * sizeof(int16_t));

    for (int iter = 0; iter < max_iterations; iter++) {
        for (int m = 0; m < H->M; m++) {
            int start = H->row_ptr[m];
            int end = H->row_ptr[m + 1];

            int min1 = 0x7fffffff;
            int min2 = 0x7fffffff;
            int min1_edge = -1;
            int sign_product = 0;

            for (int e = start; e < end; e++) {
                int vn = H->col_idx[e];
                int v2c = (int)llr[vn] - (int)cn_msg[e];
                int av = (v2c < 0) ? -v2c : v2c;
                if (av < min1) {
                    min2 = min1;
                    min1 = av;
                    min1_edge = e;
                } else if (av < min2) {
                    min2 = av;
                }
                if (v2c < 0) sign_product ^= 1;
            }

            min1 -= offset_q;
            min2 -= offset_q;
            if (min1 < 0) min1 = 0;
            if (min2 < 0) min2 = 0;
            if (min1 > qmax_msg) min1 = qmax_msg;
            if (min2 > qmax_msg) min2 = qmax_msg;

            for (int e = start; e < end; e++) {
                int vn = H->col_idx[e];
                int old_msg = (int)cn_msg[e];
                int v2c = (int)llr[vn] - old_msg;

                int magnitude = (e == min1_edge) ? min2 : min1;

                int sign = sign_product;
                if (v2c < 0) sign ^= 1;

                int new_msg = sign ? -magnitude : magnitude;
                cn_msg[e] = (int16_t)clamp_q(new_msg, qmax_msg);

                int new_llr = v2c + new_msg;
                llr[vn] = (int32_t)clamp_q(new_llr, qmax_acc);
            }
        }

        for (int n = 0; n < H->N; n++) bits_out[n] = (llr[n] < 0) ? 1u : 0u;
        if (ldpc_check_syndrome(H, bits_out)) {
            free(llr);
            free(cn_msg);
            return iter + 1;
        }
    }

    free(llr);
    free(cn_msg);
    return max_iterations;
}
