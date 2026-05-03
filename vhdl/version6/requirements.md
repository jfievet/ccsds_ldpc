I would like you to generalize the implementation that is located in the ccsds_ldpc\vhdl\version5 directory.

This generalization must statically cover all nine configurations (so not dynamically configurable).
What I mean is that it must not be possible to change the configuration at runtime.
Each configuration mode is handled through a VHDL wrapper with the appropriate configuration package, which corresponds to and instantiates the LDPC core. Therefore, there are 9 packages for 9 configurations.
Be aware that you may encounter difficulties generating the packages using Python for the 16k case, so it might be better to use a C program to generate the packages, etc.
Keep the same architectures, maybe it is possible to only replace constants in the existing file, and change top names, plus add a wrapper and map inside constants
with generics, it is just a hint

The directory structure is as follows:
sim
src
tb

I would like to have one testbench file per configuration, resulting in a total of 9 testbenches.
I also want 9 compile.do files, for example compile_1k_12.do, etc.
Then, there should be a compile.all script that runs all simulations for all configurations.
Try to generalize the concept as well for the VUnit testbenches, but do not try to validate or simulate them.
Focus on the .do files and Questa.
Also, generate 9 wave.do files, for example wave_1k_12.do, etc.
Validation is done using stimulus files. You can generate the stimuli with a C program that reuses the encoder located in ccsds_ldpc\c\qc_encoder_all and generates the 9 test vectors for the 9 configurations.
You need to generate both the message and the reference codeword — 18 files in total.