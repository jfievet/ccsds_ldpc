Plan

Plan: VHDL v7 CCSDS LDPC Offset Min‑Sum Decoder (Rate 1/2 “1k”)
Summary
Implement a synthesizable VHDL‑2008, fixed‑iteration, layered Offset‑Min‑Sum LDPC decoder matching the reference C behavior, constrained to CCSDS rate 1/2, info_length=1024 with punctured input stream length=2048 (remaining LLRs treated as 0), and output stream length=1024 bits. All work stays under vhdl/version7/, includes a ModelSim compile.do, and uses no VHDL variables (signals only).

Key Implementation Changes
Top-level decoder

Create an entity offset_min_sum_decoder with the required ports: clk_i, rst_i, data_i(5 downto 0), data_valid_i, data_start_i, iter_cfg_i, data_o, data_valid_o, data_start_o.
Define fixed code parameters (as generics/constants inside the design):
FULL_N = 2560 variable nodes (VN) (decoder internal LLR RAM depth).
IN_N = 2048 streamed LLRs; VN indices [2048..2559] initialized to 0 at frame load.
OUT_N = 1024 streamed hard decisions (information bits).
M = 1536 check nodes (rows of H) and ROW_MAX_DEG = 6 (since design must read up to 6 VNs/cycle).
Interpret iter_cfg_i as the exact fixed iteration count (no syndrome early stop).
Quantized OMS datapath (matches C “layered OMS” structure)

Treat data_i as signed 6-bit LLR in “message units” with saturation range [-31..31].
Use an OFFSET_Q VHDL generic integer (your choice via user input) applied as:
min1 = max(min1 - OFFSET_Q, 0), min2 = max(min2 - OFFSET_Q, 0) with clamp to qmax=31.
Per check-node row (layer), perform two logical passes like the C code:
Compute v2c = llr[vn] - cn_msg[e], track min1, min2, min1_edge, and sign_product (XOR of signs).
For each edge: pick magnitude (min2 for min1_edge else min1), compute sign (sign_product XOR (v2c<0)), write cn_msg[e], and update llr[vn] = clamp(llr[vn] - old_msg + new_msg).
Implement with signals-only style:
Use explicit combinational blocks + registered stages; avoid process variables and avoid functions/procedures that declare variables.
Use fixed-width signed arithmetic (e.g., signed(5 downto 0) for messages, wider for internal subtract/add) with explicit saturation logic.
Memory architecture (3 TDP RAMs + 3 TDP ROMs)

VN storage: 3 true dual‑port RAM instances, arranged to support 6 VN reads/cycle:
Use 2 read ports per RAM to fetch up to 6 llr[vn] values for the current row in one cycle.
Decide a deterministic VN-to-RAM banking scheme and ensure both ports can address independent VN indices each cycle.
CN message storage:
Store cn_msg for each edge as RAM(s) indexed by (row, edge_in_row) with fixed ROW_MAX_DEG=6 so addressing is simple and row-local.
Since ROM provides up to 6 VN indices per row, store 6 CN messages per row (unused entries held at 0).
Row adjacency ROMs:
Generate 3 ROMs, each providing two VN indices per row (total 6). If a row has <6 edges, unused indices are 0.
VN indices in ROM are 1-based (as required); hardware converts idx==0 => “skip”, else vn = idx-1.
H-row ROM generation tool (kept inside vhdl/version7/)

Add a small C utility (e.g., tools/gen_h_rows.c) that reads c/build_h/H_1_2_1024.mat and emits:
A VHDL package or .mem/.hex init files for the 3 ROMs (one line per row).
Enforce: per row output exactly 6 indices (pad with 0), and indices are 1-based.
The build flow uses the existing matrix file in c/build_h/ as input but does not modify anything outside vhdl/version7/.
Control / framing

Input load:
On data_start_i, begin loading a frame: write 2048 incoming LLRs sequentially into VN RAM(s); then implicitly set remaining 512 VNs to 0.
Track in_count; ignore data_valid_i cycles outside load.
Decode run:
After load completes, run iter_cfg_i iterations over all M=1536 rows.
Schedule per-row operations so 6 VNs are fetched, min1/min2/sign computed, CN messages updated, and VN LLRs updated deterministically.
Output:
After decoding, stream out 1024 hard decisions (bit = 1 if llr<0, else 0) with data_start_o asserted on first bit and data_valid_o during the burst.
Reusable AMD-friendly TDP RAM/ROM primitives

Add parameterizable TDP RAM module based on the provided AMD model, generalized with generics for depth and width.
Add TDP ROM module (read-only) using a similar dual-read interface and init from generated contents.
ModelSim simulation + compile.do

Create a single vhdl/version7/sim/compile.do that:
Compiles src/ and tb/ VHDL (VHDL‑2008 flags enabled).
Runs the testbench to completion and exits with failure on mismatch.
Testbench strategy:
Use LLR dumps from c/qpsk_awgn_ldpc_chain (6-bit quantized) as stimulus, or generate a small deterministic vector set inside TB.
Compare the first 1024 output bits against a golden reference produced by running the C decoder on the same inputs (golden files stored under vhdl/version7/tb/vectors/).
Test Plan (Acceptance)
Compile/run in ModelSim via vhdl/version7/sim/compile.do with VHDL‑2008 enabled.
TB cases:
1 frame: all-zero LLRs (expect all-zero output).
1–3 frames from real AWGN LLR dumps (6-bit) with known golden outputs for 1024 bits.
Iteration sweep: at least 2 different iter_cfg_i values to ensure fixed-iteration behavior.
Row padding correctness: confirm rows with <6 neighbors correctly skip idx=0 entries (no spurious reads/writes).
Assumptions / Defaults (locked)
Only vhdl/version7/ is created/modified; nothing outside is touched.
No syndrome check / early stop in hardware.
data_i is signed 6-bit in the same “q units” used internally (no floating scaling).
OFFSET_Q is a VHDL generic integer (not a port), and iter_cfg_i is the direct iteration count.
Input provides 2048 LLRs per frame; VN[2048..2559] are treated as 0 without being streamed in.