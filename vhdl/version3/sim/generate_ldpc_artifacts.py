# python generate_ldpc_artifacts.py --seed 123


from __future__ import annotations

import argparse
import random
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
WORKSPACE_DIR = ROOT_DIR.parents[1]
BUILD_H_DIR = WORKSPACE_DIR / "octave" / "build_h"


@dataclass(frozen=True)
class LdpcConfiguration:
    rate_text: str
    block_length: int
    h_path: Path


@dataclass(frozen=True)
class Constants:
    rate_text: str
    rate_numerator: int
    rate_denominator: int
    block_length: int
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate version2 LDPC artifacts")
    parser.add_argument("--rate", default="1/2", help="CCSDS code rate, for example 1/2")
    parser.add_argument("--block-length", type=int, default=1024, help="CCSDS information block length")
    parser.add_argument("--seed", type=int, default=1, help="Seed used for pseudo-random message generation")
    parser.add_argument(
        "--output-prefix",
        default="ldpc_encoder_1k_1_2",
        help="Prefix used for generated VHDL and vector file names",
    )
    return parser.parse_args()


def discover_configuration(rate_text: str, block_length: int) -> LdpcConfiguration:
    rate_tokens = rate_text.split("/", 1)
    if len(rate_tokens) != 2:
        raise ValueError(f"Expected rate in N/D format, got {rate_text}")

    rate_prefix = f"H_{rate_tokens[0]}_{rate_tokens[1]}_{block_length}.mat"
    h_path = BUILD_H_DIR / rate_prefix
    if not h_path.exists():
        raise FileNotFoundError(f"Could not find {h_path}")

    return LdpcConfiguration(rate_text=rate_text, block_length=block_length, h_path=h_path)


def parse_octave_sparse_rows(path: Path) -> tuple[int, int, list[int]]:
    row_count: int | None = None
    col_count: int | None = None
    rows: list[int] | None = None

    with path.open("r", encoding="ascii") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            if line.startswith("# rows:"):
                row_count = int(line.split(":", 1)[1].strip())
                continue

            if line.startswith("# columns:"):
                col_count = int(line.split(":", 1)[1].strip())
                if row_count is None:
                    raise ValueError(f"Found columns before rows in {path}")
                rows = [0] * row_count
                continue

            if line.startswith("#"):
                continue

            if row_count is None or col_count is None or rows is None:
                raise ValueError(f"Missing header before data in {path}")

            fields = line.split()
            if len(fields) != 3:
                continue

            row_index = int(fields[0]) - 1
            col_index = int(fields[1]) - 1
            value = int(fields[2])
            if value % 2 == 1:
                rows[row_index] |= 1 << col_index

    if row_count is None or col_count is None or rows is None:
        raise ValueError(f"Missing matrix header in {path}")

    return row_count, col_count, rows


def build_mask(start: int, width: int) -> int:
    return ((1 << width) - 1) << start


def extract_dependencies(rows: list[int], start: int, width: int) -> list[list[int]]:
    mask = build_mask(start, width)
    dependencies: list[list[int]] = []
    for row_bits in rows:
        sliced_bits = (row_bits & mask) >> start
        dependencies.append(bit_positions(sliced_bits))
    return dependencies


def bit_positions(bit_vector: int) -> list[int]:
    positions: list[int] = []
    current_bits = bit_vector
    while current_bits != 0:
        lsb = current_bits & -current_bits
        positions.append(lsb.bit_length() - 1)
        current_bits ^= lsb
    return positions


def identity_rows(size: int) -> list[int]:
    rows: list[int] = []
    for row_index in range(size):
        rows.append(1 << row_index)
    return rows


def multiply_rows_by_matrix(left_rows: list[int], right_rows: list[int], width: int) -> list[int]:
    result_rows: list[int] = [0] * len(left_rows)
    mask = (1 << width) - 1
    for row_index, left_row in enumerate(left_rows):
        accumulated = 0
        current_bits = left_row
        while current_bits != 0:
            lsb = current_bits & -current_bits
            source_row = lsb.bit_length() - 1
            accumulated ^= right_rows[source_row]
            current_bits ^= lsb
        result_rows[row_index] = accumulated & mask
    return result_rows


