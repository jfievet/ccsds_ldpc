Requirements

Overview

In the directory `octave/build_h`, there is the H matrix used to validate an encoded frame.

In the directory `octave/qc_b_encoder`, there is a MATLAB model of the encoder. It is useful as a functional reference and as guidance for an FPGA-oriented architecture.

Goals

Main Goal:

Implement the CCSDS LDPC encoder in VHDL 2008 for FPGA.

The current implementation target is the 1k rate-1/2 case. The code structure shall still allow future extension to other block sizes and code rates.

Real FPGA implementation is required. A simulation-only architecture is not sufficient.

Version4 Performance Goal
The folder version4 is derived from the current version3 implementation.

For version4, treat the existing code in this folder as a legacy baseline to be improved, not as a final architecture.

The new primary goal of version4 is to create a significantly faster LDPC encoder architecture for the CCSDS 1k rate-1/2 case.

The target is an encoding throughput improvement of about x10 to x20 compared to the legacy version3-style implementation, provided that the resulting design remains realistically implementable on FPGA.

A higher resource occupancy is acceptable if it is justified by the throughput improvement and if the architecture remains synthesis-friendly and suitable for real FPGA implementation.

The design may use additional parallelism, deeper pipelining, replicated processing resources, wider internal datapaths, multiple memory banks, or equivalent hardware techniques to achieve the speedup.

The design shall still avoid impractical flat combinational logic and shall remain compatible with FPGA-oriented implementation practices.

Version4 shall reuse useful parts of the legacy design where appropriate, but architectural changes are expected when needed to reach the new performance target.

If the exact x10 or x20 target cannot be reached for every implementation option, the preferred direction is the fastest architecture that remains practical for FPGA synthesis, place and route, and timing closure.

Another aspect: The code shall be sclable to cover all code rates of the CCSDS: 1/2, 2/3, 4/5, 1k, 4k and 16k. But for the moment only focus on 1k 1/2.

Octave / MATLAB / Artifact Generation

Create an Octave or MATLAB function that allows selection of code rate and block size.

This function shall generate VHDL constants for a BRAM memory initialization data that are:

- independent of the message to encode
- generated once per LDPC configuration, not once per frame
- usable by synthesis-friendly VHDL

The generated data shall describe the encoder structure for the selected code, especially for the 1k 1/2 case.

FPGA Architecture Requirements

The VHDL encoder shall use the MATLAB model as a functional reference, but the hardware architecture shall be adapted for real FPGA implementation.

The design shall not rely on a single-cycle parity computation that expands all matrix dependencies into very large combinational logic.

The design shall use a multi-cycle architecture, controlled by an FSM or equivalent sequencer, for parity computation.

The design shall store large generated dependency tables in a synthesis-friendly form, using ROM, block RAM, distributed ROM, or equivalent inferred memory structures.

The design shall prefer narrow typed indices, addresses, offsets, and packed vectors over large unconstrained `natural` arrays when representing generated tables.

The design shall separate:

- message capture
- parity computation
- output serialization

The parity engine shall read precomputed structural data from generated tables and process the frame over multiple clock cycles.

The generated constants shall describe the selected LDPC code only. They shall not depend on the actual payload bits of a frame.

Scope for the current version:

- implement and validate the CCSDS 1k rate-1/2 encoder
- keep the external top-level interface stable
- keep the internal organization extensible to other configurations later

Top Entity Ports

The top-level VHDL entity must have the following ports:

- `clock_i`
- `reset_i`
- `data_i` (1-bit input data)
- `data_en_i`
- `data_start_i` (first bit of a message)
- `data_o` (1-bit output data)
- `data_en_o`
- `data_start_o` (first bit of an encoded frame)
- `data_message_o` (enable signal for message output)
- `data_parity_o` (enable signal for parity output)

Behavioral Requirements

The encoder shall accept a serial input message.

The encoder shall buffer the full message frame.

After message capture, the encoder shall compute parity using the generated structural tables and the multi-cycle parity engine.

The encoder output shall serialize the encoded frame in the form:

- message bits
- parity bits

The output control signals shall clearly indicate frame start, message region, and parity region.

Compilation Script

Provide a single `compile.do` script to compile all VHDL files and run the simulation in Questa and no vunit

The script shall support regeneration of generated artifacts when required.

Test Data Generation

Use the encoder in `octave/qc_b_encoder` as the functional reference to:

- create a message in a text file
- create the corresponding encoded frame in a text file
- generate an `.m` file for this purpose

Testbench

Create a Questa-compatible testbench that:

- instantiates the VHDL encoder
- reads a message from a text file
- feeds the message serially into the DUT
- captures the encoded output
- compares the encoded output with the reference encoded frame from the text file
- reports pass/fail clearly

Iterative testing shall continue until the encoded result matches the reference vector for the selected 1k 1/2 configuration.

Implementation Note

A large constants file by itself is not acceptable.
I prefer to push all constants in a Xilinx/AMD like RAM written in vhdl in the correct format.

The main limitation is not the existence of generated tables, but how they are used.

Therefore, the implementation shall be judged acceptable for FPGA only if:

- large tables map to ROM/BRAM-like resources or other efficient memory structures
- the parity computation is scheduled across cycles
- the architecture avoids an impractically large flat combinational XOR network

Folders of generated files

Generated files shall be placed as follows:

- `sim`: compile.do, wave.do, generated vectors, and helper generation scripts
- `src`: VHDL source files
- `tb`: VHDL testbench files

Do not get inspiration from version1

Important: Split the tables into several smaller packages or ROM source files instead of one giant package (not a single package file but many)
