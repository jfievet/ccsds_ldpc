#ifndef LDPC_DECODER_H
#define LDPC_DECODER_H

#include <stdint.h>

typedef struct {
    int M;
    int N;
    int E;

    int *row_ptr;
    int *col_idx;
} ldpc_matrix_t;

int ldpc_load_mat(const char *filename, ldpc_matrix_t *H);
void ldpc_free(ldpc_matrix_t *H);

/* Floating-point layered Offset-Min-Sum (original implementation). */
int ldpc_decode_layered_oms(
    const ldpc_matrix_t *H,
    const float *llr_in,
    uint8_t *bits_out,
    int max_iterations,
    float offset
);

/* Quantized layered Offset-Min-Sum.
   - llr_width_bits: 0 for float passthrough (falls back to float decoder), else 3/4/5/6.
   - llr_clip: absolute clip value that maps to max magnitude code.
   Internal LLR state and CN messages are quantized and saturating. */
int ldpc_decode_layered_oms_quant(
    const ldpc_matrix_t *H,
    const float *llr_in,
    uint8_t *bits_out,
    int max_iterations,
    float offset,
    int llr_width_bits,
    float llr_clip,
    int accumulate_vn_llr
);

#endif /* LDPC_DECODER_H */
