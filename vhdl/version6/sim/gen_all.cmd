python .\generate_ldpc_artifacts.py
gcc -O2 -std=c99 -o generate_vectors.exe generate_vectors.c -I../../../c/qc_encoder_all ../../../c/qc_encoder_all/qc_encoder.c
generate_vectors.exe