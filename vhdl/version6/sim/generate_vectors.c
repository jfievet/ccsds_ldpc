//gcc -O2 -std=c99 -o generate_vectors.exe generate_vectors.c

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
  int selection;
  const char *suffix;
  const char *g_path;
  int info_length;
  int transmitted_length;
  int full_length;
  int row_blocks;
  int col_blocks;
  int block_size;
} t_config;

static const t_config C_CONFIGS[] = {
  {1, "1k_12", "../../../c/build_g/G_1_2_1024.mat", 1024, 2048, 2560, 8, 8, 128},
  {2, "4k_12", "../../../c/build_g/G_1_2_4096.mat", 4096, 8192, 10240, 8, 8, 512},
  {3, "16k_12", "../../../c/build_g/G_1_2_16384.mat", 16384, 32768, 40960, 8, 8, 2048},
  {4, "1k_23", "../../../c/build_g/G_2_3_1024.mat", 1024, 1536, 1792, 16, 8, 64},
  {5, "4k_23", "../../../c/build_g/G_2_3_4096.mat", 4096, 6144, 7168, 16, 8, 256},
  {6, "16k_23", "../../../c/build_g/G_2_3_16384.mat", 16384, 24576, 28672, 16, 8, 1024},
  {7, "1k_45", "../../../c/build_g/G_4_5_1024.mat", 1024, 1280, 1408, 32, 8, 32},
  {8, "4k_45", "../../../c/build_g/G_4_5_4096.mat", 4096, 5120, 5632, 32, 8, 128},
  {9, "16k_45", "../../../c/build_g/G_4_5_16384.mat", 16384, 20480, 22528, 32, 8, 512},
};

static void fail(const char *message) {
  fprintf(stderr, "%s\n", message);
  exit(1);
}

static void *checked_calloc(size_t count, size_t size) {
  void *ptr = calloc(count, size);
  if (ptr == NULL) {
    fail("Out of memory");
  }
  return ptr;
}

static const t_config *find_config(const char *suffix) {
  size_t index = 0;
  for (index = 0; index < sizeof(C_CONFIGS) / sizeof(C_CONFIGS[0]); ++index) {
    if (strcmp(C_CONFIGS[index].suffix, suffix) == 0) {
      return &C_CONFIGS[index];
    }
  }
  return NULL;
}

static void set_block_bit(uint64_t *block_words, int bit_index) {
  int word_index = bit_index / 64;
  int word_bit_index = bit_index % 64;
  block_words[word_index] |= ((uint64_t)1) << word_bit_index;
}

static uint8_t get_block_bit(const uint64_t *block_words, int bit_index) {
  int word_index = bit_index / 64;
  int word_bit_index = bit_index % 64;
  return (uint8_t)((block_words[word_index] >> word_bit_index) & ((uint64_t)1));
}

static void copy_block_words(uint64_t *dst_words, const uint64_t *src_words, int word_count) {
  int word_index = 0;
  for (word_index = 0; word_index < word_count; ++word_index) {
    dst_words[word_index] = src_words[word_index];
  }
}

static void xor_block_words(uint64_t *dst_words, const uint64_t *src_words, int word_count) {
  int word_index = 0;
  for (word_index = 0; word_index < word_count; ++word_index) {
    dst_words[word_index] ^= src_words[word_index];
  }
}

static void mask_last_word(uint64_t *block_words, int block_size, int word_count) {
  int valid_bits = block_size - ((word_count - 1) * 64);
  if (valid_bits < 64) {
    uint64_t mask = (((uint64_t)1) << valid_bits) - 1;
    block_words[word_count - 1] &= mask;
  }
}

static void rotate_block_left_one(uint64_t *block_words, int block_size, int word_count) {
  uint64_t carry_bit = (uint64_t)get_block_bit(block_words, block_size - 1);
  int word_index = 0;
  for (word_index = 0; word_index < word_count; ++word_index) {
    uint64_t next_carry = (block_words[word_index] >> 63) & ((uint64_t)1);
    block_words[word_index] = (block_words[word_index] << 1) | carry_bit;
    carry_bit = next_carry;
  }
  mask_last_word(block_words, block_size, word_count);
}