def validate_identity(rows: list[int], identity: list[int], message: str) -> None:
    for row_index, row_bits in enumerate(rows):
        if row_bits != identity[row_index]:
            raise ValueError(message)


def validate_zero(rows: list[int], message: str) -> None:
    for row_bits in rows:
        if row_bits != 0:
            raise ValueError(message)


def build_constants_from_h(configuration: LdpcConfiguration) -> Constants:
    row_count, total_length, matrix_rows = parse_octave_sparse_rows(configuration.h_path)
    if row_count % 3 != 0:
        raise ValueError("Unexpected H size: number of rows must be 3*M")

    m = row_count // 3
    k = total_length - row_count
    n = k + 2 * m
    if configuration.rate_text != "1/2" or configuration.block_length != 1024:
        raise ValueError("Version2 currently supports only the 1k rate-1/2 configuration")
    if k != 1024 or m != 512 or n != 2048:
        raise ValueError(f"Expected 1k 1/2 dimensions, got k={k}, m={m}, n={n}")

    rate_numerator_text, rate_denominator_text = configuration.rate_text.split("/", 1)
    rate_numerator = int(rate_numerator_text)
    rate_denominator = int(rate_denominator_text)

    row_1 = matrix_rows[0:m]
    row_2 = matrix_rows[m : 2 * m]
    row_3 = matrix_rows[2 * m : 3 * m]

    info_start = 0
    parity_1_start = k
    parity_2_start = k + m
    parity_3_start = k + 2 * m

    row_1_info = extract_row_segment(row_1, info_start, k)
    row_1_parity_1 = extract_row_segment(row_1, parity_1_start, m)
    row_1_parity_2 = extract_row_segment(row_1, parity_2_start, m)
    row_2_parity_1 = extract_row_segment(row_2, parity_1_start, m)
    row_2_parity_2 = extract_row_segment(row_2, parity_2_start, m)
    row_3_parity_1 = extract_row_segment(row_3, parity_1_start, m)
    row_3_parity_3 = extract_row_segment(row_3, parity_3_start, m)

    identity_m = identity_rows(m)
    validate_zero(row_1_info, "Unexpected H structure: row-1 information block must be zero")
    validate_identity(row_1_parity_1, identity_m, "Unexpected H structure: row-1 parity_1 block must be identity")
    validate_zero(row_1_parity_2, "Unexpected H structure: row-1 parity_2 block must be zero")
    validate_zero(row_2_parity_1, "Unexpected H structure: row-2 parity_1 block must be zero")
    validate_identity(row_2_parity_2, identity_m, "Unexpected H structure: row-2 parity_2 block must be identity")
    validate_zero(row_3_parity_1, "Unexpected H structure: row-3 parity_1 block must be zero")
    validate_identity(row_3_parity_3, identity_m, "Unexpected H structure: row-3 parity_3 block must be identity")

    matrix_a = extract_row_segment(row_2, info_start, k)
    matrix_b = extract_row_segment(row_3, info_start, k)
    matrix_p1 = extract_row_segment(row_1, parity_3_start, m)
    matrix_s2 = extract_row_segment(row_2, parity_3_start, m)
    matrix_s4 = extract_row_segment(row_3, parity_2_start, m)

    matrix_s4_times_s2 = multiply_rows_by_matrix(matrix_s4, matrix_s2, m)
    matrix_t = [identity_m[row_index] ^ matrix_s4_times_s2[row_index] for row_index in range(m)]

    working_t = list(matrix_t)
    forward_swap_rows = [0] * m
    forward_target_rows: list[list[int]] = [[] for _ in range(m)]
    backward_target_rows: list[list[int]] = [[] for _ in range(m)]

    for pivot in range(m):
        pivot_row = find_pivot_row(working_t, pivot)
        if pivot_row is None:
            raise ValueError("Constant generation failed: singular p3 solve matrix")

        forward_swap_rows[pivot] = pivot_row
        if pivot_row != pivot:
            saved_row = working_t[pivot]
            working_t[pivot] = working_t[pivot_row]
            working_t[pivot_row] = saved_row

        targets: list[int] = []
        for target_row in range(pivot + 1, m):
            if ((working_t[target_row] >> pivot) & 1) == 1:
                working_t[target_row] ^= working_t[pivot]
                targets.append(target_row)
        forward_target_rows[pivot] = targets

    for pivot in range(m - 1, -1, -1):
        targets = []
        for target_row in range(0, pivot):
            if ((working_t[target_row] >> pivot) & 1) == 1:
                working_t[target_row] ^= working_t[pivot]
                targets.append(target_row)
        backward_target_rows[pivot] = targets

    validate_identity(working_t, identity_m, "Elimination schedule failed to reduce the solve matrix to identity")

    return Constants(
        rate_text=configuration.rate_text,
        rate_numerator=rate_numerator,
        rate_denominator=rate_denominator,
        block_length=configuration.block_length,
        k=k,
        m=m,
        n=n,
        total_length=total_length,
        a_dependencies=dependencies_from_rows(matrix_a),
        b_dependencies=dependencies_from_rows(matrix_b),
        p1_dependencies=dependencies_from_rows(matrix_p1),
        s2_dependencies=dependencies_from_rows(matrix_s2),
        s4_dependencies=dependencies_from_rows(matrix_s4),
        forward_swap_rows=forward_swap_rows,
        forward_target_rows=forward_target_rows,
        backward_target_rows=backward_target_rows,
    )


