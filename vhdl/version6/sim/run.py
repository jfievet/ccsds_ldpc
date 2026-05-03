from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent / "../"

VU = VUnit.from_argv()
VU.add_vhdl_builtins()

LIB = VU.library("vunit_lib")
LIB.add_source_files(ROOT / "src" / "*.vhd")
LIB.add_source_files(ROOT / "tb" / "ldpc_encoder_*_vectors_pkg.vhd")
LIB.add_source_files(ROOT / "tb" / "tb_vunit_ldpc_encoder_*.vhd")

VU.set_sim_option("modelsim.vsim_flags", ["-voptargs=\"+acc\""])
VU.main()
