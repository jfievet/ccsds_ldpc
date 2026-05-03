I would like you to implement a CCSDS LDPC encoder (9 configurations) in C.

Preliminary information:
The directory ccsds_ldpc\c\build_g contains G matrices stored in separate .mat files.


Sizes of the G matrices in the .mat files:
In each matrix, the final part is punctured (shown in parentheses).

Rate 1/2:
1k: 1024 × 2560 (2048)
4k: 4096 × 10240 (8192)
16k: 16384 × 40960 (32768)

Rate 2/3:
1k: 1024 × 1792 (1536)
4k: 4096 × 7168 (6144)
16k: 16384 × 28672 (24576)

Rate 4/5:
1k: 1024 × 1408 (1280)
4k: 4096 × 5632 (5120)
16k: 16384 × 22528 (20480)

Number of circulant submatrices and size of each submatrix (in bits):

Rate 1/2:
1k: 8 × 8  128 × 128
4k: 8 × 8  512 × 512
16k: 8 × 8  2048 × 2048

Rate 2/3:
1k: 16 × 8  64 × 64
4k: 16 × 8  256 × 256
16k: 16 × 8  1024 × 1024

Rate 4/5:
1k: 32 × 8  32 × 32
4k: 32 × 8  128 × 128
16k: 32 × 8  512 × 512

Generalize the C implementation (which is 1k 1/2 only) already available in directory ccsds_ldpc\c\qc_encoder_12_1024 so that it supports all 9 configurations.
Use a Python script to generate a .h file containing all the constants required for these 9 configurations.
Note: the size of the shift registers will not be the same for all configurations.

I want you to implement a test that:
Encodes data using the C encoder
Verifies the result against m × G computed from the .mat file located in directory ccsds_ldpc\c\build_g
The test program must take a command‑line argument between 1 and 9 to select the configuration.

A run.cmd script will:
Compile the code once
Then run the test program sequentially for each configuration
The user should be able to see a “passed” message for each configuration in the console.