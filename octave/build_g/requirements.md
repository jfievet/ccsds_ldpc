# Requirements Specification: LDPC Generator Matrix (G) Builder

## 1. Overview
This project requires the implementation of a single Octave/MATLAB `.m` script that generates the LDPC Generator Matrix (G) based on specifications defined in **CCSDS 131.0-B-5**, specifically **Section 7.4.3**.

The script must support multiple coding rates and block sizes, using pre-existing parity-check matrices (H) stored in `.mat` files.

---

## 2. Inputs

### 2.1 Standard Reference
- Document: **CCSDS 131.0-B-5**
- Section: **7.4.3 (LDPC Generator Matrix Construction)**

### 2.2 H Matrix Files
- Location: `build_H/` (parent directory)
- Format: `.mat` files
- Contents: Precomputed parity-check matrices (H)

### 2.3 User-Selectable Parameters
The script must allow runtime selection of:
- **Code Rate**
  - 1/2
  - 2/3
  - 4/5
- **Block Length**
  - 1k (1024 bits)
  - 4k (4096 bits)
  - 16k (16384 bits)

---

## 3. Functional Requirements

### 3.1 Main Script
- A single `.m` file must:
  - Handle all configurations
  - Dynamically generate the Generator Matrix (G)
  - Load appropriate H matrix based on user selection

### 3.2 Menu Interface
- Provide a simple CLI menu (similar to `build_H.m`)
- Menu should allow:
  - Selection of code rate
  - Selection of block size
- Validate user input

### 3.3 G Matrix Construction
- Implement algorithm strictly following **Section 7.4.3**
- Convert parity-check matrix (H) into generator matrix (G)
- Ensure:
  - Correct dimensions:
    - If H is (n−k) × n → G must be k × n
  - Proper algebra over GF(2)

### 3.4 File Output
- Save generated G matrix as:
  - `.mat` file
- Naming convention: G_<rate>_<blocklength>.mat
G_1_2_1024.mat

## 4. Non-Functional Requirements

### 4.1 Code Structure
- Modular and readable
- Clear separation of:
- Input handling
- Matrix processing
- Output saving

### 4.2 Compatibility
- Must run in:
- GNU Octave
- MATLAB (optional compatibility)

### 4.3 Performance
- Efficient handling of large matrices (especially 16k)
- Use sparse matrices where applicable

---

## 5. Dependencies

- Existing `.mat` files containing H matrices (from `build_H/`)
- Reference implementation: `build_H.m` (for menu/UI structure)

---

## 6. Assumptions

- H matrices are valid and correctly formatted
- Section 7.4.3 provides sufficient detail for G construction
- No need to validate correctness of H matrices

---

## 7. Constraints

- Single `.m` file implementation only
- No external libraries beyond standard Octave/MATLAB functions
- Must support all required configurations in one script

---

## 8. Expected Workflow

1. User runs script
2. Menu is displayed (similar to `build_H.m`)
3. User selects:
 - Code rate
 - Block size
4. Script loads corresponding H matrix from `build_H/`
5. Script computes G matrix using Section 7.4.3
6. Script saves output `.mat` file
7. Confirmation message is displayed

---

## 9. Deliverables

- `build_G.m` (single script)
- Generated `.mat` files for each configuration
- Inline documentation/comments for usage