# Requirements

## Overview
The project requires the implementation of a MATLAB module named `test.m` that performs encoding and decoding operations using predefined matrices.

## Functional Requirements

### 1. Encoding
- The system must:
  - Generate a random message.
  - Encode the message using a generator matrix (**G matrix**).

### 2. Decoding
- The system must:
  - Decode the encoded message using a parity-check matrix (**H matrix**).
  - Verify that no errors are present (no error correction required).

### 3. Matrix Sources
- Generator matrices (**G matrices**) must be loaded from the `build_g` folder.
- Parity-check matrices (**H matrices**) must be loaded from the `build_h` folder.

### 4. User Interface
- The `test.m` module must include a menu that:
  - Allows the user to select the desired configuration.
  - Loads the corresponding G and H matrices.

### 5. Output
- After encoding and decoding:
  - The system must display a message indicating whether:
    - No errors were detected, or
    - An error occurred.

## Non-Functional Requirements

- The implementation must be written in MATLAB.
- The module should be modular and easy to extend for future error correction features.
- The user interface can be command-line based.

## Assumptions

- All matrices in `build_g` and `build_h` are valid and correctly paired.
- No noise or transmission errors are introduced during encoding/decoding.

## Constraints

- Error detection only; no error correction mechanisms are required.
- The system assumes ideal transmission conditions.