def extract_row_segment(rows: list[int], start: int, width: int) -> list[int]:
    mask = build_mask(start, width)
    segments: list[int] = []
    for row_bits in rows:
        segments.append((row_bits & mask) >> start)
    return segments


def find_pivot_row(rows: list[int], pivot: int) -> int | None:
    for row_index in range(pivot, len(rows)):
        if ((rows[row_index] >> pivot) & 1) == 1:
            return row_index
    return None


def dependencies_from_rows(rows: list[int]) -> list[list[int]]:
    return [bit_positions(row_bits) for row_bits in rows]


def xor_reduce(bit_vector: list[int], indices: list[int]) -> int:
    result = 0
    for index in indices:
        result ^= bit_vector[index]
    return result


def encode_message(message_bits: list[int], constants: Constants) -> list[int]:
    a_times_message = [0] * constants.m
    b_times_message = [0] * constants.m
    parity_1 = [0] * constants.m

    for row_index in range(constants.m):
        a_times_message[row_index] = xor_reduce(message_bits, constants.a_dependencies[row_index])
        b_times_message[row_index] = xor_reduce(message_bits, constants.b_dependencies[row_index])

    rhs = list(b_times_message)
    for row_index in range(constants.m):
        rhs[row_index] ^= xor_reduce(a_times_message, constants.s4_dependencies[row_index])

    parity_3 = list(rhs)
    for pivot in range(constants.m):
        pivot_row = constants.forward_swap_rows[pivot]
        if pivot_row != pivot:
            saved_bit = parity_3[pivot]
            parity_3[pivot] = parity_3[pivot_row]
            parity_3[pivot_row] = saved_bit

        if parity_3[pivot] == 1:
            for target_row in constants.forward_target_rows[pivot]:
                parity_3[target_row] ^= 1

    for pivot in range(constants.m - 1, -1, -1):
        if parity_3[pivot] == 1:
            for target_row in constants.backward_target_rows[pivot]:
                parity_3[target_row] ^= 1

    parity_2 = list(a_times_message)
    for row_index in range(constants.m):
        parity_2[row_index] ^= xor_reduce(parity_3, constants.s2_dependencies[row_index])
        parity_1[row_index] = xor_reduce(parity_3, constants.p1_dependencies[row_index])

    return list(message_bits) + parity_1 + parity_2


