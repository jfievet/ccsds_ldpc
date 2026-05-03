#include "qc_encoder.h"

#include <string.h>

static void block_copy(uint64_t dst[QC_BLOCK_WORDS], const uint64_t src[QC_BLOCK_WORDS]) {
	dst[0] = src[0];
	dst[1] = src[1];
}

static void block_xor(uint64_t dst[QC_BLOCK_WORDS], const uint64_t src[QC_BLOCK_WORDS]) {
	dst[0] ^= src[0];
	dst[1] ^= src[1];
}

static void block_rotate_left_one(uint64_t words[QC_BLOCK_WORDS]) {
	uint64_t low = words[0];
	uint64_t high = words[1];
	words[0] = (low << 1) | (high >> 63);
	words[1] = (high << 1) | (low >> 63);
}

void qc_encoder_compute_transmitted_parity(
	const uint8_t message_bits[QC_INFO_LENGTH],
	uint64_t parity_blocks[QC_COL_BLOCKS][QC_BLOCK_WORDS]
) {
	int row_block;
	int col_block;

	memset(parity_blocks, 0, (size_t)QC_COL_BLOCKS * QC_BLOCK_WORDS * sizeof(uint64_t));

	for (row_block = 0; row_block < QC_ROW_BLOCKS; row_block++) {
		uint64_t shift_registers[QC_COL_BLOCKS][QC_BLOCK_WORDS];
		int local_bit;

		for (col_block = 0; col_block < QC_COL_BLOCKS; col_block++) {
			block_copy(shift_registers[col_block], qc_circulant_first_rows[row_block][col_block]);
		}

		for (local_bit = 0; local_bit < QC_BLOCK_SIZE; local_bit++) {
			if (message_bits[row_block * QC_BLOCK_SIZE + local_bit] != 0) {
				for (col_block = 0; col_block < QC_COL_BLOCKS; col_block++) {
					block_xor(parity_blocks[col_block], shift_registers[col_block]);
				}
			}
			for (col_block = 0; col_block < QC_COL_BLOCKS; col_block++) {
				block_rotate_left_one(shift_registers[col_block]);
			}
		}
	}
}

void qc_encoder_build_transmitted_codeword(
	const uint8_t message_bits[QC_INFO_LENGTH],
	const uint64_t parity_blocks[QC_COL_BLOCKS][QC_BLOCK_WORDS],
	uint8_t transmitted_codeword[QC_TRANSMITTED_CODEWORD_LENGTH]
) {
	int bit_index;

	for (bit_index = 0; bit_index < QC_INFO_LENGTH; bit_index++) {
		transmitted_codeword[bit_index] = message_bits[bit_index] ? 1u : 0u;
	}

	for (bit_index = 0; bit_index < QC_TRANSMITTED_PARITY_LENGTH; bit_index++) {
		int block_index = bit_index / QC_BLOCK_SIZE;
		int local_index = bit_index % QC_BLOCK_SIZE;
		int word_index = local_index / 64;
		int bit_in_word = local_index % 64;
		transmitted_codeword[QC_INFO_LENGTH + bit_index] =
			(uint8_t)((parity_blocks[block_index][word_index] >> bit_in_word) & UINT64_C(1));
	}
}

void qc_encoder_encode(
	const uint8_t message_bits[QC_INFO_LENGTH],
	uint8_t transmitted_codeword[QC_TRANSMITTED_CODEWORD_LENGTH]
) {
	uint64_t parity_blocks[QC_COL_BLOCKS][QC_BLOCK_WORDS];
	qc_encoder_compute_transmitted_parity(message_bits, parity_blocks);
	qc_encoder_build_transmitted_codeword(message_bits, parity_blocks, transmitted_codeword);
}