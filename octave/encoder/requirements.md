# CCSDS LDPC Encoder – Requirements

## 1. Scope

This project aims to develop a CCSDS LDPC encoder in MATLAB for:

* Information length: **k = 1024 bits**
* Code rate: **1/2**

The encoder must be derived directly from the parity-check matrix **H**, using:

[
H \cdot c^T = 0 \quad \text{over GF(2)}
]

The use of a generator matrix **G** is not allowed.

---

## 2. Repository Assumptions

The repository already contains a `build_H` folder providing the construction of the parity-check matrix **H**.

The work is limited to:

* using this existing implementation,
* deriving an encoder from **H**,
* generating reusable encoding constants,
* validating encoded codewords.

The project is restricted to:

* **k = 1024**
* **rate = 1/2**

---

## 3. Directory Structure
Do not write outside of the directory where is the encoder
---

## 4. Global Architecture

The implementation shall be split into two scripts:

### 4.1 Offline Script — Constant Generation

`generate_constants.m`

Purpose:

* Analyze the parity-check matrix **H**
* Derive all structures required for encoding
* Generate and store constants

### 4.2 Online Script — Encoder + Test

`encode_and_test.m`

Purpose:

* Load previously generated constants
* Encode input messages
* Validate correctness

---

## 5. Implementation Constraints

Both scripts shall:

* be **pure MATLAB scripts** (no functions),
* contain **no subfunctions**,
* contain **no local function definitions**.

All logic must be written inline.

---

## 6. Constant Generation (generate_constants.m)

The script shall:

1. Load or generate **H** from `build_H`
2. Partition **H** into:
   [
   H = [H_m ;; H_p]
   ]
3. Analyze the structure of **H** to derive encoding relationships

The script shall generate constants such as:

* index mappings for permutations,
* sparse dependency lists between message bits and parity bits,
* optional triangular or ordered solving structure,
* block-level relationships (if QC structure is used).

The script shall:

* avoid computing a full generator matrix **G**,
* avoid storing dense matrices when possible.

### Output

The script shall save constants to a file:

```matlab
save('ldpc_constants.mat', ...)
```

Stored data may include:

* permutation tables,
* parity dependency mappings,
* block configuration parameters.

---

## 7. Encoder Strategy (encode_and_test.m)

The encoder shall:

* load constants:

```matlab
load('ldpc_constants.mat');
```

* accept or generate a binary message vector **m** of length 1024,
* compute parity bits **p** using only:

  * XOR operations,
  * index-based access,
  * precomputed constants.

The encoder shall not:

* recompute structure from **H**,
* perform matrix inversion,
* construct or use a generator matrix.

---

## 8. Encoding Implementation

The encoding shall:

* implement:
  [
  H_p \cdot p^T = H_m \cdot m^T
  ]
  using precomputed relationships,

* compute parity bits through:

  * XOR combinations of selected message bits,
  * optional intermediate variables (e.g., staged parity vectors),

* assemble the final codeword:
  [
  c = [m ;; p]
  ]

---

## 9. Data Representation

Both scripts shall:

* use binary vectors (`logical` or `uint8`),
* perform all arithmetic in **GF(2)**,
* implement addition using XOR operations.

---

## 10. Validation

The `encode_and_test.m` script shall:

1. Generate random messages **m**
2. Encode them into codewords **c**
3. Retrieve **H** from `build_H`
4. Verify:

[
H \cdot c^T = 0 \mod 2
]

The script shall:

* test multiple random vectors,
* display pass/fail results.

---

## 11. Constraints

* Only **k = 1024** is supported
* Only **rate = 1/2** is supported
* The encoder must be derived from **H**
* No generator matrix **G** may be used
* No subfunctions are allowed
* Only two scripts are allowed:

  * one for constant generation
  * one for encoding and testing
* Constants must be reused (no recomputation at runtime)

---

## 12. Development Plan

**Step 1**

* Implement `generate_constants.m` to extract encoding structure from **H**

**Step 2**

* Save all required constants into a `.mat` file

**Step 3**

* Implement `encode_and_test.m` using only constants

**Step 4**

* Validate encoding correctness using ( H \cdot c^T = 0 )

**Step 5**

* Simplify and optimize XOR-based implementation
