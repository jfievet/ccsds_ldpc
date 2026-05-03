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

typedef struct {
	int rows;
	int cols;
	int words_per_row;
	uint64_t *words;
} BitMatrix;

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
		row->cap = row->cap ? row->cap * 2 : 4;
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

static int sparse_row_contains(const SparseRow *row, int col) {
	int index;
	for (index = 0; index < row->count; index++) {
		if (row->cols[index] == col) {
			return 1;
		}
	}
	return 0;
}

static void bitmatrix_init(BitMatrix *mat, int rows, int cols) {
	mat->rows = rows;
	mat->cols = cols;
	mat->words_per_row = (cols + 63) / 64;
	mat->words = (uint64_t *)xcalloc((size_t)rows * (size_t)mat->words_per_row, sizeof(uint64_t));
}

static void bitmatrix_free(BitMatrix *mat) {
	free(mat->words);
	mat->words = NULL;
	mat->rows = 0;
	mat->cols = 0;
	mat->words_per_row = 0;
}

static uint64_t *bitmatrix_row_ptr(BitMatrix *mat, int row) {
	return mat->words + (size_t)row * (size_t)mat->words_per_row;
}

static const uint64_t *bitmatrix_const_row_ptr(const BitMatrix *mat, int row) {
	return mat->words + (size_t)row * (size_t)mat->words_per_row;
}

static void bitmatrix_toggle(BitMatrix *mat, int row, int col) {
	uint64_t *row_ptr = bitmatrix_row_ptr(mat, row);
	row_ptr[col / 64] ^= UINT64_C(1) << (col % 64);
}

static void bitmatrix_set(BitMatrix *mat, int row, int col) {
	uint64_t *row_ptr = bitmatrix_row_ptr(mat, row);
	row_ptr[col / 64] |= UINT64_C(1) << (col % 64);
}

static int bitmatrix_get(const BitMatrix *mat, int row, int col) {
	const uint64_t *row_ptr = bitmatrix_const_row_ptr(mat, row);
	return (int)((row_ptr[col / 64] >> (col % 64)) & UINT64_C(1));
}

static void bitmatrix_xor_row_range(BitMatrix *mat, int dst_row, int src_row, int start_col) {
	uint64_t *dst = bitmatrix_row_ptr(mat, dst_row);
	const uint64_t *src = bitmatrix_const_row_ptr(mat, src_row);
	int word_index;
	int start_word = start_col / 64;

	for (word_index = start_word; word_index < mat->words_per_row; word_index++) {
		dst[word_index] ^= src[word_index];
	}
}

static void bitmatrix_xor_full_row(BitMatrix *dst, int dst_row, const BitMatrix *src, int src_row) {
	uint64_t *dst_ptr = bitmatrix_row_ptr(dst, dst_row);
	const uint64_t *src_ptr = bitmatrix_const_row_ptr(src, src_row);
	int word_index;

	for (word_index = 0; word_index < dst->words_per_row; word_index++) {
		dst_ptr[word_index] ^= src_ptr[word_index];
	}
}

static void bitmatrix_swap_rows(BitMatrix *mat, int row_a, int row_b) {
	uint64_t *a = bitmatrix_row_ptr(mat, row_a);
	uint64_t *b = bitmatrix_row_ptr(mat, row_b);
	int word_index;

	for (word_index = 0; word_index < mat->words_per_row; word_index++) {
		uint64_t temp = a[word_index];
		a[word_index] = b[word_index];
		b[word_index] = temp;
	}
}

static size_t bitmatrix_row_popcount(const BitMatrix *mat, int row) {
	const uint64_t *row_ptr = bitmatrix_const_row_ptr(mat, row);
	size_t count = 0;
	int word_index;

	for (word_index = 0; word_index < mat->words_per_row; word_index++) {
		count += (size_t)__builtin_popcountll(row_ptr[word_index]);
	}
	return count;
}

static int bitmatrix_row_is_zero(const BitMatrix *mat, int row) {
	const uint64_t *row_ptr = bitmatrix_const_row_ptr(mat, row);
	int word_index;

	for (word_index = 0; word_index < mat->words_per_row; word_index++) {
		if (row_ptr[word_index] != 0) {
			return 0;
		}
	}
	return 1;
}

static void bitmatrix_toggle_sparse_row(BitMatrix *mat, int row, const SparseRow *sparse_row, int offset) {
	int index;
	for (index = 0; index < sparse_row->count; index++) {
		bitmatrix_toggle(mat, row, offset + sparse_row->cols[index]);
	}
}

