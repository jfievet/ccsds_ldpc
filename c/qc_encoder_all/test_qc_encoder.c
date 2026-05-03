#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "qc_encoder.h"

typedef struct {
	int *cols;
	int count;
	int cap;
} SparseRow;

typedef struct {
	int rows;
	int cols;
	SparseRow *row_data;
} SparseRows;

static void die(const char *msg) {
	fprintf(stderr, "Error: %s\n", msg);
	exit(EXIT_FAILURE);
}

static void *xcalloc(size_t count, size_t size) {
	void *ptr = calloc(count, size);
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

static void sparse_rows_init(SparseRows *mat, int rows, int cols) {
	mat->rows = rows;
	mat->cols = cols;
	mat->row_data = (SparseRow *)xcalloc((size_t)rows, sizeof(SparseRow));
}

static void sparse_row_add(SparseRow *row, int col) {
	if (row->count == row->cap) {
		row->cap = row->cap ? row->cap * 2 : 8;
		row->cols = (int *)xrealloc(row->cols, (size_t)row->cap * sizeof(int));
	}
	row->cols[row->count++] = col;
}

static void sparse_rows_add(SparseRows *mat, int row, int col) {
	sparse_row_add(&mat->row_data[row], col);
}

static void sparse_rows_free(SparseRows *mat) {
	int row;
	for (row = 0; row < mat->rows; row++) {
		free(mat->row_data[row].cols);
	}
	free(mat->row_data);
	mat->row_data = NULL;
	mat->rows = 0;
	mat->cols = 0;
}

static void trim_line(char *line) {
	size_t len = strlen(line);
	while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
		line[--len] = '\0';
	}
}

static int is_blank_line(const char *line) {
	while (*line) {
		if (!isspace((unsigned char)*line)) {
			return 0;
		}
		line++;
	}
	return 1;
}

static void load_octave_sparse_mat(const char *filename, const char *expected_name, SparseRows *mat) {
	FILE *fp = fopen(filename, "r");
	char line[512];
	int rows = -1;
	int cols = -1;
	long expected_nnz = -1;
	long loaded_nnz = 0;
	int saw_sparse_type = 0;
	int saw_name = 0;

	if (!fp) {
		fprintf(stderr, "Error: could not open %s\n", filename);
		exit(EXIT_FAILURE);
	}

	while (fgets(line, sizeof(line), fp)) {
		int row_index;
		int col_index;
		int value;

		trim_line(line);
		if (is_blank_line(line)) {
			continue;
		}
		if (strncmp(line, "# name:", 7) == 0) {
			char parsed_name[64];
			if (sscanf(line, "# name: %63s", parsed_name) == 1 && strcmp(parsed_name, expected_name) == 0) {
				saw_name = 1;
			}
			continue;
		}
		if (strncmp(line, "# type:", 7) == 0) {
			if (strstr(line, "sparse matrix") != NULL) {
				saw_sparse_type = 1;
			}
			continue;
		}
		if (sscanf(line, "# nnz: %ld", &expected_nnz) == 1) {
			continue;
		}
		if (sscanf(line, "# rows: %d", &rows) == 1) {
			continue;
		}
		if (sscanf(line, "# columns: %d", &cols) == 1) {
			sparse_rows_init(mat, rows, cols);
			continue;
		}
		if (line[0] == '#') {
			continue;
		}
		if (!mat->row_data) {
			die("sparse matrix entries encountered before dimensions");
		}
		if (sscanf(line, "%d %d %d", &row_index, &col_index, &value) != 3) {
			die("invalid sparse matrix entry line");
		}
		if (value != 0) {
			sparse_rows_add(mat, row_index - 1, col_index - 1);
			loaded_nnz++;
		}
	}

	fclose(fp);

	if (!saw_name) {
		die("unexpected matrix variable name");
	}
	if (!saw_sparse_type) {
		die("input file is not a sparse matrix");
	}
	if (!mat->row_data) {
		die("matrix dimensions not found in input file");
	}
	if (expected_nnz >= 0 && loaded_nnz != expected_nnz) {
		die("sparse matrix nnz count mismatch");
	}
}

static void fill_random_message(const qc_encoder_config *config, uint8_t *message_bits) {
	int index;
	for (index = 0; index < config->info_length; index++) {
		message_bits[index] = (uint8_t)(rand() & 1);
	}
}

