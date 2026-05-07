#ifndef DECODER_H
#define DECODER_H

#include <stdint.h>

typedef struct
{
    int M;
    int N;
    int E;

    int *row_ptr;
    int *col_idx;

} ldpc_matrix_t;

int ldpc_load_mat(
    const char *filename,
    ldpc_matrix_t *H);

void ldpc_free(
    ldpc_matrix_t *H);

int ldpc_decode_layered_oms(
    const ldpc_matrix_t *H,
    const float *llr_in,
    uint8_t *bits_out,
    int max_iterations,
    float offset);

#endif