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

static void fill_random_message(uint8_t *message_bits) {
	int index;
	for (index = 0; index < QC_INFO_LENGTH; index++) {
		message_bits[index] = (uint8_t)(rand() & 1);
	}
}

static void compute_reference_transmitted_codeword(
	const SparseRows *g_matrix,
	const uint8_t *message_bits,
	uint8_t *reference_codeword
) {
	int row;

	memset(reference_codeword, 0, (size_t)QC_TRANSMITTED_CODEWORD_LENGTH * sizeof(uint8_t));
	for (row = 0; row < QC_INFO_LENGTH; row++) {
		if (message_bits[row] != 0) {
			const SparseRow *g_row = &g_matrix->row_data[row];
			int index;
			for (index = 0; index < g_row->count; index++) {
				int col = g_row->cols[index];
				if (col < QC_TRANSMITTED_CODEWORD_LENGTH) {
					reference_codeword[col] ^= 1u;
				}
			}
		}
	}
}

static int compare_codewords(const uint8_t *lhs, const uint8_t *rhs, int *first_mismatch) {
	int index;
	for (index = 0; index < QC_TRANSMITTED_CODEWORD_LENGTH; index++) {
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
	const char *g_path = "../build_g/G_1_2_1024.mat";
	SparseRows g_matrix = { 0, 0, NULL };
	uint8_t message_bits[QC_INFO_LENGTH];
	uint8_t encoded_codeword[QC_TRANSMITTED_CODEWORD_LENGTH];
	uint8_t reference_codeword[QC_TRANSMITTED_CODEWORD_LENGTH];
	int trial_count = 8;
	unsigned int seed;
	int seed_from_cli = 0;
	int trial;

	if (argc >= 2) {
		trial_count = atoi(argv[1]);
		if (trial_count <= 0) {
			die("trial count must be positive");
		}
	}
	if (argc >= 3) {
		char *end_ptr = NULL;
		unsigned long parsed_seed = strtoul(argv[2], &end_ptr, 10);
		if (!argv[2][0] || (end_ptr && *end_ptr != '\0')) {
			die("seed must be an unsigned integer");
		}
		seed = (unsigned int)parsed_seed;
		seed_from_cli = 1;
	} else {
		seed = (unsigned int)time(NULL);
	}

	printf("QC LDPC encoder 1k 1/2 verification\n");
	printf("Loading G from %s\n", g_path);
	if (seed_from_cli) {
		printf("Using deterministic seed: %u\n", seed);
	} else {
		printf("Using time-based seed: %u\n", seed);
	}
	load_octave_sparse_mat(g_path, "G", &g_matrix);

	if (g_matrix.rows != QC_INFO_LENGTH || g_matrix.cols != 2560) {
		die("unexpected G dimensions for 1k 1/2 QC encoder");
	}

	srand(seed);
	for (trial = 0; trial < trial_count; trial++) {
		int first_mismatch = -1;
		fill_random_message(message_bits);
		qc_encoder_encode(message_bits, encoded_codeword);
		compute_reference_transmitted_codeword(&g_matrix, message_bits, reference_codeword);

		if (!compare_codewords(encoded_codeword, reference_codeword, &first_mismatch)) {
			printf("Trial %d: FAIL at transmitted bit %d\n", trial + 1, first_mismatch);
			printf("Reproduce with: test_qc_encoder.exe %d %u\n", trial_count, seed);
			print_preview("Message", message_bits, QC_INFO_LENGTH);
			print_preview("Encoded", encoded_codeword, QC_TRANSMITTED_CODEWORD_LENGTH);
			print_preview("Reference", reference_codeword, QC_TRANSMITTED_CODEWORD_LENGTH);
			sparse_rows_free(&g_matrix);
			return EXIT_FAILURE;
		}
	}

	print_preview("Last message", message_bits, QC_INFO_LENGTH);
	print_preview("Last transmitted codeword", encoded_codeword, QC_TRANSMITTED_CODEWORD_LENGTH);
	printf("Validated %d random message(s).\n", trial_count);
	printf("QC encoder output matches m x G on the transmitted codeword.\n");

	sparse_rows_free(&g_matrix);
	return EXIT_SUCCESS;
}