static void load_first_rows(const t_config *config, uint64_t *first_rows, int block_words) {
  FILE *handle = fopen(config->g_path, "r");
  char line[256];
  int rows = -1;
  int cols = -1;
  int nnz_expected = -1;
  int nnz_loaded = 0;
  char variable_name[32];

  if (handle == NULL) {
    fprintf(stderr, "Failed to open %s: %s\n", config->g_path, strerror(errno));
    exit(1);
  }

  variable_name[0] = '\0';
  while (fgets(line, (int)sizeof(line), handle) != NULL) {
    int row_index = 0;
    int col_index = 0;
    int value = 0;

    if (line[0] == '#') {
      if (sscanf(line, "# name: %31s", variable_name) == 1) {
        continue;
      }
      if (sscanf(line, "# rows: %d", &rows) == 1) {
        continue;
      }
      if (sscanf(line, "# columns: %d", &cols) == 1) {
        continue;
      }
      if (sscanf(line, "# nnz: %d", &nnz_expected) == 1) {
        continue;
      }
      continue;
    }

    if (sscanf(line, "%d %d %d", &row_index, &col_index, &value) != 3) {
      continue;
    }
    if (value == 0) {
      continue;
    }

    nnz_loaded += 1;
    row_index -= 1;
    col_index -= 1;
    if ((row_index % config->block_size) == 0 && col_index >= config->info_length && col_index < config->transmitted_length) {
      int row_block = row_index / config->block_size;
      int transmitted_col = col_index - config->info_length;
      int col_block = transmitted_col / config->block_size;
      int bit_index = transmitted_col % config->block_size;
      uint64_t *block_ptr = first_rows + (((row_block * config->col_blocks) + col_block) * block_words);
      set_block_bit(block_ptr, bit_index);
    }
  }

  fclose(handle);
  if (strcmp(variable_name, "G") != 0) {
    fail("Expected variable G in sparse matrix file");
  }
  if (rows != config->info_length || cols != config->full_length) {
    fail("Unexpected sparse matrix dimensions");
  }
  if (nnz_expected >= 0 && nnz_expected != nnz_loaded) {
    fail("Sparse matrix nnz mismatch");
  }
}

static void build_message(const t_config *config, uint8_t *message_bits) {
  int bit_index = 0;
  for (bit_index = 0; bit_index < config->info_length; ++bit_index) {
    message_bits[bit_index] = (uint8_t)(rand() & 1U);
  }
  if (config->info_length > 0) {
    message_bits[0] = 1;
  }
}

static void build_codeword(
  const t_config *config,
  const uint8_t *message_bits,
  const uint64_t *first_rows,
  uint8_t *codeword_bits
) {
  int block_words = (config->block_size + 63) / 64;
  int block_count = config->col_blocks;
  int bit_index = 0;
  uint64_t *shift_registers = checked_calloc((size_t)(block_count * block_words), sizeof(uint64_t));
  uint64_t *parity_blocks = checked_calloc((size_t)(block_count * block_words), sizeof(uint64_t));

  for (bit_index = 0; bit_index < config->info_length; ++bit_index) {
    int row_block = bit_index / config->block_size;
    int local_index = bit_index % config->block_size;
    int col_block = 0;

    if (local_index == 0) {
      for (col_block = 0; col_block < block_count; ++col_block) {
        const uint64_t *rom_block = first_rows + (((row_block * block_count) + col_block) * block_words);
        uint64_t *shift_block = shift_registers + (col_block * block_words);
        if (message_bits[bit_index] != 0) {
          xor_block_words(parity_blocks + (col_block * block_words), rom_block, block_words);
        }
        copy_block_words(shift_block, rom_block, block_words);
        rotate_block_left_one(shift_block, config->block_size, block_words);
      }
    } else {
      for (col_block = 0; col_block < block_count; ++col_block) {
        uint64_t *shift_block = shift_registers + (col_block * block_words);
        if (message_bits[bit_index] != 0) {
          xor_block_words(parity_blocks + (col_block * block_words), shift_block, block_words);
        }
        rotate_block_left_one(shift_block, config->block_size, block_words);
      }
    }
  }

  for (bit_index = 0; bit_index < config->info_length; ++bit_index) {
    codeword_bits[bit_index] = message_bits[bit_index];
  }
  for (bit_index = 0; bit_index < config->transmitted_length - config->info_length; ++bit_index) {
    int col_block = bit_index / config->block_size;
    int local_index = bit_index % config->block_size;
    codeword_bits[config->info_length + bit_index] = get_block_bit(parity_blocks + (col_block * block_words), local_index);
  }

  free(shift_registers);
  free(parity_blocks);
}

