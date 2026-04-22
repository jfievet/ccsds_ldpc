# Requirements Specification: QC Block-Based LDPC Encoder

## 1. Scope

Implement a single GNU Octave script that performs LDPC encoding using a quasi-cyclic block-based method.

The implementation shall be:

* written in MATLAB-compatible syntax for Octave
* FPGA-target oriented
* based on the CCSDS LDPC structure

The script shall encode using a QC block-based approach rather than a generic bit-dependency approach.

The algortigm is described in document: CCSDS 131.1-O-1 , section 3.4
If needed the pdf is in the pdf folder one upper.

---

## 2. Main Goal

The goal is to build an LDPC encoder script that:

* uses the structure described in the ccsds document
* is structured in a way that is relevant for future FPGA or RTL implementation
* generates a codeword
* validates the generated codeword using the parity-check matrix `H`

---

## 3. Existing Repository Assets

The repository already contains useful assets that shall be reused:

* the folder `build_H`
* a script in `build_H` that constructs the CCSDS `H` matrix according to CCSDS 131.0-B-5
* `.mat` files containing `H` for all supported configurations

The implementation may use:

* the existing `build_H` script as a reference for matrix structure
* the existing `H` `.mat` files for loading parity-check matrices

The implementation may also use the information from `build_H` to derive an `M` matrix or equivalent block-structured representation needed by the QC block-based encoder.

---

## 4. Script Structure

The implementation shall be a single Octave script.

The script shall:

1. display a menu at the beginning
2. allow the user to choose from all supported CCSDS configurations
3. determine the corresponding code rate and block size
4. perform QC block-based encoding for the selected configuration
5. validate the generated codeword using the corresponding `H` matrix

---

## 5. Configuration Menu

At the beginning of the script, a menu shall be displayed to select all possible supported configurations.

The script shall support the full set of CCSDS configurations already available through the repository artifacts.

The menu shall allow selection among all available combinations of:

* code rate
* block size

---

## 6. Encoding Method

The encoding shall be implemented using a QC block-based method.

This means the script should:
* be organized in a way that is meaningful for an FPGA-oriented implementation

The implementation should favor:

* block-wise processing
* circulant-shift-oriented logic
* XOR-based operations over GF(2)

The implementation should avoid relying on:

* a generator matrix `G`
* a generic dense matrix encoding method
* a purely bit-dependency-list style approach when a QC block representation is available

### Important Architectural Direction

If the implementation is pushed in the right direction, the biggest architectural decision is:

*  Constants should be precalculated once and stored in a seperate file

This is considered the clean FPGA-oriented option.

---

## 7. Use of H for Validation

The script shall load the corresponding `H` matrix from the `build_H` folder or from the existing `.mat` files generated from it.

The loaded `H` matrix shall be used to validate the encoded codeword.

Validation shall verify:

```matlab
H * c' = 0 mod 2
```

where:

* `H` is the parity-check matrix for the selected configuration
* `c` is the generated codeword

---

## 8. Data Representation

The script shall:

* use binary vectors
* operate over GF(2)
* implement additions as XOR operations

The implementation may use:

* logical arrays
* `uint8`
* sparse matrices when useful for validation

---

## 9. Console Logging

The script should log useful information in the console.

The console output should indicate:

* selected configuration
* loaded `H` file
* chosen block size and rate
* encoding progress if useful
* validation result

The logs should remain simple and readable.

---

## 10. Constraints

The implementation shall:

* remain inside the current project folder structure
* use the existing repository assets
* be a single Octave script
* be based on the CCSDS QC structure

The implementation shall not:

* use a generator matrix `G`
* depend on external libraries
* require toolboxes

---

## 11. Acceptance Criteria

The implementation is considered correct if:

* the script displays a configuration menu at startup
* the user can select any supported configuration
* the script performs LDPC encoding using a QC block-based method
* the script loads the corresponding `H` matrix
* the script verifies that the generated codeword satisfies `H * c' = 0 mod 2`
* the script is written as a single Octave script

---

## 12. Deliverable

The deliverable is:

* one Octave script implementing the QC block-based LDPC encoder and validation flow


## Aditional note
Annotate  in the code with comments, what is constants in rom, what is processed realtime in fpga
