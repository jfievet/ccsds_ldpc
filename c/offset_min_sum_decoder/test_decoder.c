
#include "decoder.h"
#include "qc_encoder.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <time.h>
#include <string.h>

typedef struct {
    int selection;
    const char *desc;
    const char *h_matrix_path;
} code_option_t;

// Table of all 9 CCSDS code rate/block size options
static const code_option_t code_options[9] = {
    {1,  "1: 1k, rate 1/2",   "../build_h/H_1_2_1024.mat"},
    {4,  "2: 1k, rate 2/3",   "../build_h/H_2_3_1024.mat"},
    {7,  "3: 1k, rate 4/5",   "../build_h/H_4_5_1024.mat"},
    {2,  "4: 4k, rate 1/2",   "../build_h/H_1_2_4096.mat"},
    {5,  "5: 4k, rate 2/3",   "../build_h/H_2_3_4096.mat"},
    {8,  "6: 4k, rate 4/5",   "../build_h/H_4_5_4096.mat"},
    {3,  "7: 16k, rate 1/2",  "../build_h/H_1_2_16384.mat"},
    {6,  "8: 16k, rate 2/3",  "../build_h/H_2_3_16384.mat"},
    {9,  "9: 16k, rate 4/5",  "../build_h/H_4_5_16384.mat"}
};

int main(int argc, char *argv[])
{
    int option = 0;
    if(argc > 1) {
        option = atoi(argv[1]);
    }

    // Show menu if no valid argument
    if(option < 1 || option > 9) {
        printf("Select CCSDS code rate and block size:\n");
        for(int i = 0; i < 9; ++i) {
            printf("  %s\n", code_options[i].desc);
        }
        printf("Enter option (1-9): ");
        fflush(stdout);
        if(scanf("%d", &option) != 1 || option < 1 || option > 9) {
            printf("Invalid selection.\n");
            return -1;
        }
    }

    const code_option_t *opt = &code_options[option-1];
    const qc_encoder_config *config = qc_encoder_get_config(opt->selection);
    if(!config) {
        printf("Invalid encoder config for selection %d\n", opt->selection);
        return -1;
    }

    srand((unsigned)time(NULL));

    ldpc_matrix_t H;
    if(ldpc_load_mat(opt->h_matrix_path, &H)) {
        printf("Failed to load H matrix: %s\n", opt->h_matrix_path);
        return -1;
    }
    printf("Loaded H matrix: %s\n", opt->h_matrix_path);
    printf("Selected: %s\n", opt->desc);

    // Debug: print buffer sizes and check consistency
    printf("info_length=%d, transmitted_length=%d, H.N=%d, H.M=%d\n",
        config->info_length, config->transmitted_length, H.N, H.M);
    if (config->transmitted_length > H.N) {
        printf("ERROR: transmitted_length > H.N!\n");
        return -1;
    }
    if (config->info_length > config->transmitted_length) {
        printf("ERROR: info_length > transmitted_length!\n");
        return -1;
    }

    //
    // Allocate message
    //


    uint8_t *message = malloc(config->info_length);
    uint8_t *tx_codeword = malloc(config->transmitted_length);
    float *llr = malloc(H.N * sizeof(float));
    uint8_t *decoded_bits = malloc(H.N);

    if (!message || !tx_codeword || !llr || !decoded_bits) {
        printf("ERROR: Memory allocation failed!\n");
        free(message); free(tx_codeword); free(llr); free(decoded_bits);
        ldpc_free(&H);
        return -1;
    }

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