def seeded_random_message(length: int, seed: int) -> list[int]:
    generator = random.Random(seed)
    bits: list[int] = []
    for _ in range(length):
        bits.append(generator.getrandbits(1))
    return bits


def flatten_nested(nested: list[list[int]]) -> tuple[list[int], list[int]]:
    offsets = [0]
    values: list[int] = []
    for row in nested:
        values.extend(row)
        offsets.append(len(values))
    return offsets, values


def uint_width(max_value: int) -> int:
    if max_value <= 0:
        return 1
    return max_value.bit_length()


def format_hex_literal(bit_string: str, indent: str = "  ") -> str:
    prefix_length = len(bit_string) % 4
    if prefix_length == 0:
        prefix_bits = ""
        suffix_bits = bit_string
    else:
        prefix_bits = bit_string[:prefix_length]
        suffix_bits = bit_string[prefix_length:]

    chunk_size = 64
    parts: list[str] = []

    if prefix_bits:
        parts.append(f'"{prefix_bits}"')

    if suffix_bits:
        hex_text = format(int(suffix_bits, 2), f"0{len(suffix_bits) // 4}X")
        start_index = 0
        while start_index < len(hex_text):
            end_index = min(start_index + chunk_size, len(hex_text))
            parts.append(f'x"{hex_text[start_index:end_index]}"')
            start_index = end_index

    if not parts:
        return '"0"'
    if len(parts) == 1:
        return parts[0]
    return (" &\n" + indent * 2).join(parts)


def pack_values(values: list[int], width: int) -> str:
    if not values:
        return "0" * width

    pieces: list[str] = []
    for value in reversed(values):
        pieces.append(format(value, f"0{width}b"))
    return "".join(pieces)


def format_packed_constant(name: str, count_name: str, width_name: str, values: list[int], width: int, indent: str = "  ") -> str:
    packed_bits = pack_values(values, width)
    literal_text = format_hex_literal(packed_bits, indent)
    return (
        f"{indent}constant {count_name} : natural := {len(values)};\n"
        f"{indent}constant {name} : std_logic_vector({count_name} * {width_name} - 1 downto 0) :=\n"
        f"{indent * 2}{literal_text};\n\n"
    )


def write_vhdl_package(package_name: str, body: str, output_path: Path, use_config: bool) -> None:
    header = "library ieee;\nuse ieee.std_logic_1164.all;\n"
    if use_config:
        header += f"\nuse work.{package_name.replace('_a_tables_pkg', '_config_pkg').replace('_b_tables_pkg', '_config_pkg').replace('_parity_tables_pkg', '_config_pkg').replace('_solver_tables_pkg', '_config_pkg')}.all;\n"
    package_text = f"{header}\npackage {package_name} is\n{body}end package {package_name};\n"
    output_path.write_text(package_text, encoding="ascii")


def write_values_rom(
        output_path: Path,
        entity_name: str,
        config_package_name: str,
        data_package_name: str,
        values_count_name: str,
        values_bits_name: str,
        data_width_name: str,
    rom_style: str,
) -> None:
        rom_text = f"""library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.{config_package_name}.all;
use work.{data_package_name}.all;

entity {entity_name} is
    port (
        clock_i   : in  std_logic;
        rd_en_i   : in  std_logic;
        rd_addr_i : in  std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
        rd_data_o : out std_logic_vector({data_width_name} - 1 downto 0)
    );
end entity {entity_name};

architecture rtl of {entity_name} is
    type rom_t is array (0 to {values_count_name} - 1) of std_logic_vector({data_width_name} - 1 downto 0);

    function unpack_values return rom_t is
        variable data : rom_t;
    begin
        for index in 0 to {values_count_name} - 1 loop
            data(index) := {values_bits_name}((index + 1) * {data_width_name} - 1 downto index * {data_width_name});
        end loop;
        return data;
    end function unpack_values;

    signal rom     : rom_t := unpack_values;
    signal rd_data : std_logic_vector({data_width_name} - 1 downto 0) := (others => '0');

    attribute rom_style : string;
    attribute rom_style of rom : signal is "{rom_style}";
begin
    rd_data_o <= rd_data;

    process (clock_i)
        variable address_index : natural;
    begin
        if rising_edge(clock_i) then
            if rd_en_i = '1' then
                address_index := to_integer(unsigned(rd_addr_i));
                if address_index < {values_count_name} then
                    rd_data <= rom(address_index);
                else
                    rd_data <= (others => '0');
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
"""
        output_path.write_text(rom_text, encoding="ascii")


