from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np


ROOT_DIR = Path(__file__).resolve().parents[1]
WORKSPACE_DIR = ROOT_DIR.parents[1]
H_PATH = WORKSPACE_DIR / "octave" / "build_h" / "H_1_2_1024.mat"
OUTPUT_PACKAGE = ROOT_DIR / "src" / "ldpc_encoder_1k_1_2_constants_pkg.vhd"
OUTPUT_MESSAGE = ROOT_DIR / "sim" / "message_1k_1_2.txt"
OUTPUT_FRAME = ROOT_DIR / "sim" / "encoded_frame_1k_1_2.txt"


@dataclass(frozen=True)
class Constants:
    k: int
    m: int
    n: int
    total_length: int
    a_dependencies: list[list[int]]
    b_dependencies: list[list[int]]
    p1_dependencies: list[list[int]]
    s2_dependencies: list[list[int]]
    s4_dependencies: list[list[int]]
    forward_swap_rows: list[int]
    forward_target_rows: list[list[int]]
    backward_target_rows: list[list[int]]


def parse_octave_sparse_matrix(path: Path) -> np.ndarray:
    rows = None
    cols = None
    entries: list[tuple[int, int, int]] = []

    with path.open("r", encoding="ascii") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith("# rows:"):
                rows = int(line.split(":", 1)[1].strip())
                continue
            if line.startswith("# columns:"):
                cols = int(line.split(":", 1)[1].strip())
                continue
            if line.startswith("#"):
                continue

            fields = line.split()
            if len(fields) != 3:
                continue

            row_text, col_text, value_text = fields
            entries.append((int(row_text) - 1, int(col_text) - 1, int(value_text)))

    if rows is None or cols is None:
        raise ValueError(f"Missing matrix dimensions in {path}")

    matrix = np.zeros((rows, cols), dtype=np.bool_)
    for row_index, col_index, value in entries:
        matrix[row_index, col_index] = (value % 2) == 1

    return matrix


def dependency_list(matrix: np.ndarray) -> list[list[int]]:
    return [np.flatnonzero(matrix[row_index]).astype(int).tolist() for row_index in range(matrix.shape[0])]


def build_constants_from_h(matrix_h: np.ndarray) -> Constants:
    parity_equation_count, total_length = matrix_h.shape
    if parity_equation_count % 3 != 0:
        raise ValueError("Unexpected H size: number of rows must be 3*M")

    m = parity_equation_count // 3
    k = total_length - parity_equation_count
    n = k + 2 * m

    if k != 1024 or m != 512 or n != 2048:
        raise ValueError(f"Expected 1k 1/2 dimensions, got k={k}, m={m}, n={n}")

    info_columns = slice(0, k)
    parity_1_columns = slice(k, k + m)
    parity_2_columns = slice(k + m, k + 2 * m)
    parity_3_columns = slice(k + 2 * m, k + 3 * m)

    row_1 = matrix_h[0:m, :]
    row_2 = matrix_h[m : 2 * m, :]
    row_3 = matrix_h[2 * m : 3 * m, :]

    eye_m = np.eye(m, dtype=np.bool_)

    if np.any(row_1[:, info_columns]):
        raise ValueError("Unexpected H structure: row-1 information block must be zero")
    if np.any(np.logical_xor(row_1[:, parity_1_columns], eye_m)):
        raise ValueError("Unexpected H structure: row-1 parity_1 block must be identity")
    if np.any(row_1[:, parity_2_columns]):
        raise ValueError("Unexpected H structure: row-1 parity_2 block must be zero")
    if np.any(row_2[:, parity_1_columns]):
        raise ValueError("Unexpected H structure: row-2 parity_1 block must be zero")
    if np.any(np.logical_xor(row_2[:, parity_2_columns], eye_m)):
        raise ValueError("Unexpected H structure: row-2 parity_2 block must be identity")
    if np.any(row_3[:, parity_1_columns]):
        raise ValueError("Unexpected H structure: row-3 parity_1 block must be zero")
    if np.any(np.logical_xor(row_3[:, parity_3_columns], eye_m)):
        raise ValueError("Unexpected H structure: row-3 parity_3 block must be identity")

    matrix_a = row_2[:, info_columns]
    matrix_b = row_3[:, info_columns]
    matrix_p1 = row_1[:, parity_3_columns]
    matrix_s2 = row_2[:, parity_3_columns]
    matrix_s4 = row_3[:, parity_2_columns]

    matrix_t = np.logical_xor(eye_m, (matrix_s4.astype(np.uint8) @ matrix_s2.astype(np.uint8)) % 2 == 1)
    working_t = matrix_t.copy()

    forward_swap_rows = [0] * m
    forward_target_rows: list[list[int]] = [[] for _ in range(m)]
    backward_target_rows: list[list[int]] = [[] for _ in range(m)]

    for pivot in range(m):
        pivot_candidates = np.flatnonzero(working_t[pivot:, pivot])
        if pivot_candidates.size == 0:
            raise ValueError("Constant generation failed: singular p3 solve matrix")

        pivot_row = pivot + int(pivot_candidates[0])
        forward_swap_rows[pivot] = pivot_row

        if pivot_row != pivot:
            saved_row = working_t[pivot].copy()
            working_t[pivot] = working_t[pivot_row]
            working_t[pivot_row] = saved_row

        target_rows = np.flatnonzero(working_t[pivot + 1 :, pivot]).astype(int) + pivot + 1
        forward_target_rows[pivot] = target_rows.tolist()
        for target_row in forward_target_rows[pivot]:
            working_t[target_row, pivot:] = np.logical_xor(working_t[target_row, pivot:], working_t[pivot, pivot:])

    for pivot in range(m - 1, -1, -1):
        target_rows = np.flatnonzero(working_t[:pivot, pivot]).astype(int)
        backward_target_rows[pivot] = target_rows.tolist()
        for target_row in backward_target_rows[pivot]:
            working_t[target_row, pivot:] = np.logical_xor(working_t[target_row, pivot:], working_t[pivot, pivot:])

    if np.any(np.logical_xor(working_t, eye_m)):
        raise ValueError("Elimination schedule failed to reduce the solve matrix to identity")

    return Constants(
        k=k,
        m=m,
        n=n,
        total_length=total_length,
        a_dependencies=dependency_list(matrix_a),
        b_dependencies=dependency_list(matrix_b),
        p1_dependencies=dependency_list(matrix_p1),
        s2_dependencies=dependency_list(matrix_s2),
        s4_dependencies=dependency_list(matrix_s4),
        forward_swap_rows=forward_swap_rows,
        forward_target_rows=forward_target_rows,
        backward_target_rows=backward_target_rows,
    )