static void write_bit_file(const char *path, const uint8_t *bits, int bit_count) {
  FILE *handle = fopen(path, "w");
  int bit_index = 0;
  if (handle == NULL) {
    fprintf(stderr, "Failed to open %s for writing: %s\n", path, strerror(errno));
    exit(1);
  }
  for (bit_index = 0; bit_index < bit_count; ++bit_index) {
    fprintf(handle, "%u\n", (unsigned)bits[bit_index]);
  }
  fclose(handle);
}

static void write_rom_package(const t_config *config, const uint64_t *first_rows) {
  char path[256];
  FILE *handle;
  int block_words = (config->block_size + 63) / 64;
  int col_block = 0;
  int row_block = 0;

  snprintf(path, sizeof(path), "../src/ldpc_encoder_%s_qc_rom_pkg.vhd", config->suffix);
  handle = fopen(path, "w");
  if (handle == NULL) {
    fprintf(stderr, "Failed to open %s for writing: %s\n", path, strerror(errno));
    exit(1);
  }

  fprintf(handle, "library ieee;\n");
  fprintf(handle, "use ieee.std_logic_1164.all;\n\n");
  fprintf(handle, "library work;\n");
  fprintf(handle, "use work.ldpc_encoder_%s_config_pkg.all;\n\n", config->suffix);
  fprintf(handle, "package ldpc_encoder_%s_qc_rom_pkg is\n", config->suffix);
  fprintf(handle, "  type t_ldpc_%s_rom is array (0 to LDPC_QC_ROW_BLOCKS - 1) of std_logic_vector(LDPC_QC_BLOCK_SIZE - 1 downto 0);\n", config->suffix);
  fprintf(handle, "  type t_ldpc_%s_rom_bank is array (0 to LDPC_QC_COL_BLOCKS - 1) of t_ldpc_%s_rom;\n", config->suffix, config->suffix);
  fprintf(handle, "  constant C_LDPC_QC_ROM_BANK_");
  for (row_block = 0; config->suffix[row_block] != '\0'; ++row_block) {
    char character = config->suffix[row_block];
    if (character >= 'a' && character <= 'z') {
      character = (char)(character - 'a' + 'A');
    }
    fputc(character, handle);
  }
  fprintf(handle, " : t_ldpc_%s_rom_bank := (\n", config->suffix);

  for (col_block = 0; col_block < config->col_blocks; ++col_block) {
    fprintf(handle, "    %d => (\n", col_block);
    for (row_block = 0; row_block < config->row_blocks; ++row_block) {
      int bit_index = 0;
      const uint64_t *block_ptr = first_rows + (((row_block * config->col_blocks) + col_block) * block_words);
      fprintf(handle, "      %d => \"", row_block);
      for (bit_index = config->block_size - 1; bit_index >= 0; --bit_index) {
        fputc(get_block_bit(block_ptr, bit_index) != 0 ? '1' : '0', handle);
      }
      if (row_block + 1 < config->row_blocks) {
        fprintf(handle, "\",\n");
      } else {
        fprintf(handle, "\"\n");
      }
    }
    if (col_block + 1 < config->col_blocks) {
      fprintf(handle, "    ),\n");
    } else {
      fprintf(handle, "    )\n");
    }
  }

  fprintf(handle, "  );\n");
  fprintf(handle, "end package ldpc_encoder_%s_qc_rom_pkg;\n", config->suffix);
  fclose(handle);
}