def write_config_package(
    constants: Constants,
    output_path: Path,
    package_name: str,
    offset_width: int,
    message_index_width: int,
    codeword_index_width: int,
    parity_row_width: int,
) -> None:
    body = (
        f"  constant LDPC_RATE_NUMERATOR : natural := {constants.rate_numerator};\n"
        f"  constant LDPC_RATE_DENOMINATOR : natural := {constants.rate_denominator};\n"
        f"  constant LDPC_BLOCK_SIZE : natural := {constants.block_length};\n"
        f"  constant LDPC_K : natural := {constants.k};\n"
        f"  constant LDPC_M : natural := {constants.m};\n"
        f"  constant LDPC_N : natural := {constants.n};\n"
        f"  constant LDPC_TOTAL_LENGTH : natural := {constants.total_length};\n"
        f"  constant LDPC_OFFSET_WIDTH : natural := {offset_width};\n"
        f"  constant LDPC_MESSAGE_INDEX_WIDTH : natural := {message_index_width};\n"
        f"  constant LDPC_CODEWORD_INDEX_WIDTH : natural := {codeword_index_width};\n"
        f"  constant LDPC_ROW_INDEX_WIDTH : natural := {parity_row_width};\n"
    )
    write_vhdl_package(package_name, body, output_path, False)


