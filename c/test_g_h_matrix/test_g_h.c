#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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

static void *xmalloc(size_t size) {
	void *ptr = malloc(size);
	if (!ptr) {
		die("out of memory");
	}
	return ptr;
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
			char parsed_name[128];
			if (sscanf(line, "# name: %127s", parsed_name) == 1 && strcmp(parsed_name, expected_name) == 0) {
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
			if (rows <= 0 || cols <= 0) {
				die("invalid sparse matrix header");
			}
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
			if (row_index < 1 || row_index > mat->rows || col_index < 1 || col_index > mat->cols) {
				die("sparse matrix entry out of bounds");
			}
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

static void set_configuration_from_selection(int selection, const char **rate, int *block_length) {
	switch (selection) {
		case 1: *rate = "1/2"; *block_length = 1024; break;
		case 2: *rate = "1/2"; *block_length = 4096; break;
		case 3: *rate = "1/2"; *block_length = 16384; break;
		case 4: *rate = "2/3"; *block_length = 1024; break;
		case 5: *rate = "2/3"; *block_length = 4096; break;
		case 6: *rate = "2/3"; *block_length = 16384; break;
		case 7: *rate = "4/5"; *block_length = 1024; break;
		case 8: *rate = "4/5"; *block_length = 4096; break;
		case 9: *rate = "4/5"; *block_length = 16384; break;
		default:
			die("selection must be between 1 and 9");
	}
}

static void choose_configuration(const char **rate, int *block_length) {
	int selection;

	printf("Select a CCSDS LDPC configuration:\n");
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
	printf("\n");
	}

static void rate_to_tag(const char *rate, char *tag, size_t tag_size) {
	if (strcmp(rate, "1/2") == 0) {
		(void)snprintf(tag, tag_size, "1_2");
	} else if (strcmp(rate, "2/3") == 0) {
		(void)snprintf(tag, tag_size, "2_3");
	} else if (strcmp(rate, "4/5") == 0) {
		(void)snprintf(tag, tag_size, "4_5");
	} else {
		die("unsupported rate");
	}
}

static void build_matrix_paths(const char *rate, int block_length, char *g_path, size_t g_path_size, char *h_path, size_t h_path_size) {
	char tag[16];
	rate_to_tag(rate, tag, sizeof(tag));
	(void)snprintf(g_path, g_path_size, "../build_g/G_%s_%d.mat", tag, block_length);
	(void)snprintf(h_path, h_path_size, "../build_h/H_%s_%d.mat", tag, block_length);
}

static void fill_random_message(uint8_t *message, int length) {
	int index;
	for (index = 0; index < length; index++) {
		message[index] = (uint8_t)(rand() & 1);
	}
	}

static void encode_message_with_g(const uint8_t *message, const SparseRows *g_matrix, uint8_t *full_codeword) {
	int row;
	for (row = 0; row < g_matrix->rows; row++) {
		if (message[row] != 0) {
			const SparseRow *g_row = &g_matrix->row_data[row];
			int index;
			for (index = 0; index < g_row->count; index++) {
				full_codeword[g_row->cols[index]] ^= 1u;
			}
		}
	}
}

static int verify_systematic_prefix(const uint8_t *message, const uint8_t *full_codeword, int length) {
	int index;
	for (index = 0; index < length; index++) {
		if (message[index] != full_codeword[index]) {
			return 0;
		}
	}
	return 1;
}

static int verify_codeword_with_h(const SparseRows *h_matrix, const uint8_t *full_codeword, int *failing_row) {
	int row;
	for (row = 0; row < h_matrix->rows; row++) {
		const SparseRow *h_row = &h_matrix->row_data[row];
		uint8_t parity = 0;
		int index;
		for (index = 0; index < h_row->count; index++) {
			parity ^= full_codeword[h_row->cols[index]];
		}
		if (parity != 0) {
			if (failing_row) {
				*failing_row = row;
			}
			return 0;
		}
	}
	return 1;
}

static void print_bits_preview(const char *label, const uint8_t *bits, int length) {
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

static void copy_prefix(uint8_t *dst, const uint8_t *src, int length) {
	if (length > 0) {
		memcpy(dst, src, (size_t)length * sizeof(uint8_t));
	}
}

int main(int argc, char **argv) {
	const char *rate = NULL;
	int block_length = 0;
	char g_path[256];
	char h_path[256];
	SparseRows g_matrix = { 0, 0, NULL };
	SparseRows h_matrix = { 0, 0, NULL };
	uint8_t *message;
	uint8_t *full_codeword;
	uint8_t *transmitted_codeword;
	int selection = 0;
	int k;
	int n;
	int parity_rows;
	int transmitted_length;
	int failing_row = -1;
	int syndrome_ok;
	int systematic_ok;

	printf("CCSDS LDPC G/H matrix test\n\n");

	if (argc >= 2) {
		selection = atoi(argv[1]);
		set_configuration_from_selection(selection, &rate, &block_length);
	} else {
		choose_configuration(&rate, &block_length);
	}

	build_matrix_paths(rate, block_length, g_path, sizeof(g_path), h_path, sizeof(h_path));
	printf("Configuration: rate %s, block length %d\n", rate, block_length);
	printf("Loading G from %s\n", g_path);
	load_octave_sparse_mat(g_path, "G", &g_matrix);
	printf("Loading H from %s\n", h_path);
	load_octave_sparse_mat(h_path, "H", &h_matrix);

	k = g_matrix.rows;
	n = g_matrix.cols;
	if (h_matrix.cols != n) {
		die("G and H column counts do not match");
	}
	if (h_matrix.rows <= 0 || (h_matrix.rows % 3) != 0) {
		die("H row count is not a valid CCSDS 3*M value");
	}

	parity_rows = h_matrix.rows / 3;
	transmitted_length = n - parity_rows;
	if (transmitted_length <= 0) {
		die("invalid transmitted length derived from puncturing");
	}

	message = (uint8_t *)xcalloc((size_t)k, sizeof(uint8_t));
	full_codeword = (uint8_t *)xcalloc((size_t)n, sizeof(uint8_t));
	transmitted_codeword = (uint8_t *)xcalloc((size_t)transmitted_length, sizeof(uint8_t));

	srand((unsigned int)time(NULL));
	fill_random_message(message, k);
	encode_message_with_g(message, &g_matrix, full_codeword);
	copy_prefix(transmitted_codeword, full_codeword, transmitted_length);

	systematic_ok = verify_systematic_prefix(message, full_codeword, k);
	syndrome_ok = verify_codeword_with_h(&h_matrix, full_codeword, &failing_row);

	printf("\nG size: %d x %d\n", g_matrix.rows, g_matrix.cols);
	printf("H size: %d x %d\n", h_matrix.rows, h_matrix.cols);
	printf("Derived punctured block size M: %d\n", parity_rows);
	printf("Full codeword length: %d\n", n);
	printf("Transmitted codeword length: %d\n\n", transmitted_length);

	print_bits_preview("Message", message, k);
	print_bits_preview("Transmitted codeword", transmitted_codeword, transmitted_length);

	printf("\nSystematic prefix check: %s\n", systematic_ok ? "PASS" : "FAIL");
	if (!syndrome_ok) {
		printf("Syndrome check: FAIL at H row %d\n", failing_row + 1);
	} else {
		printf("Syndrome check: PASS\n");
	}

	if (!systematic_ok || !syndrome_ok) {
		free(transmitted_codeword);
		free(full_codeword);
		free(message);
		sparse_rows_free(&h_matrix);
		sparse_rows_free(&g_matrix);
		return EXIT_FAILURE;
	}

	printf("\nTest passed.\n");

	free(transmitted_codeword);
	free(full_codeword);
	free(message);
	sparse_rows_free(&h_matrix);
	sparse_rows_free(&g_matrix);
	return EXIT_SUCCESS;
}