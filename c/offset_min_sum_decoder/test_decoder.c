#include "decoder.h"
#include "qc_encoder.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <time.h>


int main(void)
{
    //
    // CCSDS selection:
    // 1 = rate 1/2, 1024
    //

    const int selection = 1;

    const qc_encoder_config *config =
        qc_encoder_get_config(selection);

    if(!config)
    {
        printf("invalid encoder config\n");
        return -1;
    }

    //Init RNG
    srand((unsigned)time(NULL));

    //
    // Load matching H matrix
    //

    ldpc_matrix_t H;

    if(ldpc_load_mat(
        "../build_h/H_1_2_1024.mat",
        &H))
    {
        return -1;
    }

    printf("Loaded H matrix\n");

    //
    // Allocate message
    //

    uint8_t *message =
        malloc(config->info_length);

    //
    // Allocate transmitted codeword
    //

    uint8_t *tx_codeword =
        malloc(config->transmitted_length);

    //
    // Full decoder-size LLRs
    //

    float *llr =
        malloc(H.N * sizeof(float));

    //
    // Decoder output
    //

    uint8_t *decoded_bits =
        malloc(H.N);

    //
    // Random message
    //

    for(int i = 0; i < config->info_length; i++)
    {
        message[i] = rand() & 1;
    }

    //
    // Encode
    //

    qc_encoder_encode(
        config,
        message,
        tx_codeword);

    printf("Encoding done\n");

//
// Eb/N0 in dB
//

float ebn0_db = 2.0f;

//
// CCSDS code rate
//

float code_rate =
    (float)config->info_length /
    (float)H.N;

//
// Convert Eb/N0 to linear
//

float ebn0 =
    powf(10.0f, ebn0_db / 10.0f);

//
// Noise sigma
//

float sigma =
    sqrtf(1.0f / (2.0f * code_rate * ebn0));

printf("Eb/N0 = %.2f dB\n", ebn0_db);
printf("Sigma = %f\n", sigma);

//
// AWGN channel
//

for(int i = 0;
    i < config->transmitted_length;
    i++)
{
    //
    // BPSK modulation
    //
    // 0 -> +1
    // 1 -> -1
    //

    float tx;

    if(tx_codeword[i] == 0)
    {
        tx = +1.0f;
    }
    else
    {
        tx = -1.0f;
    }

    //
    // Box-Muller Gaussian noise
    //

    float u1 =
        ((float)rand() + 1.0f) /
        ((float)RAND_MAX + 1.0f);

    float u2 =
        ((float)rand() + 1.0f) /
        ((float)RAND_MAX + 1.0f);

    float noise =
        sigma *
        sqrtf(-2.0f * logf(u1)) *
        cosf(2.0f * 3.1415926535f * u2);

    //
    // Received sample
    //

    float y =
        tx + noise;

    //
    // Soft LLR
    //

    llr[i] =
        2.0f * y / (sigma * sigma);

    if(llr[i] > 50.0f)
    {
        llr[i] = 50.0f;
    }

    if(llr[i] < -50.0f)
    {
        llr[i] = -50.0f;
    }

}

//
// Punctured bits
//

for(int i = config->transmitted_length;
    i < H.N;
    i++)
{
    llr[i] = 0.0f;
}

    //
    // Decode
    //

    int iterations =
        ldpc_decode_layered_oms(
            &H,
            llr,
            decoded_bits,
            50,
            0.5f);

    printf(
        "Decoder finished in %d iterations\n",
        iterations);

    //
    // Compare only transmitted bits
    //

    int bit_errors = 0;

    for(int i = 0;
        i < config->transmitted_length;
        i++)
    {
        if(decoded_bits[i] != tx_codeword[i])
        {
            bit_errors++;
        }
    }

    printf(
        "Bit errors = %d\n",
        bit_errors);

    free(message);
    free(tx_codeword);
    free(llr);
    free(decoded_bits);

    ldpc_free(&H);

    return 0;
}