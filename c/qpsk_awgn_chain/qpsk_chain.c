#include "qpsk_chain.h"

#include <math.h>
#include <string.h>

static const float k_pi_f = 3.14159265358979323846f;

static float clampf(float x, float lo, float hi) {
    if (x < lo) return lo;
    if (x > hi) return hi;
    return x;
}

void prbs31_init(prbs31_t *p, uint32_t seed) {
    uint32_t s = seed & 0x7FFFFFFFu;
    if (s == 0u) s = 0x1u;
    p->state = s;
}

uint8_t prbs31_next_bit(prbs31_t *p) {
    /* Polynomial: x^31 + x^28 + 1 -> taps at 31 and 28 (1-indexed) */
    uint32_t bit = p->state & 1u;
    uint32_t newbit = ((p->state >> 0) ^ (p->state >> 3)) & 1u; /* 31 and 28 => 0 and 3 from LSB */
    p->state = (p->state >> 1) | (newbit << 30);
    p->state &= 0x7FFFFFFFu;
    return (uint8_t)bit;
}

void prbs31_checker_init(prbs31_checker_t *c, uint32_t seed) {
    prbs31_t p;
    prbs31_init(&p, seed);
    c->state = p.state;
    c->bits_checked = 0;
    c->bit_errors = 0;
}

void prbs31_checker_push(prbs31_checker_t *c, uint8_t rx_bit) {
    prbs31_t p;
    p.state = c->state;
    uint8_t ref = prbs31_next_bit(&p);
    c->state = p.state;
    c->bits_checked++;
    c->bit_errors += (uint64_t)((rx_bit ^ ref) & 1u);
}

void rng32_init(rng32_t *r, uint32_t seed) {
    if (seed == 0u) seed = 0x6D2B79F5u;
    r->state = seed;
}

uint32_t rng32_next_u32(rng32_t *r) {
    /* xorshift32 */
    uint32_t x = r->state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    r->state = x;
    return x;
}

float rng32_next_f32_open01(rng32_t *r) {
    /* (0,1) exclusive-ish: map 24 MSBs to (0,1) and nudge away from endpoints */
    uint32_t u = rng32_next_u32(r);
    uint32_t mant = (u >> 8) & 0xFFFFFFu;
    float x = ((float)mant + 0.5f) * (1.0f / 16777216.0f);
    return clampf(x, 1.0e-7f, 1.0f - 1.0e-7f);
}

void rng32_next_gaussian_pair(rng32_t *r, float *g0, float *g1) {
    /* Box-Muller */
    float u1 = rng32_next_f32_open01(r);
    float u2 = rng32_next_f32_open01(r);
    float mag = sqrtf(-2.0f * logf(u1));
    float ang = 2.0f * k_pi_f * u2;
    *g0 = mag * cosf(ang);
    *g1 = mag * sinf(ang);
}

complexf_t qpsk_mod_gray(uint8_t b0, uint8_t b1) {
    /* Gray: 00->(+,+), 01->(-,+), 11->(-,-), 10->(+,-) */
    const float s = 0.7071067811865475f; /* 1/sqrt(2) */
    complexf_t y;
    uint8_t b0v = (uint8_t)(b0 & 1u);
    uint8_t b1v = (uint8_t)(b1 & 1u);

    if (b0v == 0u && b1v == 0u) { y.i = +s; y.q = +s; }
    else if (b0v == 0u && b1v == 1u) { y.i = -s; y.q = +s; }
    else if (b0v == 1u && b1v == 1u) { y.i = -s; y.q = -s; }
    else { y.i = +s; y.q = -s; }
    return y;
}

void qpsk_demod_gray(complexf_t s, uint8_t *b0, uint8_t *b1) {
    /* Decide quadrant then invert mapping above */
    uint8_t i_neg = (uint8_t)(s.i < 0.0f);
    uint8_t q_neg = (uint8_t)(s.q < 0.0f);
    if (!i_neg && !q_neg) { *b0 = 0u; *b1 = 0u; }
    else if (i_neg && !q_neg) { *b0 = 0u; *b1 = 1u; }
    else if (i_neg && q_neg) { *b0 = 1u; *b1 = 1u; }
    else { *b0 = 1u; *b1 = 0u; }
}