static void write_chunks(FILE *handle, const uint8_t *bits, int bit_count) {
  int start_index = 0;
  int chunk_size = 128;
  for (start_index = 0; start_index < bit_count; start_index += chunk_size) {
    int end_index = start_index + chunk_size;
    int bit_index = 0;
    if (end_index > bit_count) {
      end_index = bit_count;
    }
    fprintf(handle, "    \"");
    for (bit_index = start_index; bit_index < end_index; ++bit_index) {
      fputc(bits[bit_index] != 0 ? '1' : '0', handle);
    }
    if (end_index < bit_count) {
      fprintf(handle, "\" &\n");
    } else {
      fprintf(handle, "\";\n");
    }
  }
}

static void write_vhdl_vectors_package(const t_config *config, const uint8_t *message_bits, const uint8_t *codeword_bits) {
  char path[256];
  FILE *handle;

  snprintf(path, sizeof(path), "../tb/ldpc_encoder_%s_vectors_pkg.vhd", config->suffix);
  handle = fopen(path, "w");
  if (handle == NULL) {
    fprintf(stderr, "Failed to open %s for writing: %s\n", path, strerror(errno));
    exit(1);
  }

  fprintf(handle, "library ieee;\n");
  fprintf(handle, "use ieee.std_logic_1164.all;\n\n");
  fprintf(handle, "library work;\n");
  fprintf(handle, "use work.ldpc_encoder_%s_config_pkg.all;\n\n", config->suffix);
  fprintf(handle, "package ldpc_encoder_%s_vectors_pkg is\n", config->suffix);
  fprintf(handle, "  constant MESSAGE_BITS : std_logic_vector(0 to LDPC_K - 1) :=\n");
  write_chunks(handle, message_bits, config->info_length);
  fprintf(handle, "  constant EXPECTED_CODEWORD : std_logic_vector(0 to LDPC_N - 1) :=\n");
  write_chunks(handle, codeword_bits, config->transmitted_length);
  fprintf(handle, "end package ldpc_encoder_%s_vectors_pkg;\n", config->suffix);
  fclose(handle);
}

static void generate_one(const t_config *config) {
  int block_words = (config->block_size + 63) / 64;
  int first_row_word_count = config->row_blocks * config->col_blocks * block_words;
  uint64_t *first_rows = checked_calloc((size_t)first_row_word_count, sizeof(uint64_t));
  uint8_t *message_bits = checked_calloc((size_t)config->info_length, sizeof(uint8_t));
  uint8_t *codeword_bits = checked_calloc((size_t)config->transmitted_length, sizeof(uint8_t));
  char message_path[256];
  char codeword_path[256];

  load_first_rows(config, first_rows, block_words);
  build_message(config, message_bits);
  build_codeword(config, message_bits, first_rows, codeword_bits);

  snprintf(message_path, sizeof(message_path), "message_ldpc_encoder_%s.txt", config->suffix);
  snprintf(codeword_path, sizeof(codeword_path), "encoded_frame_ldpc_encoder_%s.txt", config->suffix);
  write_rom_package(config, first_rows);
  write_bit_file(message_path, message_bits, config->info_length);
  write_bit_file(codeword_path, codeword_bits, config->transmitted_length);
  write_vhdl_vectors_package(config, message_bits, codeword_bits);

  printf("Generated vectors for %s\n", config->suffix);

  free(first_rows);
  free(message_bits);
  free(codeword_bits);
}

int main(int argc, char **argv) {
  size_t index = 0;

  srand((unsigned)time(NULL));

  if (argc == 1) {
    for (index = 0; index < sizeof(C_CONFIGS) / sizeof(C_CONFIGS[0]); ++index) {
      generate_one(&C_CONFIGS[index]);
    }
    return 0;
  }

  for (index = 1; index < (size_t)argc; ++index) {
    const t_config *config = find_config(argv[index]);
    if (config == NULL) {
      fprintf(stderr, "Unknown configuration suffix: %s\n", argv[index]);
      return 1;
    }
    generate_one(config);
  }

  return 0;
}