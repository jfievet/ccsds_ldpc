#include "qpsk_chain.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "qc_encoder.h"
#include "ldpc_decoder.h"

static const float k_pi_f = 3.14159265358979323846f;
static const float k_inv_sqrt2_f = 0.7071067811865475f; /* 1/sqrt(2) */

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
    complexf_t y;
    uint8_t b0v = (uint8_t)(b0 & 1u);
    uint8_t b1v = (uint8_t)(b1 & 1u);

    if (b0v == 0u && b1v == 0u) { y.i = +k_inv_sqrt2_f; y.q = +k_inv_sqrt2_f; }
    else if (b0v == 0u && b1v == 1u) { y.i = -k_inv_sqrt2_f; y.q = +k_inv_sqrt2_f; }
    else if (b0v == 1u && b1v == 1u) { y.i = -k_inv_sqrt2_f; y.q = -k_inv_sqrt2_f; }
    else { y.i = +k_inv_sqrt2_f; y.q = -k_inv_sqrt2_f; }
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
    /* QPSK (M=4), uncoded (R=1). Eb/N0 is referenced to information bits. */
    float ebn0 = powf(10.0f, ebn0_db / 10.0f);
    int bits_per_sym = 2; /* log2(4) */
    float code_rate = 1.0f;
    float snr = (ebn0 * (float)bits_per_sym * code_rate) / sps;
    if (!(snr > 0.0f)) return 0.0f;
    /* With sps samples/symbol and Es normalized to 1, average complex-sample power is ~Es/sps. */
    float sig_pwr = 1.0f / sps;
    return sig_pwr / snr;
}

static float qpsk_noise_variance_per_complex_sample_coded(float ebn0_db, float sps, float code_rate) {
    /* Eb/N0 referenced to information bits.
       Convert Eb/N0 -> Es/N0 with modulation order + code rate:
         Es/N0 = Eb/N0 * log2(M) * R, with QPSK M=4 => log2(M)=2. */
    if (!(code_rate > 0.0f && code_rate <= 1.0f)) return 0.0f;
    float ebn0 = powf(10.0f, ebn0_db / 10.0f);
    int bits_per_sym = 2;
    float snr = (ebn0 * (float)bits_per_sym * code_rate) / sps;
    if (!(snr > 0.0f)) return 0.0f;
    float sig_pwr = 1.0f / sps;
    return sig_pwr / snr;
}

static int build_h_path_from_g_path(const char *g_path, char *out, size_t out_sz) {
    /* Expect something like "../build_g/G_1_2_1024.mat" -> "../build_h/H_1_2_1024.mat" */
    const char *needle = "build_g/G_";
    const char *p = strstr(g_path, needle);
    if (!p) return -1;

    size_t prefix_len = (size_t)(p - g_path);
    const char *suffix = p + strlen("build_g/G_"); /* points to "1_2_1024.mat" */

    int n = snprintf(out, out_sz, "%.*sbuild_h/H_%s", (int)prefix_len, g_path, suffix);
    return (n > 0 && (size_t)n < out_sz) ? 0 : -2;
}

static void qpsk_llr_gray(complexf_t s, float sigma2_dim, float *llr_b0, float *llr_b1) {
    /* Mapping (b0,b1) -> (I,Q):
         00 -> (+,+)
         01 -> (-,+)
         11 -> (-,-)
         10 -> (+,-)
       So b1 controls I sign, b0 controls Q sign.
       LLR = log P(bit=0|y)/P(bit=1|y) = 2*a*y / sigma^2 for BPSK ±a. */
    float inv = (sigma2_dim > 0.0f) ? (1.0f / sigma2_dim) : 0.0f;
    *llr_b0 = 2.0f * k_inv_sqrt2_f * s.q * inv;
    *llr_b1 = 2.0f * k_inv_sqrt2_f * s.i * inv;
}

static float quantize_llr(float x, int width_bits, float clip) {
    if (width_bits == 0) return x; /* float */
    if (width_bits < 3 || width_bits > 6) return x;
    if (!(clip > 0.0f)) return x;

    int qmax = (1 << (width_bits - 1)) - 1; /* e.g. 3b -> 3, 6b -> 31 */
    x = clampf(x, -clip, clip);

    float scaled = x * ((float)qmax / clip);
    int qi = (int)lrintf(scaled);
    if (qi > qmax) qi = qmax;
    if (qi < -qmax) qi = -qmax;
    return ((float)qi) * (clip / (float)qmax);
}

