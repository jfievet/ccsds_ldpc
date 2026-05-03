from __future__ import annotations

from pathlib import Path


CONFIGS = [
    {
        "selection": 1,
        "name": "rate_1_2_1k",
        "g_path": "../build_g/G_1_2_1024.mat",
        "info_length": 1024,
        "transmitted_length": 2048,
        "full_length": 2560,
        "row_blocks": 8,
        "col_blocks": 8,
        "block_size": 128,
    },
    {
        "selection": 2,
        "name": "rate_1_2_4k",
        "g_path": "../build_g/G_1_2_4096.mat",
        "info_length": 4096,
        "transmitted_length": 8192,
        "full_length": 10240,
        "row_blocks": 8,
        "col_blocks": 8,
        "block_size": 512,
    },
    {
        "selection": 3,
        "name": "rate_1_2_16k",
        "g_path": "../build_g/G_1_2_16384.mat",
        "info_length": 16384,
        "transmitted_length": 32768,
        "full_length": 40960,
        "row_blocks": 8,
        "col_blocks": 8,
        "block_size": 2048,
    },
    {
        "selection": 4,
        "name": "rate_2_3_1k",
        "g_path": "../build_g/G_2_3_1024.mat",
        "info_length": 1024,
        "transmitted_length": 1536,
        "full_length": 1792,
        "row_blocks": 16,
        "col_blocks": 8,
        "block_size": 64,
    },
    {
        "selection": 5,
        "name": "rate_2_3_4k",
        "g_path": "../build_g/G_2_3_4096.mat",
        "info_length": 4096,
        "transmitted_length": 6144,
        "full_length": 7168,
        "row_blocks": 16,
        "col_blocks": 8,
        "block_size": 256,
    },
    {
        "selection": 6,
        "name": "rate_2_3_16k",
        "g_path": "../build_g/G_2_3_16384.mat",
        "info_length": 16384,
        "transmitted_length": 24576,
        "full_length": 28672,
        "row_blocks": 16,
        "col_blocks": 8,
        "block_size": 1024,
    },
    {
        "selection": 7,
        "name": "rate_4_5_1k",
        "g_path": "../build_g/G_4_5_1024.mat",
        "info_length": 1024,
        "transmitted_length": 1280,
        "full_length": 1408,
        "row_blocks": 32,
        "col_blocks": 8,
        "block_size": 32,
    },
    {
        "selection": 8,
        "name": "rate_4_5_4k",
        "g_path": "../build_g/G_4_5_4096.mat",
        "info_length": 4096,
        "transmitted_length": 5120,
        "full_length": 5632,
        "row_blocks": 32,
        "col_blocks": 8,
        "block_size": 128,
    },
    {
        "selection": 9,
        "name": "rate_4_5_16k",
        "g_path": "../build_g/G_4_5_16384.mat",
        "info_length": 16384,
        "transmitted_length": 20480,
        "full_length": 22528,
        "row_blocks": 32,
        "col_blocks": 8,
        "block_size": 512,
    },
]

SUPPORTED_SELECTIONS = {1, 2, 4, 5, 7, 8}


