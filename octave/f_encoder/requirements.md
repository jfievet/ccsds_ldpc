# Requirements Specification: LDPC Encoding Function

## 1. Scope

Implement an LDPC encoder in MATLAB-compatible syntax for GNU Octave.

The implementation shall provide:

* one function named `ldpc_encoding`
* one function or script named `test.m`

The encoder shall support the CCSDS configurations already available in the repository through the existing matrix artifacts.

---

## 2. Main Encoder Function

The main encoder entry point shall be:

```matlab
codeword = ldpc_encoding(message, code_rate, block_size)
```

### Input Arguments

The function shall accept:

* `message`
* `code_rate`
* `block_size`

### Output

The function shall return:

* `codeword`

---

## 3. Encoding Behavior

The implementation of `ldpc_encoding` shall:

* encode the provided binary input message into an LDPC codeword
* be based on the logic already implemented in the neighboring `encoder` folder, especially `encode_and_test.m`
* reuse the existing `.mat` files for the selected configuration
* avoid any precalculation or constant-generation step at runtime

The function shall therefore:

* load the proper `.mat` file from the `encoder` folder for the requested configuration
* use the stored constants directly
* not regenerate constants from `H`

---

## 4. Supported Configuration Selection

The encoder shall determine the configuration from:

* the `code_rate` argument
* the `block_size` argument

The implementation shall support the CCSDS configurations for which matching `.mat` files already exist in the repository.

The script shall build the correct filename suffix from the selected configuration, for example:

```matlab
1/2 + 1024 -> ldpc_constants_1_2_1024.mat
```

---

## 5. Data Dependencies

The implementation shall reuse the existing artifacts already available in the repository:

* constants `.mat` files from the `encoder` folder
* corresponding `H` matrices from the `build_H` folder for testing

The implementation shall not:

* recompute constants
* rebuild `H`

---

## 6. Test Function

Implement also a file named `test.m`.

Its purpose is to test `ldpc_encoding`.

The test flow shall:

1. display a menu to choose the LDPC configuration
2. determine the corresponding code rate and block size
3. generate a random binary information vector
4. encode that vector using `ldpc_encoding`
5. load the corresponding `H` matrix from the `build_H` folder
6. verify that the encoded codeword satisfies the parity-check equation
7. display whether the parity-check validation passed

The test is only required to:

* generate the random vector
* encode it
* validate the result with `H`

No decoding step is required.

---

## 7. Console Logging

The implementation shall log useful progress information in the console.

The console output should indicate:

* selected configuration
* loaded constants file
* loaded parity-check matrix file
* message length
* codeword length
* whether the encoded codeword satisfies the parity-check equation

The logs should remain simple and readable.

---

## 8. Implementation Constraints

The implementation shall use:

* MATLAB-compatible syntax for GNU Octave
* only base language features
* relative paths inside the repository

The implementation shall not:

* use toolboxes
* use external libraries
* depend on absolute paths

---

## 9. Functional Expectations

`ldpc_encoding` is considered correct if:

* it loads the proper precomputed constants file for the requested configuration
* it returns a codeword for the supplied message
* it does not perform any precalculation

`test.m` is considered correct if:

* it lets the user choose a configuration from a menu
* it generates a random message
* it encodes that message using `ldpc_encoding`
* it loads the corresponding `H` matrix
* it verifies that the produced codeword satisfies `H * c' = 0 mod 2`
* it reports the validation result in the console

---

## 10. Deliverables

The implementation deliverables are:

* `ldpc_encoding.m`
* `test.m`

Both files shall live in the current implementation folder and rely on neighboring repository folders through relative paths only.
