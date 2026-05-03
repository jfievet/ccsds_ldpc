#ifndef QC_ENCODER_H
#define QC_ENCODER_H

#include <stdint.h>

typedef struct {
	int selection;
	const char *name;
	const char *g_matrix_path;
	int info_length;
	int transmitted_length;
	int full_length;
	int row_blocks;
	int col_blocks;
	int block_size;
	int block_words;
	int transmitted_parity_length;
	const uint64_t *first_rows;
} qc_encoder_config;

const qc_encoder_config *qc_encoder_get_config(int selection);

void qc_encoder_compute_transmitted_parity(
	const qc_encoder_config *config,
	const uint8_t *message_bits,
	uint64_t *parity_blocks
);

void qc_encoder_build_transmitted_codeword(
	const qc_encoder_config *config,
	const uint8_t *message_bits,
	const uint64_t *parity_blocks,
	uint8_t *transmitted_codeword
);

void qc_encoder_encode(
	const qc_encoder_config *config,
	const uint8_t *message_bits,
	uint8_t *transmitted_codeword
);

#endif