static void set_configuration_from_selection(int selection, char rate[4], int *block_length) {
	switch (selection) {
		case 1: strcpy(rate, "1/2"); *block_length = 1024; break;
		case 2: strcpy(rate, "1/2"); *block_length = 4096; break;
		case 3: strcpy(rate, "1/2"); *block_length = 16384; break;
		case 4: strcpy(rate, "2/3"); *block_length = 1024; break;
		case 5: strcpy(rate, "2/3"); *block_length = 4096; break;
		case 6: strcpy(rate, "2/3"); *block_length = 16384; break;
		case 7: strcpy(rate, "4/5"); *block_length = 1024; break;
		case 8: strcpy(rate, "4/5"); *block_length = 4096; break;
		case 9: strcpy(rate, "4/5"); *block_length = 16384; break;
		default: die("invalid selection; choose an integer from 1 to 9");
	}
}

static void choose_configuration(char rate[4], int *block_length) {
	int selection;

	printf("Select CCSDS LDPC configuration:\n");
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
}

static void make_rate_tag(const char *rate, char out[4]) {
	out[0] = rate[0];
	out[1] = '_';
	out[2] = rate[2];
	out[3] = '\0';
}

static int file_exists(const char *path) {
	FILE *fp = fopen(path, "r");
	if (!fp) {
		return 0;
	}
	fclose(fp);
	return 1;
}

static void find_h_file(const char *rate, int block_length, char *out_path, size_t out_path_size) {
	char h_filename[64];
	char rate_tag[4];
	const char *prefixes[] = {
		"..\\build_h\\",
		"..\\build_H\\",
		"build_h\\",
		"build_H\\"
	};
	size_t prefix_index;

	make_rate_tag(rate, rate_tag);
	snprintf(h_filename, sizeof(h_filename), "H_%s_%d.mat", rate_tag, block_length);

	for (prefix_index = 0; prefix_index < sizeof(prefixes) / sizeof(prefixes[0]); prefix_index++) {
		snprintf(out_path, out_path_size, "%s%s", prefixes[prefix_index], h_filename);
		if (file_exists(out_path)) {
			return;
		}
	}

	die("could not find the required H_*.mat file in build_h/ or build_H/");
}

static SparseRows extract_block(const SparseRows *src, int row_start, int row_count, int col_start, int col_count) {
	SparseRows out;
	int row_offset;

	sparse_rows_init(&out, row_count, col_count);

	for (row_offset = 0; row_offset < row_count; row_offset++) {
		const SparseRow *src_row = &src->row_data[row_start + row_offset];
		int index;
		for (index = 0; index < src_row->count; index++) {
			int col = src_row->cols[index];
			if (col >= col_start && col < col_start + col_count) {
				sparse_rows_add(&out, row_offset, col - col_start);
			}
		}
	}

	return out;
}

static SparseRows load_octave_sparse_text_mat(const char *path, const char *expected_name) {
	FILE *fp;
	char line[256];
	int rows = -1;
	int cols = -1;
	char found_name[64] = "";
	SparseRows mat;
	int initialized = 0;

	fp = fopen(path, "r");
	if (!fp) {
		die("could not open H matrix file");
	}

	while (fgets(line, sizeof(line), fp) != NULL) {
		if (line[0] == '#') {
			if (sscanf(line, "# name: %63s", found_name) == 1) {
				continue;
			}
			if (sscanf(line, "# rows: %d", &rows) == 1) {
				continue;
			}
			if (sscanf(line, "# columns: %d", &cols) == 1) {
				continue;
			}
			continue;
		}

		if (rows < 0 || cols < 0) {
			die("invalid sparse-text mat file header");
		}

		if (!initialized) {
			sparse_rows_init(&mat, rows, cols);
			initialized = 1;
		}

		if (line[0] != '\n' && line[0] != '\r' && line[0] != '\0') {
			int row_1based;
			int col_1based;
			double value;

			if (sscanf(line, "%d %d %lf", &row_1based, &col_1based, &value) != 3) {
				die("invalid sparse-text matrix entry");
			}

			if (((int)value & 1) != 0) {
				sparse_rows_add(&mat, row_1based - 1, col_1based - 1);
			}
		}
	}

	fclose(fp);

	if (!initialized) {
		die("sparse-text mat file did not contain matrix data");
	}

	if (expected_name && expected_name[0] != '\0' && strcmp(found_name, expected_name) != 0) {
		die("mat file did not contain the expected matrix variable");
	}

	return mat;
}

static void expect_identity_block(const SparseRows *block, const char *message) {
	int row;
	for (row = 0; row < block->rows; row++) {
		const SparseRow *current = &block->row_data[row];
		if (current->count != 1 || current->cols[0] != row) {
			die(message);
		}
	}
}

