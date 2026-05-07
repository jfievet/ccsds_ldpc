QPSK AWGN Chain – Requirements
1. Objective

Implement a QPSK baseband communication chain in C to perform Bit Error Rate (BER) measurements over an AWGN channel.

The implementation must simulate an ideal coherent link without carrier frequency offset or timing offset.

All processing must use single-precision floating-point (float).

2. Implementation Constraints
The project must be implemented in C language only
The project structure must contain:
qpsk_chain.c → implementation of all signal processing functions
qpsk_chain.h → function declarations and configuration structures
main.c (or equivalent) → test program for BER measurements

No external DSP libraries should be required (unless explicitly stated later).

3. System Architecture

The chain must implement the following processing blocks in order:

Eb/N0 to SNR conversion
PRBS31 generator
QPSK modulator
Interpolation by 2
Root Raised Cosine (RRC) filter (Tx)
Configurable roll-off factor
Default roll-off = 0.5
AWGN channel
Noise power set from SNR
Root Raised Cosine (RRC) filter (Rx)
Same roll-off configuration
Default roll-off = 0.5
Decimation by 2
QPSK demodulator
PRBS31 checker / decoder
BER computation

4. Functional Requirements

4.1 Eb/N0 Handling
The system must:
Support BER measurement at a single Eb/N0
Support BER measurement over multiple Eb/N0 points
Eb/N0 to SNR conversion must account for:
QPSK modulation
Oversampling factor
Filter energy normalization

4.2 PRBS31

Must implement a standard PRBS31 generator
Must allow reproducible initialization (seed configurable)
A PRBS31 checker must be implemented for BER measurement

4.3 QPSK Modulator

Gray mapping required
Output must be complex baseband samples (I/Q)
Output normalized to unit average symbol energy

4.4 Pulse Shaping

Interpolation factor: 2
RRC filter:
Configurable roll-off
Default roll-off = 0.5
Configurable number of taps
Energy normalized

4.5 AWGN Channel
Additive white Gaussian noise
Noise variance computed from SNR
Must use a proper Gaussian generator (e.g., Box-Muller)

4.6 Receiver
Matched RRC filtering
Decimation by 2
Ideal symbol timing (no timing recovery)
Ideal carrier (no CFO, no phase offset)

4.7 Demodulator
QPSK hard decision demodulation
Bit output aligned with PRBS generator
No soft-decision required (unless added later)

4.8 BER Measurement
BER = number of bit errors / total transmitted bits
Must support:
Configurable number of transmitted bits
Early stop when reaching a target number of errors (optional)
Results must be printed in a clear format:
Eb/N0
Number of bits
Number of errors
Measured BER

5. Non-Functional Requirements
Single-precision floating point only (float)
Deterministic behavior when using fixed seed
Clear modular code structure
No dynamic memory allocation required (unless justified)
Portable C (C99 or later)

6. Others
A run.cmd shall compile and run the test
gcc is available in command window

7. Incremental additional requests:
a)Do additional points up to 10 dB
b)In the console when the ber is displayed from measure, is it possible to also display theoritical expected
c)Results shall be deplayed in the console but also saved to a textfile
d)Is it possible to configure the number of bits to do in a measure  per ebn0 in a table also. Fill the table by default
e) Can you put in the code a prefilled table of number of bits like : {1000000,100000,1000000, etc...} to configure each point
f) With the ber, can you add a column where you log the simulation time per point