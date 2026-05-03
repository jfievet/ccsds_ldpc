from pathlib import Path
import subprocess
from vunit import VUnit

# Paths
ROOT = Path(__file__).parent / "../"

#subprocess.run(["python", str(ROOT / "sim" / "generate_ldpc_artifacts.py")], check=True)

# Call Vunit addons
VU = VUnit.from_argv()
VU.add_vhdl_builtins()

# Source files
LIB = VU.library("vunit_lib")
LIB.add_source_files( ROOT / "src" / "*.vhd")

# Testbench files
LIB.add_source_files( ROOT / "tb" / "tb_vunit_ldpc_encoder_1k_1_2.vhd")

# Modelsim options
VU.set_sim_option('modelsim.init_files.after_load', [str(ROOT / 'sim' / 'wave.do')])
VU.set_sim_option('modelsim.vsim_flags', ["-voptargs=\"+acc\""])

VU.main()