static float rrc_impulse(float t, float beta) {
    /* t in symbol periods, sps handled externally.
       Standard RRC impulse response (unit symbol period). */
    const float pi = k_pi_f;
    float at = fabsf(t);
    if (at < 1e-8f) {
        /* t -> 0 */
        return (1.0f + beta * (4.0f / pi - 1.0f));
    }
    float tb = 4.0f * beta * t;
    float denom = pi * t * (1.0f - tb * tb);
    if (fabsf(1.0f - tb * tb) < 1e-6f) {
        /* t -> ±1/(4β) */
        float a = (beta / sqrtf(2.0f));
        float s1 = (1.0f + 2.0f / pi) * sinf(pi / (4.0f * beta));
        float s2 = (1.0f - 2.0f / pi) * cosf(pi / (4.0f * beta));
        return a * (s1 + s2);
    }
    float num = sinf(pi * t * (1.0f - beta)) + tb * cosf(pi * t * (1.0f + beta));
    return num / denom;
}

int rrc_design(rrc_filter_desc_t *d, float rolloff, int taps, float sps) {
    if (!d) return -1;
    if (!(sps > 0.0f)) return -2;
    if (!(rolloff > 0.0f && rolloff <= 1.0f)) return -3;
    if (taps < 3 || (taps & 1) == 0) return -4;
    if (taps > (int)(sizeof(d->h) / sizeof(d->h[0]))) return -5;

    d->sps = sps;
    d->rolloff = rolloff;
    d->taps = taps;

    int mid = taps / 2;
    float e = 0.0f;
    for (int n = 0; n < taps; n++) {
        float t = ((float)(n - mid)) / sps;
        float v = rrc_impulse(t, rolloff);
        d->h[n] = v;
        e += v * v;
    }
    if (e <= 0.0f) return -6;
    float inv = 1.0f / sqrtf(e);
    for (int n = 0; n < taps; n++) {
        d->h[n] *= inv;
    }
    return 0;
}

void fir_cplx_init(fir_cplx_t *f, const float *h, int taps) {
    memset(f, 0, sizeof(*f));
    f->taps = taps;
    for (int i = 0; i < taps; i++) f->h[i] = h[i];
    f->idx = 0;
}

complexf_t fir_cplx_push(fir_cplx_t *f, complexf_t x) {
    /* circular buffer delay line, newest at idx */
    f->delay[f->idx] = x;
    int idx = f->idx;
    f->idx = (f->idx + 1) % f->taps;

    complexf_t y = {0.0f, 0.0f};
    for (int k = 0; k < f->taps; k++) {
        int di = idx - k;
        if (di < 0) di += f->taps;
        float hk = f->h[k];
        y.i += hk * f->delay[di].i;
        y.q += hk * f->delay[di].q;
    }
    return y;
}

float qpsk_noise_variance_per_complex_sample(float ebn0_db, float sps) {
    /* Es normalized to 1, QPSK: Eb=Es/2 = 0.5.
       Oversampling sps increases noise bandwidth in discrete-time model by sps. */
    float ebn0 = powf(10.0f, ebn0_db / 10.0f);
    float eb = 0.5f;
    float n0 = eb / ebn0;
    /* For complex baseband with independent I/Q components, the discrete-time
       per-complex-sample noise power that matches BER theory here is N0*sps/2. */
    float var_complex = n0 * sps * 0.5f; /* E[|n|^2] per complex sample */
    return var_complex;
}