static void expect_zero_block(const SparseRows *block, const char *message) {
	int row;
	for (row = 0; row < block->rows; row++) {
		if (block->row_data[row].count != 0) {
			die(message);
		}
	}
}

static void print_progress(int current_step, int total_steps, int *last_reported_percent) {
	int percent = (100 * current_step) / total_steps;
	if (percent > *last_reported_percent) {
		printf("Progress: %d%%\n", percent);
		*last_reported_percent = percent;
	}
}

static BitMatrix build_augmented_system(
	const SparseRows *A,
	const SparseRows *B,
	const SparseRows *S2,
	const SparseRows *S4,
	int M,
	int k
) {
	BitMatrix aug;
	int row;

	bitmatrix_init(&aug, M, M + k);

	for (row = 0; row < M; row++) {
		int index;
		bitmatrix_set(&aug, row, row);
		bitmatrix_toggle_sparse_row(&aug, row, &B->row_data[row], M);

		for (index = 0; index < S4->row_data[row].count; index++) {
			int dep = S4->row_data[row].cols[index];
			const SparseRow *s2_row = &S2->row_data[dep];
			const SparseRow *a_row = &A->row_data[dep];
			bitmatrix_toggle_sparse_row(&aug, row, s2_row, 0);
			bitmatrix_toggle_sparse_row(&aug, row, a_row, M);
		}
	}

	return aug;
}

static void solve_augmented_gf2(BitMatrix *aug, int M, int k) {
	int pivot;
	int total_steps = 2 * M;
	int last_reported_percent = -1;
	int augmented_columns = M + k;

	printf("Solving Section 7.4.3 GF(2) system of size %d x %d...\n", M, M);

	for (pivot = 0; pivot < M; pivot++) {
		int pivot_row = pivot;
		print_progress(pivot + 1, total_steps, &last_reported_percent);

		while (pivot_row < M && !bitmatrix_get(aug, pivot_row, pivot)) {
			pivot_row++;
		}

		if (pivot_row == M) {
			die("generator construction failed: singular parity block matrix");
		}

		if (pivot_row != pivot) {
			bitmatrix_swap_rows(aug, pivot, pivot_row);
		}

		if (pivot < M - 1) {
			int row;
			for (row = pivot + 1; row < M; row++) {
				if (bitmatrix_get(aug, row, pivot)) {
					bitmatrix_xor_row_range(aug, row, pivot, pivot);
				}
			}
		}
	}

	for (pivot = M - 1; pivot >= 0; pivot--) {
		int row;
		(void)augmented_columns;
		print_progress(2 * M - pivot, total_steps, &last_reported_percent);
		for (row = 0; row < pivot; row++) {
			if (bitmatrix_get(aug, row, pivot)) {
				bitmatrix_xor_row_range(aug, row, pivot, pivot);
			}
		}
	}

	if (last_reported_percent < 100) {
		printf("Progress: 100%%\n");
	}
}

static BitMatrix extract_rhs_matrix(const BitMatrix *aug, int M, int k) {
	BitMatrix out;
	int row;
	int col;

	bitmatrix_init(&out, M, k);

	for (row = 0; row < M; row++) {
		for (col = 0; col < k; col++) {
			if (bitmatrix_get(aug, row, M + col)) {
				bitmatrix_set(&out, row, col);
			}
		}
	}

	return out;
}

static BitMatrix build_coeff_from_sparse_plus_product(const SparseRows *base, const SparseRows *mult, const BitMatrix *rhs) {
	BitMatrix out;
	int row;

	bitmatrix_init(&out, base->rows, base->cols);

	for (row = 0; row < base->rows; row++) {
		int index;
		bitmatrix_toggle_sparse_row(&out, row, &base->row_data[row], 0);
		for (index = 0; index < mult->row_data[row].count; index++) {
			int dep = mult->row_data[row].cols[index];
			bitmatrix_xor_full_row(&out, row, rhs, dep);
		}
	}

	return out;
}

static BitMatrix build_coeff_from_product(const SparseRows *mult, const BitMatrix *rhs) {
	BitMatrix out;
	int row;

	bitmatrix_init(&out, mult->rows, rhs->cols);

	for (row = 0; row < mult->rows; row++) {
		int index;
		for (index = 0; index < mult->row_data[row].count; index++) {
			int dep = mult->row_data[row].cols[index];
			bitmatrix_xor_full_row(&out, row, rhs, dep);
		}
	}

	return out;
}

