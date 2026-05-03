from __future__ import annotations

import argparse
from pathlib import Path


ROW_BLOCKS = 8
COL_BLOCKS = 8
BLOCK_SIZE = 128
INFO_LENGTH = 1024
TRANSMITTED_PARITY_LENGTH = 1024
TOTAL_COLUMNS = 2560
TOTAL_ROWS = 1024


def load_octave_sparse_text_mat(path: Path) -> list[set[int]]:
    rows = -1
    cols = -1
    nnz_expected = -1
    nnz_loaded = 0
    variable_name = None
    row_sets: list[set[int]] | None = None

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
                row_sets = [set() for _ in range(rows)]
                continue
            if line.startswith("#"):
                continue
            if row_sets is None:
                raise ValueError("matrix entries were seen before dimensions were parsed")

            row_text, col_text, value_text = line.split()
            row_index = int(row_text) - 1
            col_index = int(col_text) - 1
            value = int(value_text)
            if value:
                row_sets[row_index].add(col_index)
                nnz_loaded += 1

    if variable_name != "G":
        raise ValueError(f"expected variable G in {path}, got {variable_name!r}")
    if rows != TOTAL_ROWS or cols != TOTAL_COLUMNS:
        raise ValueError(f"unexpected G dimensions {rows} x {cols}, expected {TOTAL_ROWS} x {TOTAL_COLUMNS}")
    if nnz_expected >= 0 and nnz_expected != nnz_loaded:
        raise ValueError(f"nnz mismatch in {path}: expected {nnz_expected}, loaded {nnz_loaded}")
    assert row_sets is not None
    return row_sets


def bits_to_words(bits: list[int]) -> tuple[int, int]:
    low = 0
    high = 0
    for index, bit in enumerate(bits):
        if bit:
            if index < 64:
                low |= 1 << index
            else:
                high |= 1 << (index - 64)
    return low, high


def extract_block_rows(row_sets: list[set[int]], row_block: int, col_block: int) -> list[list[int]]:
    row_start = row_block * BLOCK_SIZE
    col_start = INFO_LENGTH + col_block * BLOCK_SIZE
    block_rows: list[list[int]] = []

    for local_row in range(BLOCK_SIZE):
        cols = row_sets[row_start + local_row]
        bits = [0] * BLOCK_SIZE
        for local_col in range(BLOCK_SIZE):
            if col_start + local_col in cols:
                bits[local_col] = 1
        block_rows.append(bits)

    return block_rows


def rotate_right(bits: list[int], shift: int) -> list[int]:
    shift %= len(bits)
    if shift == 0:
        return list(bits)
    return bits[-shift:] + bits[:-shift]


def validate_circulant(block_rows: list[list[int]], row_block: int, col_block: int) -> list[int]:
    first_row = block_rows[0]
    for index in range(1, BLOCK_SIZE):
        expected = rotate_right(first_row, index)
        if block_rows[index] != expected:
            raise ValueError(
                f"block ({row_block}, {col_block}) is not circulant at local row {index}"
            )
    return first_row


def emit_header(first_rows: list[list[list[int]]], output_path: Path) -> None:
    lines: list[str] = []
    lines.append("#ifndef QC_ENCODER_CONSTANTS_H")
    lines.append("#define QC_ENCODER_CONSTANTS_H")
    lines.append("")
    lines.append("#include <stdint.h>")
    lines.append("")
    lines.append(f"#define QC_ROW_BLOCKS {ROW_BLOCKS}")
    lines.append(f"#define QC_COL_BLOCKS {COL_BLOCKS}")
    lines.append(f"#define QC_BLOCK_SIZE {BLOCK_SIZE}")
    lines.append(f"#define QC_INFO_LENGTH {INFO_LENGTH}")
    lines.append(f"#define QC_TRANSMITTED_PARITY_LENGTH {TRANSMITTED_PARITY_LENGTH}")
    lines.append("")
    lines.append("static const uint64_t qc_circulant_first_rows[QC_ROW_BLOCKS][QC_COL_BLOCKS][2] = {")
    for row_block in range(ROW_BLOCKS):
        lines.append("    {")
        for col_block in range(COL_BLOCKS):
            low, high = bits_to_words(first_rows[row_block][col_block])
            suffix = "," if col_block + 1 < COL_BLOCKS else ""
            lines.append(
                f"        {{ UINT64_C(0x{low:016x}), UINT64_C(0x{high:016x}) }}{suffix}"
            )
        suffix = "," if row_block + 1 < ROW_BLOCKS else ""
        lines.append(f"    }}{suffix}")
    lines.append("};")
    lines.append("")
    lines.append("#endif")
    lines.append("")
    output_path.write_text("\n".join(lines), encoding="ascii")


def main() -> int:
    parser = argparse.ArgumentParser(description="Derive QC encoder constants from G_1_2_1024.mat")
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("../build_g/G_1_2_1024.mat"),
        help="path to G_1_2_1024.mat",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("qc_encoder_constants.h"),
        help="output header path",
    )
    args = parser.parse_args()

    row_sets = load_octave_sparse_text_mat(args.input)
    first_rows: list[list[list[int]]] = []

    for row_block in range(ROW_BLOCKS):
        current_row: list[list[int]] = []
        for col_block in range(COL_BLOCKS):
            block_rows = extract_block_rows(row_sets, row_block, col_block)
            current_row.append(validate_circulant(block_rows, row_block, col_block))
        first_rows.append(current_row)

    emit_header(first_rows, args.output)
    print(f"Validated {ROW_BLOCKS}x{COL_BLOCKS} circulant blocks from {args.input}")
    print(f"Wrote constants header to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())