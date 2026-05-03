#include "qc_encoder.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "qc_encoder_constants.h"

static void block_copy(uint64_t *dst, const uint64_t *src, int word_count) {
	memcpy(dst, src, (size_t)word_count * sizeof(uint64_t));
}

static void block_xor(uint64_t *dst, const uint64_t *src, int word_count) {
	int word_index;
	for (word_index = 0; word_index < word_count; word_index++) {
		dst[word_index] ^= src[word_index];
	}
}

static uint64_t last_word_mask(int bit_count) {
	int used_bits = bit_count % 64;
	if (used_bits == 0) {
		return UINT64_MAX;
	}
	return (UINT64_C(1) << used_bits) - UINT64_C(1);
}

static void block_rotate_left_one(uint64_t *words, int word_count, int bit_count) {
	int last_word_index = (bit_count - 1) / 64;
	int last_bit_index = (bit_count - 1) % 64;
	uint64_t carry = (words[last_word_index] >> last_bit_index) & UINT64_C(1);
	int word_index;

	for (word_index = last_word_index; word_index > 0; word_index--) {
		words[word_index] = (words[word_index] << 1) | (words[word_index - 1] >> 63);
	}
	words[0] = (words[0] << 1) | carry;
	words[last_word_index] &= last_word_mask(bit_count);
	for (word_index = last_word_index + 1; word_index < word_count; word_index++) {
		words[word_index] = 0;
	}
}

static const uint64_t *config_first_row_ptr(
	const qc_encoder_config *config,
	int row_block,
	int col_block
) {
	size_t offset = ((size_t)row_block * (size_t)config->col_blocks + (size_t)col_block) * (size_t)config->block_words;
	return config->first_rows + offset;
}

const qc_encoder_config *qc_encoder_get_config(int selection) {
	int index;
	for (index = 0; index < k_qc_encoder_config_count; index++) {
		if (k_qc_encoder_configs[index].selection == selection) {
			return &k_qc_encoder_configs[index];
		}
	}
	return NULL;
}

void qc_encoder_compute_transmitted_parity(
	const qc_encoder_config *config,
	const uint8_t *message_bits,
	uint64_t *parity_blocks
) {
	int row_block;
	int col_block;
	const size_t parity_word_count = (size_t)config->col_blocks * (size_t)config->block_words;
	uint64_t *shift_registers = (uint64_t *)malloc(parity_word_count * sizeof(uint64_t));

	if (!shift_registers) {
		abort();
	}

	memset(parity_blocks, 0, parity_word_count * sizeof(uint64_t));

	for (row_block = 0; row_block < config->row_blocks; row_block++) {
		int local_bit;
		for (col_block = 0; col_block < config->col_blocks; col_block++) {
			block_copy(
				shift_registers + (size_t)col_block * (size_t)config->block_words,
				config_first_row_ptr(config, row_block, col_block),
				config->block_words
			);
		}

		for (local_bit = 0; local_bit < config->block_size; local_bit++) {
			if (message_bits[row_block * config->block_size + local_bit] != 0) {
				for (col_block = 0; col_block < config->col_blocks; col_block++) {
					block_xor(
						parity_blocks + (size_t)col_block * (size_t)config->block_words,
						shift_registers + (size_t)col_block * (size_t)config->block_words,
						config->block_words
					);
				}
			}
			for (col_block = 0; col_block < config->col_blocks; col_block++) {
				block_rotate_left_one(
					shift_registers + (size_t)col_block * (size_t)config->block_words,
					config->block_words,
					config->block_size
				);
			}
		}
	}

	free(shift_registers);
}

void qc_encoder_build_transmitted_codeword(
	const qc_encoder_config *config,
	const uint8_t *message_bits,
	const uint64_t *parity_blocks,
	uint8_t *transmitted_codeword
) {
	int bit_index;

	for (bit_index = 0; bit_index < config->info_length; bit_index++) {
		transmitted_codeword[bit_index] = message_bits[bit_index] ? 1u : 0u;
	}

	for (bit_index = 0; bit_index < config->transmitted_parity_length; bit_index++) {
		int block_index = bit_index / config->block_size;
		int local_index = bit_index % config->block_size;
		int word_index = local_index / 64;
		int bit_in_word = local_index % 64;
		transmitted_codeword[config->info_length + bit_index] =
			(uint8_t)((parity_blocks[(size_t)block_index * (size_t)config->block_words + (size_t)word_index] >> bit_in_word) & UINT64_C(1));
	}
}

void qc_encoder_encode(
	const qc_encoder_config *config,
	const uint8_t *message_bits,
	uint8_t *transmitted_codeword
) {
	const size_t parity_word_count = (size_t)config->col_blocks * (size_t)config->block_words;
	uint64_t *parity_blocks = (uint64_t *)malloc(parity_word_count * sizeof(uint64_t));

	if (!parity_blocks) {
		abort();
	}

	qc_encoder_compute_transmitted_parity(config, message_bits, parity_blocks);
	qc_encoder_build_transmitted_codeword(config, message_bits, parity_blocks, transmitted_codeword);
	free(parity_blocks);
}