def write_split_vhdl_tables(constants: Constants, output_dir: Path, output_prefix: str) -> list[Path]:
    a_offsets, a_values = flatten_nested(constants.a_dependencies)
    b_offsets, b_values = flatten_nested(constants.b_dependencies)
    p1_offsets, p1_values = flatten_nested(constants.p1_dependencies)
    s2_offsets, s2_values = flatten_nested(constants.s2_dependencies)
    s4_offsets, s4_values = flatten_nested(constants.s4_dependencies)
    fwd_offsets, fwd_values = flatten_nested(constants.forward_target_rows)
    bwd_offsets, bwd_values = flatten_nested(constants.backward_target_rows)

    offset_width = uint_width(max(len(a_values), len(b_values), len(p1_values), len(s2_values), len(s4_values), len(fwd_values), len(bwd_values)))
    message_index_width = uint_width(constants.k - 1)
    codeword_index_width = uint_width(constants.n - 1)
    parity_row_width = uint_width(constants.m - 1)

    config_package = f"{output_prefix}_config_pkg"
    package_paths = [
        output_dir / f"{output_prefix}_config_pkg.vhd",
        output_dir / f"{output_prefix}_a_tables_pkg.vhd",
        output_dir / f"{output_prefix}_b_tables_pkg.vhd",
        output_dir / f"{output_prefix}_parity_tables_pkg.vhd",
        output_dir / f"{output_prefix}_solver_tables_pkg.vhd",
    ]
    rom_paths = [
        output_dir / "ldpc_a_dep_values_rom.vhd",
        output_dir / "ldpc_b_dep_values_rom.vhd",
        output_dir / "ldpc_p1_dep_values_rom.vhd",
        output_dir / "ldpc_s2_dep_values_rom.vhd",
        output_dir / "ldpc_s4_dep_values_rom.vhd",
        output_dir / "ldpc_fwd_target_values_rom.vhd",
        output_dir / "ldpc_bwd_target_values_rom.vhd",
    ]

    write_config_package(constants, package_paths[0], config_package, offset_width, message_index_width, codeword_index_width, parity_row_width)

    a_body = "".join(
        [
            format_packed_constant("A_DEP_OFFSETS_BITS", "A_DEP_OFFSETS_COUNT", "LDPC_OFFSET_WIDTH", a_offsets, offset_width),
            format_packed_constant("A_DEP_VALUES_BITS", "A_DEP_VALUES_COUNT", "LDPC_MESSAGE_INDEX_WIDTH", a_values, message_index_width),
        ]
    )
    write_vhdl_package(f"{output_prefix}_a_tables_pkg", a_body, package_paths[1], True)

    b_body = "".join(
        [
            format_packed_constant("B_DEP_OFFSETS_BITS", "B_DEP_OFFSETS_COUNT", "LDPC_OFFSET_WIDTH", b_offsets, offset_width),
            format_packed_constant("B_DEP_VALUES_BITS", "B_DEP_VALUES_COUNT", "LDPC_MESSAGE_INDEX_WIDTH", b_values, message_index_width),
        ]
    )
    write_vhdl_package(f"{output_prefix}_b_tables_pkg", b_body, package_paths[2], True)

    parity_body = "".join(
        [
            format_packed_constant("P1_DEP_OFFSETS_BITS", "P1_DEP_OFFSETS_COUNT", "LDPC_OFFSET_WIDTH", p1_offsets, offset_width),
            format_packed_constant("P1_DEP_VALUES_BITS", "P1_DEP_VALUES_COUNT", "LDPC_ROW_INDEX_WIDTH", p1_values, parity_row_width),
            format_packed_constant("S2_DEP_OFFSETS_BITS", "S2_DEP_OFFSETS_COUNT", "LDPC_OFFSET_WIDTH", s2_offsets, offset_width),
            format_packed_constant("S2_DEP_VALUES_BITS", "S2_DEP_VALUES_COUNT", "LDPC_ROW_INDEX_WIDTH", s2_values, parity_row_width),
            format_packed_constant("S4_DEP_OFFSETS_BITS", "S4_DEP_OFFSETS_COUNT", "LDPC_OFFSET_WIDTH", s4_offsets, offset_width),
            format_packed_constant("S4_DEP_VALUES_BITS", "S4_DEP_VALUES_COUNT", "LDPC_ROW_INDEX_WIDTH", s4_values, parity_row_width),
        ]
    )
    write_vhdl_package(f"{output_prefix}_parity_tables_pkg", parity_body, package_paths[3], True)

    solver_body = "".join(
        [
            format_packed_constant("FWD_SWAP_ROWS_BITS", "FWD_SWAP_ROWS_COUNT", "LDPC_ROW_INDEX_WIDTH", constants.forward_swap_rows, parity_row_width),
            format_packed_constant("FWD_TARGET_OFFSETS_BITS", "FWD_TARGET_OFFSETS_COUNT", "LDPC_OFFSET_WIDTH", fwd_offsets, offset_width),
            format_packed_constant("FWD_TARGET_VALUES_BITS", "FWD_TARGET_VALUES_COUNT", "LDPC_ROW_INDEX_WIDTH", fwd_values, parity_row_width),
            format_packed_constant("BWD_TARGET_OFFSETS_BITS", "BWD_TARGET_OFFSETS_COUNT", "LDPC_OFFSET_WIDTH", bwd_offsets, offset_width),
            format_packed_constant("BWD_TARGET_VALUES_BITS", "BWD_TARGET_VALUES_COUNT", "LDPC_ROW_INDEX_WIDTH", bwd_values, parity_row_width),
        ]
    )
    write_vhdl_package(f"{output_prefix}_solver_tables_pkg", solver_body, package_paths[4], True)

    config_package_name = f"{output_prefix}_config_pkg"
    write_values_rom(
        rom_paths[0],
        "ldpc_a_dep_values_rom",
        config_package_name,
        f"{output_prefix}_a_tables_pkg",
        "A_DEP_VALUES_COUNT",
        "A_DEP_VALUES_BITS",
        "LDPC_MESSAGE_INDEX_WIDTH",
        "distributed",
    )
    write_values_rom(
        rom_paths[1],
        "ldpc_b_dep_values_rom",
        config_package_name,
        f"{output_prefix}_b_tables_pkg",
        "B_DEP_VALUES_COUNT",
        "B_DEP_VALUES_BITS",
        "LDPC_MESSAGE_INDEX_WIDTH",
        "distributed",
    )
    write_values_rom(
        rom_paths[2],
        "ldpc_p1_dep_values_rom",
        config_package_name,
        f"{output_prefix}_parity_tables_pkg",
        "P1_DEP_VALUES_COUNT",
        "P1_DEP_VALUES_BITS",
        "LDPC_ROW_INDEX_WIDTH",
        "distributed",
    )
    write_values_rom(
        rom_paths[3],
        "ldpc_s2_dep_values_rom",
        config_package_name,
        f"{output_prefix}_parity_tables_pkg",
        "S2_DEP_VALUES_COUNT",
        "S2_DEP_VALUES_BITS",
        "LDPC_ROW_INDEX_WIDTH",
        "distributed",
    )
    write_values_rom(
        rom_paths[4],
        "ldpc_s4_dep_values_rom",
        config_package_name,
        f"{output_prefix}_parity_tables_pkg",
        "S4_DEP_VALUES_COUNT",
        "S4_DEP_VALUES_BITS",
        "LDPC_ROW_INDEX_WIDTH",
        "distributed",
    )
    write_values_rom(
        rom_paths[5],
        "ldpc_fwd_target_values_rom",
        config_package_name,
        f"{output_prefix}_solver_tables_pkg",
        "FWD_TARGET_VALUES_COUNT",
        "FWD_TARGET_VALUES_BITS",
        "LDPC_ROW_INDEX_WIDTH",
        "block",
    )
    write_values_rom(
        rom_paths[6],
        "ldpc_bwd_target_values_rom",
        config_package_name,
        f"{output_prefix}_solver_tables_pkg",
        "BWD_TARGET_VALUES_COUNT",
        "BWD_TARGET_VALUES_BITS",
        "LDPC_ROW_INDEX_WIDTH",
        "block",
    )

    legacy_package = output_dir / f"{output_prefix}_tables_pkg.vhd"
    if legacy_package.exists():
        legacy_package.unlink()

    return package_paths + rom_paths


