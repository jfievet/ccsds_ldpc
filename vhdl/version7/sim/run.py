from pathlib import Path
from vunit import VUnit

import os
import subprocess
import sys

GCC = r"C:\MinGW\bin\gcc.exe"

def run_or_die(cmd: str) -> None:
    rc = subprocess.call(cmd)
    if rc != 0:
        sys.exit(rc)

ROOT = (Path(__file__).parent / "..").resolve()
os.chdir(ROOT)

run_or_die(
    f'"{GCC}" -O2 -std=c11 -Wall -Wextra tools\\gen_h_rows.c '
    f'-o tools\\gen_h_rows.exe'
)

run_or_die(
    f'"{GCC}" -O2 -std=c11 -Wall -Wextra '
    f'-I ..\\..\\c\\qpsk_awgn_ldpc_chain '
    f'-I ..\\..\\c\\qc_encoder_all '
    f'tools\\gen_vectors.c '
    f'..\\..\\c\\qpsk_awgn_ldpc_chain\\qpsk_chain.c '
    f'..\\..\\c\\qpsk_awgn_ldpc_chain\\ldpc_decoder.c '
    f'..\\..\\c\\qc_encoder_all\\qc_encoder.c '
    f'-o tools\\gen_vectors.exe -lm'
)

run_or_die(r'tools\\gen_h_rows.exe')

run_or_die(
    r'tools\\gen_vectors.exe '
    r'--pattern x83 --ebn0_db 10.0 --llr hard --invert 0'
)

VU = VUnit.from_argv()
VU.add_vhdl_builtins()

LIB = VU.library("vunit_lib")
LIB.add_source_files(ROOT / "src" / "*.vhd")
LIB.add_source_files(ROOT / "tb" / "tb_vunit*.vhd")

LIB.entity("tb_offset_min_sum_decoder").set_generic(
    "vector_dir",
    str((ROOT / "tb" / "vectors").resolve()).replace("\\", "/"),
)

VU.set_sim_option('modelsim.init_files.after_load', [str(ROOT / 'sim' / 'wave.do')])
VU.set_sim_option("modelsim.vsim_flags", ["-voptargs=\"+acc\""])

VU.main()
