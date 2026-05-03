#ifndef QC_ENCODER_H
#define QC_ENCODER_H

#include <stdint.h>

#include "qc_encoder_constants.h"

#define QC_TRANSMITTED_CODEWORD_LENGTH (QC_INFO_LENGTH + QC_TRANSMITTED_PARITY_LENGTH)
#define QC_BLOCK_WORDS 2

void qc_encoder_compute_transmitted_parity(
	const uint8_t message_bits[QC_INFO_LENGTH],
	uint64_t parity_blocks[QC_COL_BLOCKS][QC_BLOCK_WORDS]
);

void qc_encoder_build_transmitted_codeword(
	const uint8_t message_bits[QC_INFO_LENGTH],
	const uint64_t parity_blocks[QC_COL_BLOCKS][QC_BLOCK_WORDS],
	uint8_t transmitted_codeword[QC_TRANSMITTED_CODEWORD_LENGTH]
);

void qc_encoder_encode(
	const uint8_t message_bits[QC_INFO_LENGTH],
	uint8_t transmitted_codeword[QC_TRANSMITTED_CODEWORD_LENGTH]
);

#endif