static void verify_generator(
	const SparseRows *row1_parity3,
	const SparseRows *A,
	const SparseRows *B,
	const SparseRows *S2,
	const SparseRows *S4,
	const BitMatrix *p1,
	const BitMatrix *p2,
	const BitMatrix *p3
) {
	BitMatrix eq1;
	BitMatrix eq2;
	BitMatrix eq3;
	int row;

	eq1 = build_coeff_from_product(row1_parity3, p3);
	eq2 = build_coeff_from_sparse_plus_product(A, S2, p3);
	eq3 = build_coeff_from_sparse_plus_product(B, S4, p2);

	for (row = 0; row < p1->rows; row++) {
		bitmatrix_xor_full_row(&eq1, row, p1, row);
		bitmatrix_xor_full_row(&eq2, row, p2, row);
		bitmatrix_xor_full_row(&eq3, row, p3, row);

		if (!bitmatrix_row_is_zero(&eq1, row) || !bitmatrix_row_is_zero(&eq2, row) || !bitmatrix_row_is_zero(&eq3, row)) {
			die("generator verification failed: H * G' is not zero over GF(2)");
		}
	}

	bitmatrix_free(&eq1);
	bitmatrix_free(&eq2);
	bitmatrix_free(&eq3);
}

static size_t count_g_nnz(const BitMatrix *p1, const BitMatrix *p2, const BitMatrix *p3, int k) {
	size_t total = (size_t)k;
	int row;

	for (row = 0; row < p1->rows; row++) {
		total += bitmatrix_row_popcount(p1, row);
		total += bitmatrix_row_popcount(p2, row);
		total += bitmatrix_row_popcount(p3, row);
	}

	return total;
}

static void write_bitmatrix_row_as_column(FILE *fp, const BitMatrix *mat, int bit_row, int column_1based) {
	const uint64_t *row_ptr = bitmatrix_const_row_ptr(mat, bit_row);
	int word_index;

	for (word_index = 0; word_index < mat->words_per_row; word_index++) {
		uint64_t word = row_ptr[word_index];
		while (word != 0) {
			unsigned long bit_index = (unsigned long)__builtin_ctzll(word);
			int row_1based = word_index * 64 + (int)bit_index + 1;
			if (row_1based <= mat->cols) {
				fprintf(fp, "%d %d 1\n", row_1based, column_1based);
			}
			word &= word - 1;
		}
	}
}

static void save_g_sparse_text_mat(
	const char *filename,
	const BitMatrix *p1,
	const BitMatrix *p2,
	const BitMatrix *p3,
	int k,
	int n
) {
	FILE *fp;
	time_t now;
	struct tm *tm_utc;
	char timestamp[64];
	int info_col;
	int row;
	size_t nnz = count_g_nnz(p1, p2, p3, k);

	fp = fopen(filename, "w");
	if (!fp) {
		die("could not open output G mat file for writing");
	}

	now = time(NULL);
	tm_utc = gmtime(&now);
	if (tm_utc && strftime(timestamp, sizeof(timestamp), "%a %b %d %H:%M:%S %Y UTC", tm_utc) > 0) {
		fprintf(fp, "# Created by build_g.c, %s\n", timestamp);
	} else {
		fprintf(fp, "# Created by build_g.c\n");
	}

	fprintf(fp, "# name: G\n");
	fprintf(fp, "# type: sparse matrix\n");
	fprintf(fp, "# nnz: %zu\n", nnz);
	fprintf(fp, "# rows: %d\n", k);
	fprintf(fp, "# columns: %d\n", n);

	for (info_col = 0; info_col < k; info_col++) {
		fprintf(fp, "%d %d 1\n", info_col + 1, info_col + 1);
	}

	for (row = 0; row < p1->rows; row++) {
		write_bitmatrix_row_as_column(fp, p1, row, k + row + 1);
	}

	for (row = 0; row < p2->rows; row++) {
		write_bitmatrix_row_as_column(fp, p2, row, k + p1->rows + row + 1);
	}

	for (row = 0; row < p3->rows; row++) {
		write_bitmatrix_row_as_column(fp, p3, row, k + 2 * p1->rows + row + 1);
	}

	fclose(fp);
}