def xor_reduce(bit_vector: np.ndarray, indices: Iterable[int]) -> int:
    result = 0
    for index in indices:
        result ^= int(bit_vector[index])
    return result


def encode_message(message_bits: np.ndarray, constants: Constants) -> np.ndarray:
    a_times_message = np.zeros(constants.m, dtype=np.uint8)
    b_times_message = np.zeros(constants.m, dtype=np.uint8)

    for row_index in range(constants.m):
        a_times_message[row_index] = xor_reduce(message_bits, constants.a_dependencies[row_index])
        b_times_message[row_index] = xor_reduce(message_bits, constants.b_dependencies[row_index])

    rhs = b_times_message.copy()
    for row_index in range(constants.m):
        rhs[row_index] ^= xor_reduce(a_times_message, constants.s4_dependencies[row_index])

    parity_3 = rhs.copy()
    for pivot in range(constants.m):
        pivot_row = constants.forward_swap_rows[pivot]
        if pivot_row != pivot:
            parity_3[pivot], parity_3[pivot_row] = parity_3[pivot_row], parity_3[pivot]

        if parity_3[pivot]:
            for target_row in constants.forward_target_rows[pivot]:
                parity_3[target_row] ^= 1

    for pivot in range(constants.m - 1, -1, -1):
        if parity_3[pivot]:
            for target_row in constants.backward_target_rows[pivot]:
                parity_3[target_row] ^= 1

    parity_2 = a_times_message.copy()
    parity_1 = np.zeros(constants.m, dtype=np.uint8)
    for row_index in range(constants.m):
        parity_2[row_index] ^= xor_reduce(parity_3, constants.s2_dependencies[row_index])
        parity_1[row_index] = xor_reduce(parity_3, constants.p1_dependencies[row_index])

    return np.concatenate((message_bits, parity_1, parity_2)).astype(np.uint8)


def deterministic_message(length: int) -> np.ndarray:
    indices = np.arange(length, dtype=np.uint32)
    pattern = ((indices * 7 + 3) ^ (indices >> 1) ^ (indices >> 3)) & 1
    return pattern.astype(np.uint8)


def flatten_nested(nested: list[list[int]]) -> tuple[list[int], list[int]]:
    offsets = [0]
    values: list[int] = []
    for row in nested:
        values.extend(row)
        offsets.append(len(values))
    return offsets, values