def load_octave_sparse_text_mat(
    path: Path,
    expected_rows: int,
    expected_cols: int,
    info_length: int,
    transmitted_length: int,
    col_blocks: int,
    block_size: int,
) -> list[list[int]]:
    rows = -1
    cols = -1
    nnz_expected = -1
    nnz_loaded = 0
    variable_name = None
    target_rows = {row_block * block_size for row_block in range(expected_rows // block_size)}
    block_rows: list[list[int]] | None = None

    with path.open("r", encoding="ascii") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith("# name:"):
                variable_name = line.split(":", 1)[1].strip()
                continue
            if line.startswith("# type:"):
                if "sparse matrix" not in line:
                    raise ValueError(f"{path} is not a sparse matrix file")
                continue
            if line.startswith("# nnz:"):
                nnz_expected = int(line.split(":", 1)[1].strip())
                continue
            if line.startswith("# rows:"):
                rows = int(line.split(":", 1)[1].strip())
                continue
            if line.startswith("# columns:"):
                cols = int(line.split(":", 1)[1].strip())
                block_rows = [[0] * col_blocks for _ in range(rows)]
                continue
            if line.startswith("#"):
                continue
            if block_rows is None:
                raise ValueError("matrix entries were seen before dimensions were parsed")

            row_text, col_text, value_text = line.split()
            row_index = int(row_text) - 1
            col_index = int(col_text) - 1
            value = int(value_text)
            if value:
                nnz_loaded += 1
                if row_index in target_rows and info_length <= col_index < transmitted_length:
                    transmitted_col = col_index - info_length
                    col_block = transmitted_col // block_size
                    bit_index = transmitted_col % block_size
                    block_rows[row_index][col_block] |= 1 << bit_index

    if variable_name != "G":
        raise ValueError(f"expected variable G in {path}, got {variable_name!r}")
    if rows != expected_rows or cols != expected_cols:
        raise ValueError(f"unexpected G dimensions {rows} x {cols}, expected {expected_rows} x {expected_cols}")
    if nnz_expected >= 0 and nnz_expected != nnz_loaded:
        raise ValueError(f"nnz mismatch in {path}: expected {nnz_expected}, loaded {nnz_loaded}")
    assert block_rows is not None
    return block_rows


def rotate_first_row_bits(first_row_bits: int, shift: int, block_size: int) -> int:
    mask = (1 << block_size) - 1
    shift %= block_size
    if shift == 0:
        return first_row_bits & mask
    return ((first_row_bits << shift) | (first_row_bits >> (block_size - shift))) & mask


def validate_circulant(
    block_rows: list[list[int]],
    block_size: int,
    row_block: int,
    col_block: int,
) -> int:
    row_start = row_block * block_size
    first_row_bits = block_rows[row_start][col_block]
    return first_row_bits


def bits_to_words(bits_value: int, block_words: int) -> list[int]:
    words = [0] * block_words
    for word_index in range(block_words):
        words[word_index] = (bits_value >> (word_index * 64)) & ((1 << 64) - 1)
    return words


def emit_header(config_rows: list[tuple[dict[str, int | str], list[int]]], output_path: Path) -> None:
    lines: list[str] = []
    lines.append("#ifndef QC_ENCODER_CONSTANTS_H")
    lines.append("#define QC_ENCODER_CONSTANTS_H")
    lines.append("")
    lines.append("#include <stdint.h>")
    lines.append("")

    for config, flat_words in config_rows:
        selection = int(config["selection"])
        lines.append(
            f"static const uint64_t qc_circulant_first_rows_cfg_{selection}[] = {{"
        )
        for index, word in enumerate(flat_words):
            suffix = "," if index + 1 < len(flat_words) else ""
            lines.append(f"    UINT64_C(0x{word:016x}){suffix}")
        lines.append("};")
        lines.append("")

    lines.append("static const qc_encoder_config k_qc_encoder_configs[] = {")
    for config, _flat_words in config_rows:
        selection = int(config["selection"])
        transmitted_length = int(config["transmitted_length"])
        info_length = int(config["info_length"])
        transmitted_parity_length = transmitted_length - info_length
        block_words = (int(config["block_size"]) + 63) // 64
        lines.append("    {")
        lines.append(f"        {selection},")
        lines.append(f"        \"{config['name']}\",")
        lines.append(f"        \"{config['g_path']}\",")
        lines.append(f"        {info_length},")
        lines.append(f"        {transmitted_length},")
        lines.append(f"        {int(config['full_length'])},")
        lines.append(f"        {int(config['row_blocks'])},")
        lines.append(f"        {int(config['col_blocks'])},")
        lines.append(f"        {int(config['block_size'])},")
        lines.append(f"        {block_words},")
        lines.append(f"        {transmitted_parity_length},")
        lines.append(f"        qc_circulant_first_rows_cfg_{selection}")
        lines.append("    },")
    lines.append("};")
    lines.append("")
    lines.append(
        "static const int k_qc_encoder_config_count = (int)(sizeof(k_qc_encoder_configs) / sizeof(k_qc_encoder_configs[0]));"
    )
    lines.append("")
    lines.append("#endif")
    lines.append("")
    output_path.write_text("\n".join(lines), encoding="ascii")


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    config_rows: list[tuple[dict[str, int | str], list[int]]] = []

    for config in CONFIGS:
        if int(config["selection"]) not in SUPPORTED_SELECTIONS:
            continue
        info_length = int(config["info_length"])
        transmitted_length = int(config["transmitted_length"])
        full_length = int(config["full_length"])
        row_blocks = int(config["row_blocks"])
        col_blocks = int(config["col_blocks"])
        block_size = int(config["block_size"])
        block_words = (block_size + 63) // 64

        if row_blocks * block_size != info_length:
            raise ValueError(f"config {config['selection']} has inconsistent row block dimensions")
        if col_blocks * block_size != transmitted_length - info_length:
            raise ValueError(f"config {config['selection']} has inconsistent column block dimensions")

        block_row_values = load_octave_sparse_text_mat(
            script_dir / str(config["g_path"]),
            info_length,
            full_length,
            info_length,
            transmitted_length,
            col_blocks,
            block_size,
        )
        flat_words: list[int] = []
        for row_block in range(row_blocks):
            for col_block in range(col_blocks):
                first_row_bits = validate_circulant(block_row_values, block_size, row_block, col_block)
                flat_words.extend(bits_to_words(first_row_bits, block_words))

        print(
            f"Validated config {config['selection']}: {config['name']} "
            f"({row_blocks}x{col_blocks} blocks, {block_size} bits)"
        )
        config_rows.append((config, flat_words))

    emit_header(config_rows, script_dir / "qc_encoder_constants.h")
    print("Wrote constants header to qc_encoder_constants.h")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())