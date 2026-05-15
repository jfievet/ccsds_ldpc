from pathlib import Path
from vunit import VUnit

import os

import os

GCC = r"C:\MinGW\bin\gcc.exe"

os.system(
    f'"{GCC}" -O2 -std=c11 -Wall -Wextra ..\\tools\\gen_h_rows.c '
    f'-o ..\\tools\\gen_h_rows.exe'
)

os.system(r'..\tools\gen_h_rows.exe')

os.system(
    r'..\tools\gen_vectors.exe '
    r'--pattern x83 --ebn0_db 10.0 --llr hard --invert 0'
)

ROOT = Path(__file__).parent / "../"

VU = VUnit.from_argv()
VU.add_vhdl_builtins()

LIB = VU.library("vunit_lib")
LIB.add_source_files(ROOT / "src" / "*.vhd")
LIB.add_source_files(ROOT / "tb" / "tb_vunit*.vhd")

VU.set_sim_option('modelsim.init_files.after_load', [str(ROOT / 'sim' / 'wave.do')])
VU.set_sim_option("modelsim.vsim_flags", ["-voptargs=\"+acc\""])

VU.main()