def format_natural_vector(name: str, values: list[int], indent: str = "  ") -> str:
    if not values:
        return f"{indent}constant {name} : natural_vector_t(0 to 0) := (0 => 0);\n"

    lines = [f"{indent}constant {name} : natural_vector_t(0 to {len(values) - 1}) := ("]
    chunk_size = 8
    for start in range(0, len(values), chunk_size):
        chunk = values[start : start + chunk_size]
        assignments = ", ".join(f"{start + offset} => {value}" for offset, value in enumerate(chunk))
        suffix = "," if start + chunk_size < len(values) else ""
        lines.append(f"{indent * 2}{assignments}{suffix}")
    lines.append(f"{indent});\n")
    return "\n".join(lines)


def write_vhdl_package(constants: Constants, path: Path) -> None:
    a_offsets, a_values = flatten_nested(constants.a_dependencies)
    b_offsets, b_values = flatten_nested(constants.b_dependencies)
    p1_offsets, p1_values = flatten_nested(constants.p1_dependencies)
    s2_offsets, s2_values = flatten_nested(constants.s2_dependencies)
    s4_offsets, s4_values = flatten_nested(constants.s4_dependencies)
    fwd_offsets, fwd_values = flatten_nested(constants.forward_target_rows)
    bwd_offsets, bwd_values = flatten_nested(constants.backward_target_rows)

    package_text = """library ieee;
use ieee.std_logic_1164.all;

package ldpc_encoder_1k_1_2_constants_pkg is
  type natural_vector_t is array (natural range <>) of natural;

  constant LDPC_RATE_NUMERATOR : natural := 1;
  constant LDPC_RATE_DENOMINATOR : natural := 2;
  constant LDPC_BLOCK_SIZE : natural := 1024;
  constant LDPC_K : natural := {k};
  constant LDPC_M : natural := {m};
  constant LDPC_N : natural := {n};
  constant LDPC_TOTAL_LENGTH : natural := {total_length};

{body}end package ldpc_encoder_1k_1_2_constants_pkg;
""".format(
        k=constants.k,
        m=constants.m,
        n=constants.n,
        total_length=constants.total_length,
        body="".join(
            [
                format_natural_vector("A_DEP_OFFSETS", a_offsets),
                format_natural_vector("A_DEP_VALUES", a_values),
                format_natural_vector("B_DEP_OFFSETS", b_offsets),
                format_natural_vector("B_DEP_VALUES", b_values),
                format_natural_vector("P1_DEP_OFFSETS", p1_offsets),
                format_natural_vector("P1_DEP_VALUES", p1_values),
                format_natural_vector("S2_DEP_OFFSETS", s2_offsets),
                format_natural_vector("S2_DEP_VALUES", s2_values),
                format_natural_vector("S4_DEP_OFFSETS", s4_offsets),
                format_natural_vector("S4_DEP_VALUES", s4_values),
                format_natural_vector("FWD_SWAP_ROWS", constants.forward_swap_rows),
                format_natural_vector("FWD_TARGET_OFFSETS", fwd_offsets),
                format_natural_vector("FWD_TARGET_VALUES", fwd_values),
                format_natural_vector("BWD_TARGET_OFFSETS", bwd_offsets),
                format_natural_vector("BWD_TARGET_VALUES", bwd_values),
            ]
        ),
    )

    path.write_text(package_text, encoding="ascii")


def write_bit_file(path: Path, bits: np.ndarray) -> None:
    path.write_text("\n".join(str(int(bit)) for bit in bits) + "\n", encoding="ascii")


def main() -> None:
    if not H_PATH.exists():
        raise FileNotFoundError(f"Could not find {H_PATH}")

    matrix_h = parse_octave_sparse_matrix(H_PATH)
    constants = build_constants_from_h(matrix_h)
    message_bits = deterministic_message(constants.k)
    codeword_bits = encode_message(message_bits, constants)

    OUTPUT_PACKAGE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_MESSAGE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FRAME.parent.mkdir(parents=True, exist_ok=True)

    write_vhdl_package(constants, OUTPUT_PACKAGE)
    write_bit_file(OUTPUT_MESSAGE, message_bits)
    write_bit_file(OUTPUT_FRAME, codeword_bits)

    print(f"Generated {OUTPUT_PACKAGE}")
    print(f"Generated {OUTPUT_MESSAGE}")
    print(f"Generated {OUTPUT_FRAME}")
    print(f"k={constants.k}, m={constants.m}, n={constants.n}, total={constants.total_length}")


if __name__ == "__main__":
    main()