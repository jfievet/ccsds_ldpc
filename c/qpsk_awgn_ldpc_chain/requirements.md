# QPSK AWGN LDPC Chain Requirements

## Objective

The objective of this project is to implement, in this repository, a complete QPSK communication chain over an AWGN channel with LDPC coding support.

The implemented chain must contain the following processing blocks:

- PRBS31 generator
- LDPC encoder
- QPSK modulation
- Root Raised Cosine (RRC) transmit filter
- AWGN channel
- Receive filter
- Basic QPSK demodulation
- LLR (Log-Likelihood Ratio) computation/conversion
- LDPC decoder
- BER (Bit Error Rate) computation

---

## Existing Source Reuse

Some source files originating from the `c/qpsk_awgn_chain` directory have already been added to this repository.

These files may be modified as needed for the implementation.

Additionally:

- The directory `c/qc_encoder_all` contains a reusable LDPC encoder implemented in C.
- The directory `offset_min_sum_decoder` contains an LDPC decoder that must be integrated into the communication chain.

---

## Build and Execution Requirements

The complete project must:

- Compile successfully
- Execute through a single runnable binary/application
- Support runtime configuration selection

The selected configuration must be:

- Passed as a command-line argument to the compiled executable
- Or use a default configuration if no argument is provided

---

## Simulation Parameters

The `Eb/N0` parameter must be included in the communication chain and configurable as part of the simulation execution.

---

## Expected Functional Flow

The communication chain is expected to follow the sequence below:

1. Generate PRBS31 data
2. Encode data using LDPC
3. Modulate encoded bits using QPSK
4. Apply RRC transmit filtering
5. Pass the signal through an AWGN channel
6. Apply receive filtering
7. Perform basic QPSK demodulation
8. Compute LLRs from the received symbols
9. Decode using the LDPC decoder
10. Compute BER statistics

---

## Integration Notes

- The implementation should prioritize modularity and reusability.
- Existing encoder and decoder implementations should be reused whenever possible instead of rewritten.
- The LDPC decoder integration must use the provided Offset Min-Sum decoder implementation.
- The LDPC decoder must receive soft-input LLR values generated from the QPSK demodulator output.
- The chain should be structured to allow future extension and additional configurations.

---

## Implemented CLI (this directory)

The runnable binary is built and executed via `run.cmd`.

Key options:

- `--ldpc_cfg ID` selects the CCSDS AR4JA LDPC configuration (1..9, as defined in `c/qc_encoder_all`).
- `--ldpc_iters I` sets the maximum number of OMS iterations (default: 10).
- `--ldpc_offset O` sets the OMS offset (default: 0.15).
- `--ldpc_h PATH` optionally overrides the H-matrix path (default: auto `../build_h/H_*.mat` derived from `--ldpc_cfg`).