static void compute_reference_transmitted_codeword(
	const qc_encoder_config *config,
	const SparseRows *g_matrix,
	const uint8_t *message_bits,
	uint8_t *reference_codeword
) {
	int row;

	memset(reference_codeword, 0, (size_t)config->transmitted_length * sizeof(uint8_t));
	for (row = 0; row < config->info_length; row++) {
		if (message_bits[row] != 0) {
			const SparseRow *g_row = &g_matrix->row_data[row];
			int index;
			for (index = 0; index < g_row->count; index++) {
				int col = g_row->cols[index];
				if (col < config->transmitted_length) {
					reference_codeword[col] ^= 1u;
				}
			}
		}
	}
}

static int compare_codewords(const qc_encoder_config *config, const uint8_t *lhs, const uint8_t *rhs, int *first_mismatch) {
	int index;
	for (index = 0; index < config->transmitted_length; index++) {
		if (lhs[index] != rhs[index]) {
			if (first_mismatch) {
				*first_mismatch = index;
			}
			return 0;
		}
	}
	return 1;
}

static void print_preview(const char *label, const uint8_t *bits, int length) {
	int preview = length < 64 ? length : 64;
	int index;
	printf("%s (%d bits, first %d): ", label, length, preview);
	for (index = 0; index < preview; index++) {
		putchar(bits[index] ? '1' : '0');
	}
	if (length > preview) {
		printf("...");
	}
	printf("\n");
}

int main(int argc, char **argv) {
	const qc_encoder_config *config;
	SparseRows g_matrix = { 0, 0, NULL };
	uint8_t *message_bits;
	uint8_t *encoded_codeword;
	uint8_t *reference_codeword;
	int selection;
	unsigned int seed;
	int first_mismatch = -1;

	if (argc != 2) {
		fprintf(stderr, "Usage: %s <configuration 1..9>\n", argv[0]);
		return EXIT_FAILURE;
	}

	selection = atoi(argv[1]);
	config = qc_encoder_get_config(selection);
	if (!config) {
		die("configuration must be between 1 and 9");
	}

	printf("QC LDPC encoder verification for selection %d (%s)\n", config->selection, config->name);
	printf("Loading G from %s\n", config->g_matrix_path);
	printf(
		"info=%d transmitted=%d full=%d blocks=%dx%d block_size=%d\n",
		config->info_length,
		config->transmitted_length,
		config->full_length,
		config->row_blocks,
		config->col_blocks,
		config->block_size
	);

	load_octave_sparse_mat(config->g_matrix_path, "G", &g_matrix);
	if (g_matrix.rows != config->info_length || g_matrix.cols != config->full_length) {
		die("unexpected G dimensions for selected configuration");
	}

	message_bits = (uint8_t *)xcalloc((size_t)config->info_length, sizeof(uint8_t));
	encoded_codeword = (uint8_t *)xcalloc((size_t)config->transmitted_length, sizeof(uint8_t));
	reference_codeword = (uint8_t *)xcalloc((size_t)config->transmitted_length, sizeof(uint8_t));

	seed = (unsigned int)time(NULL) ^ (unsigned int)(config->selection * 2654435761u);
	srand(seed);
	fill_random_message(config, message_bits);
	qc_encoder_encode(config, message_bits, encoded_codeword);
	compute_reference_transmitted_codeword(config, &g_matrix, message_bits, reference_codeword);

	if (!compare_codewords(config, encoded_codeword, reference_codeword, &first_mismatch)) {
		printf("FAIL at transmitted bit %d\n", first_mismatch);
		print_preview("Message", message_bits, config->info_length);
		print_preview("Encoded", encoded_codeword, config->transmitted_length);
		print_preview("Reference", reference_codeword, config->transmitted_length);
		free(reference_codeword);
		free(encoded_codeword);
		free(message_bits);
		sparse_rows_free(&g_matrix);
		return EXIT_FAILURE;
	}

	printf("PASS: encoder output matches m x G on transmitted bits\n");
	free(reference_codeword);
	free(encoded_codeword);
	free(message_bits);
	sparse_rows_free(&g_matrix);
	return EXIT_SUCCESS;
}