int main(int argc, char **argv) {
	char rate[4];
	char rate_tag[4];
	char h_path[260];
	char g_filename[64];
	long selection;
	char *endptr = NULL;
	int block_length;
	SparseRows H;
	SparseRows row1_parity1;
	SparseRows row1_parity2;
	SparseRows row1_parity3;
	SparseRows row2_info;
	SparseRows row2_parity1;
	SparseRows row2_parity2;
	SparseRows row2_parity3;
	SparseRows row3_info;
	SparseRows row3_parity1;
	SparseRows row3_parity2;
	SparseRows row3_parity3;
	BitMatrix aug;
	BitMatrix p3_coeff;
	BitMatrix p2_coeff;
	BitMatrix p1_coeff;
	int m;
	int n;
	int M;
	int k;
	int k_blocks;

	if (argc >= 2) {
		selection = strtol(argv[1], &endptr, 10);
		if (argv[1][0] == '\0' || *endptr != '\0') {
			die("argument must be an integer from 1 to 9");
		}
		set_configuration_from_selection((int)selection, rate, &block_length);
	} else {
		choose_configuration(rate, &block_length);
	}

	find_h_file(rate, block_length, h_path, sizeof(h_path));
	H = load_octave_sparse_text_mat(h_path, "H");

	m = H.rows;
	n = H.cols;
	if ((m % 3) != 0) {
		die("unexpected H size: the number of rows must be 3*M");
	}

	M = m / 3;
	k = n - m;
	if ((k % M) != 0) {
		die("unexpected H size: k must be a multiple of M");
	}

	k_blocks = k / M;
	if (k_blocks != 2 && k_blocks != 4 && k_blocks != 8) {
		die("unsupported H structure for Section 7.4.3");
	}

	row1_parity1 = extract_block(&H, 0, M, k, M);
	row1_parity2 = extract_block(&H, 0, M, k + M, M);
	row1_parity3 = extract_block(&H, 0, M, k + 2 * M, M);

	row2_info = extract_block(&H, M, M, 0, k);
	row2_parity1 = extract_block(&H, M, M, k, M);
	row2_parity2 = extract_block(&H, M, M, k + M, M);
	row2_parity3 = extract_block(&H, M, M, k + 2 * M, M);

	row3_info = extract_block(&H, 2 * M, M, 0, k);
	row3_parity1 = extract_block(&H, 2 * M, M, k, M);
	row3_parity2 = extract_block(&H, 2 * M, M, k + M, M);
	row3_parity3 = extract_block(&H, 2 * M, M, k + 2 * M, M);

	expect_identity_block(&row1_parity1, "unexpected Section 7.4.3 structure: row-1 parity block 1 must be identity");
	expect_zero_block(&row1_parity2, "unexpected Section 7.4.3 structure: row-1 parity block 2 must be zero");
	expect_zero_block(&row2_parity1, "unexpected Section 7.4.3 structure: row-2 parity block 1 must be zero");
	expect_identity_block(&row2_parity2, "unexpected Section 7.4.3 structure: row-2 parity block 2 must be identity");
	expect_zero_block(&row3_parity1, "unexpected Section 7.4.3 structure: row-3 parity block 1 must be zero");
	expect_identity_block(&row3_parity3, "unexpected Section 7.4.3 structure: row-3 parity block 3 must be identity");

	aug = build_augmented_system(&row2_info, &row3_info, &row2_parity3, &row3_parity2, M, k);
	solve_augmented_gf2(&aug, M, k);

	p3_coeff = extract_rhs_matrix(&aug, M, k);
	p2_coeff = build_coeff_from_sparse_plus_product(&row2_info, &row2_parity3, &p3_coeff);
	p1_coeff = build_coeff_from_product(&row1_parity3, &p3_coeff);

	verify_generator(&row1_parity3, &row2_info, &row3_info, &row2_parity3, &row3_parity2, &p1_coeff, &p2_coeff, &p3_coeff);

	make_rate_tag(rate, rate_tag);
	snprintf(g_filename, sizeof(g_filename), "G_%s_%d.mat", rate_tag, block_length);
	save_g_sparse_text_mat(g_filename, &p1_coeff, &p2_coeff, &p3_coeff, k, n);

	printf("Built CCSDS LDPC G for rate %s, block length %d.\n", rate, block_length);
	printf("G size: %d x %d\n", k, n);
	printf("Loaded H from %s\n", h_path);
	printf("Saved G matrix to %s\n", g_filename);

	bitmatrix_free(&p1_coeff);
	bitmatrix_free(&p2_coeff);
	bitmatrix_free(&p3_coeff);
	bitmatrix_free(&aug);

	sparse_rows_free(&row1_parity1);
	sparse_rows_free(&row1_parity2);
	sparse_rows_free(&row1_parity3);
	sparse_rows_free(&row2_info);
	sparse_rows_free(&row2_parity1);
	sparse_rows_free(&row2_parity2);
	sparse_rows_free(&row2_parity3);
	sparse_rows_free(&row3_info);
	sparse_rows_free(&row3_parity1);
	sparse_rows_free(&row3_parity2);
	sparse_rows_free(&row3_parity3);
	sparse_rows_free(&H);

	return 0;
}