int qpsk_awgn_chain_ber(const qpsk_ber_cfg_t *cfg, qpsk_ber_result_t *out) {
    if (!cfg || !out) return -1;
    if (cfg->nbits == 0) return -2;
    if ((cfg->nbits & 1ull) != 0ull) return -7;
    if (cfg->rrc_taps < 3 || (cfg->rrc_taps & 1) == 0) return -3;
    if (cfg->rrc_taps > 256) return -4;

    const float sps = 2.0f;

    rrc_filter_desc_t rrc;
    if (rrc_design(&rrc, cfg->rolloff, cfg->rrc_taps, sps) != 0) return -5;

    fir_cplx_t tx, rx;
    fir_cplx_init(&tx, rrc.h, rrc.taps);
    fir_cplx_init(&rx, rrc.h, rrc.taps);

    prbs31_t prbs;
    prbs31_init(&prbs, cfg->seed_prbs);

    rng32_t rng;
    rng32_init(&rng, cfg->seed_noise);

    float var_c = qpsk_noise_variance_per_complex_sample(cfg->ebn0_db, sps);
    float sigma = sqrtf(0.5f * var_c); /* per dimension */

    /* Account for FIR group delay through Tx and Rx and decimation phase.
       With symmetric FIR of length L, group delay = (L-1)/2 samples each.
       Total delay through cascade is L-1 samples. Downsampling by 2:
       choose sampling phase at the midpoint. */
    int L = rrc.taps;
    int total_delay = (L - 1); /* samples */
    int decim_phase = total_delay % 2; /* 0 or 1 */
    int sample_count = 0;

    /* Bit alignment: FIFO of transmitted bits to bridge the filter latency.
       With sps=2 and total_delay samples, first valid symbol decision occurs after total_delay samples,
       which corresponds to (total_delay/2) symbols, i.e. (L-1) bits (QPSK = 2 bits/symbol). */
    const int bit_delay = (L - 1); /* bits */
    uint8_t bit_fifo[512];
    int fifo_w = 0;
    int fifo_r = 0;
    int fifo_count = 0;

    uint64_t bits_checked = 0;
    uint64_t bit_errors = 0;

    uint64_t bits_tx = 0;
    while (bits_tx + 1 < cfg->nbits) {
        if (cfg->target_errors != 0 && bit_errors >= cfg->target_errors) break;

        uint8_t b0 = prbs31_next_bit(&prbs);
        uint8_t b1 = prbs31_next_bit(&prbs);
        bits_tx += 2;

        /* Push TX bits into FIFO. */
        bit_fifo[fifo_w] = b0; fifo_w = (fifo_w + 1) & 511;
        bit_fifo[fifo_w] = b1; fifo_w = (fifo_w + 1) & 511;
        fifo_count += 2;

        complexf_t sym = qpsk_mod_gray(b0, b1);

        /* Interpolation by 2: two samples, first is symbol, second is zero */
        for (int u = 0; u < 2; u++) {
            complexf_t xin = (u == 0) ? sym : (complexf_t){0.0f, 0.0f};
            complexf_t ytx = fir_cplx_push(&tx, xin);

            /* AWGN */
            float g0, g1;
            rng32_next_gaussian_pair(&rng, &g0, &g1);
            complexf_t n = {sigma * g0, sigma * g1};
            complexf_t ych = {ytx.i + n.i, ytx.q + n.q};

            /* Rx matched filter */
            complexf_t yrx = fir_cplx_push(&rx, ych);

            /* Decimation by 2 with phase */
            if (((sample_count - decim_phase) & 1) == 0) {
                if (sample_count >= total_delay) {
                    uint8_t rb0, rb1;
                    qpsk_demod_gray(yrx, &rb0, &rb1);
                    if (fifo_count > bit_delay && fifo_count >= 2) {
                        uint8_t tb0 = bit_fifo[fifo_r]; fifo_r = (fifo_r + 1) & 511;
                        uint8_t tb1 = bit_fifo[fifo_r]; fifo_r = (fifo_r + 1) & 511;
                        fifo_count -= 2;
                        bit_errors += (uint64_t)((rb0 ^ tb0) & 1u);
                        bit_errors += (uint64_t)((rb1 ^ tb1) & 1u);
                        bits_checked += 2;
                    }
                    if (bits_checked >= cfg->nbits) break;
                }
            }
            sample_count++;
        }
    }

    out->ebn0_db = cfg->ebn0_db;
    out->bits = bits_checked;
    out->errors = bit_errors;
    out->ber = (bits_checked == 0) ? 0.0f : ((float)bit_errors / (float)bits_checked);
    return 0;
}
