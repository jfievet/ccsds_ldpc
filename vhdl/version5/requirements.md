I would like you to implement an optimized LDPC encoder (1k, 1/2) in VHDL.

Preliminary information:
The ccsds_ldpc\c\build_g directory contains a G matrix in a .mat file.
This matrix has a size of 1024 × 2560.
The part from 2048 to 2560 is punctured.
The part from 1024 to 2048 is composed of 8 × 8 circulant submatrices.
Each of these submatrices is 128 × 128 bits.

Encoder implementation:
I would like you to base your work and architecture with the C implementation located in directory ccsds_ldpc\c\qc_encoder_12_1024.

The architecture must be as follows:

The encoder receives the message bits as input, bit by bit (from 1 to 1024).
The 8 × 8 first rows of each circulant submatrix are stored in ROMs (VHDL‑implementable on Xilinx).
In total, there must be 8 ROMs, each with 8 × 128 entries. Each ROM has a 128‑bit data bus.
There must be 8 shift registers, each initialized from a ROM output every 128 cycles (when switching from one circulant matrix to the next).
Each shift register is 128 bits wide and must be shiftable.
There is another large register that replicates the incoming message bit across it.
A XOR operation is performed between the 1024 replicated bits of the incoming message bit and the contents of the 8 shift registers of 128 bits each (1024 bits total).

Important: every 128 message bits, the ROM must be read again and the shift registers must be reinitialized.
However, the results of each XOR operation between the incoming message bit and the shift registers are accumulated until the end in a large 1024‑bit accumulator register that contains the parity bits.

The message bits are output on the fly as they are received, and at the end, the accumulator register containing the parity bits is serialized and output bit by bit.

Module interface:
The module must contain the following ports:
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


You may reuse the testbench already present in the sim and tb directories.
However, try to reuse as little of the existing VHDL as possible from other versions folders; instead, base your implementation mainly on the working C code.
Avoid using a fully sequential state machine to control everything.