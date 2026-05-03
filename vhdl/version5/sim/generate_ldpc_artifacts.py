from __future__ import annotations

import re
import shutil
from pathlib import Path


ROW_BLOCKS = 8
COL_BLOCKS = 8
BLOCK_SIZE = 128


def load_qc_rows(header_path: Path) -> list[list[str]]:
    header_text = header_path.read_text(encoding="ascii")
    pairs = re.findall(r"UINT64_C\(0x([0-9a-fA-F]{16})\),\s*UINT64_C\(0x([0-9a-fA-F]{16})\)", header_text)
    if len(pairs) != ROW_BLOCKS * COL_BLOCKS:
        raise ValueError(f"expected {ROW_BLOCKS * COL_BLOCKS} constant pairs, found {len(pairs)}")

    rows: list[list[str]] = []
    pair_index = 0
    for _row_block in range(ROW_BLOCKS):
        row_entries: list[str] = []
        for _col_block in range(COL_BLOCKS):
            low_text, high_text = pairs[pair_index]
            low_value = int(low_text, 16)
            high_value = int(high_text, 16)
            bits = []
            for bit_index in range(63, -1, -1):
                bits.append("1" if ((high_value >> bit_index) & 1) != 0 else "0")
            for bit_index in range(63, -1, -1):
                bits.append("1" if ((low_value >> bit_index) & 1) != 0 else "0")
            row_entries.append("".join(bits))
            pair_index += 1
        rows.append(row_entries)
    return rows


def emit_qc_rom_package(rows: list[list[str]], output_path: Path) -> None:
    transposed = [[rows[row_index][col_index] for row_index in range(ROW_BLOCKS)] for col_index in range(COL_BLOCKS)]
    lines: list[str] = []
    lines.append("library ieee;")
    lines.append("use ieee.std_logic_1164.all;")
    lines.append("")
    lines.append("library work;")
    lines.append("use work.ldpc_encoder_1k_1_2_config_pkg.all;")
    lines.append("")
    lines.append("package ldpc_encoder_1k_1_2_qc_rom_pkg is")
    lines.append("  type t_ldpc_rom is array (0 to LDPC_QC_ROW_BLOCKS - 1) of t_ldpc_block;")
    lines.append("  type t_ldpc_rom_bank is array (0 to LDPC_QC_COL_BLOCKS - 1) of t_ldpc_rom;")
    lines.append("  constant C_LDPC_QC_ROM_BANK : t_ldpc_rom_bank := (")
    for col_index in range(COL_BLOCKS):
        lines.append(f"    {col_index} => (")
        for row_index in range(ROW_BLOCKS):
            suffix = "," if row_index + 1 < ROW_BLOCKS else ""
            lines.append(f"      {row_index} => \"{transposed[col_index][row_index]}\"{suffix}")
        suffix = "," if col_index + 1 < COL_BLOCKS else ""
        lines.append(f"    ){suffix}")
    lines.append("  );")
    lines.append("end package ldpc_encoder_1k_1_2_qc_rom_pkg;")
    lines.append("")
    output_path.write_text("\n".join(lines), encoding="ascii")


def copy_reference_vectors(repo_root: Path, sim_dir: Path) -> None:
    source_dir = repo_root / "vhdl" / "version3" / "sim"
    for file_name in ("message_ldpc_encoder_1k_1_2.txt", "encoded_frame_ldpc_encoder_1k_1_2.txt"):
        shutil.copyfile(source_dir / file_name, sim_dir / file_name)


def main() -> int:
    sim_dir = Path(__file__).resolve().parent
    version_dir = sim_dir.parent
    repo_root = version_dir.parent.parent
    header_path = repo_root / "c" / "qc_encoder_12_1024" / "qc_encoder_constants.h"
    rom_pkg_path = version_dir / "src" / "ldpc_encoder_1k_1_2_qc_rom_pkg.vhd"

    rows = load_qc_rows(header_path)
    emit_qc_rom_package(rows, rom_pkg_path)
    copy_reference_vectors(repo_root, sim_dir)

    print(f"Generated {rom_pkg_path.name} from {header_path}")
    print("Copied reference message/codeword vectors into version5/sim")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())