#ifndef QPSK_CHAIN_H
#define QPSK_CHAIN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float i;
    float q;
} complexf_t;

typedef struct {
    uint32_t state; /* 31-bit LFSR stored in LSBs */
} prbs31_t;

typedef struct {
    uint32_t state;
    uint64_t bits_checked;
    uint64_t bit_errors;
} prbs31_checker_t;

typedef struct {
    uint32_t state;
} rng32_t;

typedef struct {
    float sps;          /* samples per symbol (must be 2.0f for this chain) */
    float rolloff;      /* 0 < rolloff <= 1 */
    int taps;           /* odd number of taps */
    float h[256];       /* impulse response, energy-normalized */
} rrc_filter_desc_t;

typedef struct {
    int taps;
    float h[256];
    complexf_t delay[256];
    int idx;
} fir_cplx_t;

typedef struct {
    float ebn0_db;
    uint64_t nbits;
    uint64_t target_errors; /* 0 = disabled */

    uint32_t seed_prbs;
    uint32_t seed_noise;

    float rolloff;
    int rrc_taps;
} qpsk_ber_cfg_t;

typedef struct {
    float ebn0_db;
    uint64_t bits;
    uint64_t errors;
    float ber;
} qpsk_ber_result_t;

/* PRBS31 (x^31 + x^28 + 1), output bit is LSB */
void prbs31_init(prbs31_t *p, uint32_t seed);
uint8_t prbs31_next_bit(prbs31_t *p);

void prbs31_checker_init(prbs31_checker_t *c, uint32_t seed);
void prbs31_checker_push(prbs31_checker_t *c, uint8_t rx_bit);

/* RNG + Gaussian */
void rng32_init(rng32_t *r, uint32_t seed);
uint32_t rng32_next_u32(rng32_t *r);
float rng32_next_f32_open01(rng32_t *r);
void rng32_next_gaussian_pair(rng32_t *r, float *g0, float *g1);

/* QPSK */
complexf_t qpsk_mod_gray(uint8_t b0, uint8_t b1);
void qpsk_demod_gray(complexf_t s, uint8_t *b0, uint8_t *b1);

/* RRC filter design + FIR */
int rrc_design(rrc_filter_desc_t *d, float rolloff, int taps, float sps);
void fir_cplx_init(fir_cplx_t *f, const float *h, int taps);
complexf_t fir_cplx_push(fir_cplx_t *f, complexf_t x);

/* Eb/N0 handling (QPSK, sps=2, Es=1) -> complex noise variance per sample */
float qpsk_noise_variance_per_complex_sample(float ebn0_db, float sps);

/* End-to-end BER measurement for one Eb/N0 point */
int qpsk_awgn_chain_ber(const qpsk_ber_cfg_t *cfg, qpsk_ber_result_t *out);

#ifdef __cplusplus
}
#endif

#endif /* QPSK_CHAIN_H */

