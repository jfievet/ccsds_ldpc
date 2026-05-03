I would like you to implement an optimized LDPC encoder (1k, 1/2) in C.

Preliminary information:
The ccsds_ldpc\c\build_g directory contains a G matrix in a .mat file.
This matrix is of size 1024 × 2560.
The part from 2048 to 2560 is to be punctured.
The part from 1024 to 2048 is composed of 8 × 8 circulant submatrices.
Each of these submatrices is 128 × 128 bits.

Encoder implementation:

I would like you to create 8 shift registers.
Each shift register is 128 bits wide and is initialized with the top row of a circulant matrix.
So we can say that we have 8 × 128 = 1024 registers.
The sequencing is as follows:

Read the first bit and replicate it into a large register D of width 1024 bits.
Preload the 8 shift registers Sᵢ from a table C (table C contains the first rows of the 8 × 8 matrices).
Perform an XOR between D and Sᵢ; the result is stored in accu.
Shift the 8 registers Sᵢ.
Read the second bit and replicate it into D.
Perform an XOR between D and Sᵢ; store the result in accu.
Perform an XOR between D and Sᵢ, and also with the current accu; store the result in accu.
And so on, until reading bit 128.

Once bit 128 has been processed, reload the Sᵢ registers with the next lower circulant matrix.
This is done a total of eight times.
However, the accumulator must not be reset between reloads.
At the end, accu (which is a 1024‑bit‑wide register) contains the computed parts of parities.
Finally, output the message and the parity bits.


Verification:
Generate a random message m.
Compute m × G using the .mat file from directory ccsds_ldpc\c\build_g.
Then encode m using the implemented function.
Verify that the resulting codeword is the same as m × G.

Helping tips:
You can create an .h file with constants
You can precompute with a python script (you could create) the elaboration of the .h file containing the first lines of each of the 8 x 8 circulants matrix