def write_bit_file(path: Path, bits: list[int]) -> None:
    path.write_text("\n".join(str(bit) for bit in bits) + "\n", encoding="ascii")


def main() -> None:
    args = parse_args()
    configuration = discover_configuration(args.rate, args.block_length)
    constants = build_constants_from_h(configuration)
    message_bits = seeded_random_message(constants.k, args.seed)
    codeword_bits = encode_message(message_bits, constants)

    output_dir = ROOT_DIR / "src"
    output_message = ROOT_DIR / "sim" / f"message_{args.output_prefix}.txt"
    output_frame = ROOT_DIR / "sim" / f"encoded_frame_{args.output_prefix}.txt"

    output_dir.mkdir(parents=True, exist_ok=True)
    output_message.parent.mkdir(parents=True, exist_ok=True)
    output_frame.parent.mkdir(parents=True, exist_ok=True)

    output_packages = write_split_vhdl_tables(constants, output_dir, args.output_prefix)
    write_bit_file(output_message, message_bits)
    write_bit_file(output_frame, codeword_bits)

    for output_package in output_packages:
        print(f"Generated {output_package}")
    print(f"Generated {output_message}")
    print(f"Generated {output_frame}")
    print(
        f"rate={constants.rate_text} block_length={constants.block_length} "
        f"k={constants.k} m={constants.m} n={constants.n} total={constants.total_length} seed={args.seed}"
    )


if __name__ == "__main__":
    main()