static int build_llr_out_path_ebn0(char *dst, size_t dst_sz, const char *base_path, float ebn0_db) {
    if (!dst || dst_sz == 0 || !base_path || !base_path[0]) return -1;

    /* Format Eb/N0 with two decimals and filename-safe characters. */
    char eb[32];
    (void)snprintf(eb, sizeof(eb), "%.2f", (double)ebn0_db);
    for (char *p = eb; *p; p++) {
        if (*p == '.') *p = 'p';
        else if (*p == '-') *p = 'm';
    }

    const char *ext = strrchr(base_path, '.');
    if (ext && !strcmp(ext, ".txt")) {
        size_t stem_len = (size_t)(ext - base_path);
        int n = snprintf(dst, dst_sz, "%.*s_ebn0_%s.txt", (int)stem_len, base_path, eb);
        return (n > 0 && (size_t)n < dst_sz) ? 0 : -2;
    }

    int n = snprintf(dst, dst_sz, "%s_ebn0_%s.txt", base_path, eb);
    return (n > 0 && (size_t)n < dst_sz) ? 0 : -2;
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

static int qpsk_awgn_llrs_block(
    float sigma,
    fir_cplx_t *tx,
    fir_cplx_t *rx,
    rng32_t *rng,
    const uint8_t *data_bits,
    int data_bits_n,
    int warmup_bits,
    int tail_bits,
    int decim_phase,
    int total_delay,
    float *llr_out,
    int llr_width_bits,
    float llr_clip
) {
    if ((data_bits_n & 1) != 0) return -1;
    if ((warmup_bits & 1) != 0) return -2;
    if ((tail_bits & 1) != 0) return -3;

    const float sigma2_dim = sigma * sigma;
    int bits_to_discard = warmup_bits;
    int llr_count = 0;
    int sample_count = 0;

    int total_bits = warmup_bits + data_bits_n + tail_bits;
    int total_syms = total_bits / 2;

    for (int si = 0; si < total_syms; si++) {
        int bit_pos = 2 * si;
        uint8_t b0 = 0u, b1 = 0u;
        if (bit_pos >= warmup_bits && bit_pos + 1 < warmup_bits + data_bits_n) {
            int di = bit_pos - warmup_bits;
            b0 = data_bits[di + 0];
            b1 = data_bits[di + 1];
        }
        complexf_t sym = qpsk_mod_gray(b0, b1);

        for (int u = 0; u < 2; u++) {
            complexf_t xin = (u == 0) ? sym : (complexf_t){0.0f, 0.0f};
            complexf_t ytx = fir_cplx_push(tx, xin);

            float g0, g1;
            rng32_next_gaussian_pair(rng, &g0, &g1);
            complexf_t n = {sigma * g0, sigma * g1};
            complexf_t ych = {ytx.i + n.i, ytx.q + n.q};

            complexf_t yrx = fir_cplx_push(rx, ych);

            if (((sample_count - decim_phase) & 1) == 0) {
                if (sample_count >= total_delay) {
                    float llr0, llr1;
                    qpsk_llr_gray(yrx, sigma2_dim, &llr0, &llr1);
                    llr0 = quantize_llr(llr0, llr_width_bits, llr_clip);
                    llr1 = quantize_llr(llr1, llr_width_bits, llr_clip);
                    if (bits_to_discard > 0) {
                        bits_to_discard -= 2;
                        if (bits_to_discard < 0) bits_to_discard = 0;
                    } else {
                        llr_out[llr_count++] = llr0;
                        llr_out[llr_count++] = llr1;
                        if (llr_count >= data_bits_n) return 0;
                    }
                }
            }
            sample_count++;
        }
    }

    return -4;
}

int qpsk_awgn_ldpc_chain_ber(const qpsk_ber_cfg_t *cfg, qpsk_ber_result_t *out) {
    if (!cfg || !out) return -1;
    if (cfg->nbits == 0) return -2;
    if (cfg->rrc_taps < 3 || (cfg->rrc_taps & 1) == 0) return -3;
    if (cfg->rrc_taps > 256) return -4;
    if (cfg->ldpc_cfg <= 0) return -10;

    const qc_encoder_config *enc_cfg = qc_encoder_get_config(cfg->ldpc_cfg);
    if (!enc_cfg) return -11;
    if ((enc_cfg->transmitted_length & 1) != 0) return -12; /* QPSK needs 2 bits/symbol */

    char h_path_buf[512];
    const char *h_path = cfg->ldpc_h_path;
    if (!h_path) {
        if (build_h_path_from_g_path(enc_cfg->g_matrix_path, h_path_buf, sizeof(h_path_buf)) != 0) {
            return -13;
        }
        h_path = h_path_buf;
    }

    ldpc_matrix_t H;
    memset(&H, 0, sizeof(H));
    if (ldpc_load_mat(h_path, &H) != 0) {
        return -14;
    }

    const float sps = 2.0f;
    rrc_filter_desc_t rrc;
    if (rrc_design(&rrc, cfg->rolloff, cfg->rrc_taps, sps) != 0) {
        ldpc_free(&H);
        return -5;
    }

    prbs31_t prbs;
    prbs31_init(&prbs, cfg->seed_prbs);

    rng32_t rng;
    rng32_init(&rng, cfg->seed_noise);

    float code_rate = (float)enc_cfg->info_length / (float)enc_cfg->transmitted_length;
    float var_c = qpsk_noise_variance_per_complex_sample_coded(cfg->ebn0_db, sps, code_rate);
    if (!(var_c > 0.0f)) {
        ldpc_free(&H);
        return -15;
    }
    float sigma = sqrtf(0.5f * var_c);

    int L = rrc.taps;
    int total_delay = (L - 1);
    int decim_phase = total_delay % 2;

    uint8_t *msg_bits = (uint8_t *)malloc((size_t)enc_cfg->info_length);
    uint8_t *tx_bits = (uint8_t *)malloc((size_t)enc_cfg->transmitted_length);
    float *llr_tx = (float *)malloc((size_t)enc_cfg->transmitted_length * sizeof(float));
    float *llr_full = (float *)malloc((size_t)enc_cfg->full_length * sizeof(float));
    uint8_t *dec_bits = (uint8_t *)malloc((size_t)enc_cfg->full_length);

    if (!msg_bits || !tx_bits || !llr_tx || !llr_full || !dec_bits) {
        free(msg_bits); free(tx_bits); free(llr_tx); free(llr_full); free(dec_bits);
        ldpc_free(&H);
        return -16;
    }

    uint64_t bits_checked = 0;
    uint64_t bit_errors = 0;

    FILE *fllr = NULL;
    int dumped_frames = 0;
    if (cfg->llr_out_path && cfg->llr_out_path[0]) {
        char llr_path[768];
        if (build_llr_out_path_ebn0(llr_path, sizeof(llr_path), cfg->llr_out_path, cfg->ebn0_db) != 0) {
            free(msg_bits); free(tx_bits); free(llr_tx); free(llr_full); free(dec_bits);
            ldpc_free(&H);
            return -30;
        }
        fllr = fopen(llr_path, "w");
        if (!fllr) {
            free(msg_bits); free(tx_bits); free(llr_tx); free(llr_full); free(dec_bits);
            ldpc_free(&H);
            return -30;
        }
        fprintf(fllr, "# LLR dump (rate=%s, info_length=%d, transmitted_length=%d, ebn0_db=%.6g)\n",
                enc_cfg->name ? enc_cfg->name : "?",
                enc_cfg->info_length,
                enc_cfg->transmitted_length,
                (double)cfg->ebn0_db);
        fprintf(fllr, "# Columns: frame_index bit_index llr\n");
        fflush(fllr);
    }

    while (bits_checked < cfg->nbits) {
        if (cfg->target_errors != 0 && bit_errors >= cfg->target_errors) break;

        for (int i = 0; i < enc_cfg->info_length; i++) {
            msg_bits[i] = prbs31_next_bit(&prbs);
        }

        qc_encoder_encode(enc_cfg, msg_bits, tx_bits);

        /* Reset filters for frame-based processing (independent codewords). */
        fir_cplx_t tx, rx;
        fir_cplx_init(&tx, rrc.h, rrc.taps);
        fir_cplx_init(&rx, rrc.h, rrc.taps);

        int warmup_bits = (L - 1);
        int tail_bits = (L - 1);
        int rc = qpsk_awgn_llrs_block(
            sigma,
            &tx,
            &rx,
            &rng,
            tx_bits,
            enc_cfg->transmitted_length,
            warmup_bits,
            tail_bits,
            decim_phase,
            total_delay,
            llr_tx,
            cfg->llr_width_bits,
            cfg->llr_clip
        );
        if (rc != 0) {
            free(msg_bits); free(tx_bits); free(llr_tx); free(llr_full); free(dec_bits);
            ldpc_free(&H);
            return -20;
        }

        memset(llr_full, 0, (size_t)enc_cfg->full_length * sizeof(float));
        memcpy(llr_full, llr_tx, (size_t)enc_cfg->transmitted_length * sizeof(float));

        if (fllr && (cfg->llr_out_frames <= 0 || dumped_frames < cfg->llr_out_frames)) {
            for (int i = 0; i < enc_cfg->transmitted_length; i++) {
                fprintf(fllr, "%d %d %.9g\n", dumped_frames, i, (double)llr_tx[i]);
            }
            fflush(fllr);
            dumped_frames++;
        }

        (void)ldpc_decode_layered_oms(
            &H,
            llr_full,
            dec_bits,
            (cfg->ldpc_max_iters > 0) ? cfg->ldpc_max_iters : 10,
            (cfg->ldpc_oms_offset >= 0.0f) ? cfg->ldpc_oms_offset : 0.15f
        );

        for (int i = 0; i < enc_cfg->info_length; i++) {
            bit_errors += (uint64_t)((dec_bits[i] ^ msg_bits[i]) & 1u);
        }
        bits_checked += (uint64_t)enc_cfg->info_length;
    }

    out->ebn0_db = cfg->ebn0_db;
    out->bits = bits_checked;
    out->errors = bit_errors;
    out->ber = (bits_checked == 0) ? 0.0f : ((float)bit_errors / (float)bits_checked);

    if (fllr) fclose(fllr);
    free(msg_bits); free(tx_bits); free(llr_tx); free(llr_full); free(dec_bits);
    ldpc_free(&H);
    return 0;
}
