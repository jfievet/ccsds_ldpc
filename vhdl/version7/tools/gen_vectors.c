/*
 * gen_vectors.c
 *
 * Generates deterministic test vectors for the VHDL decoder, using the same
 * QPSK + RRC + AWGN + LLR chain as c/qpsk_awgn_ldpc_chain.
 *
 * - Builds one CCSDS AR4JA frame (rate 1/2, 1k) with qc_encoder (cfg=1)
 * - PRBS31 -> QC encode -> QPSK Gray mapping
 * - Oversample by 2, TX RRC, AWGN, RX RRC, decimate, LLR
 * - Quantize to signed 6-bit integer codes in [-31..31]
 * - Runs integer layered Offset-Min-Sum for fixed iterations to create golden bits
 *
 * Output files in tb/vectors:
 *   llr_zero.txt / bits_zero_it10.txt
 *   llr_chain.txt / bits_chain_it5.txt / bits_chain_it10.txt
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>

#include "qpsk_chain.h"
#include "qc_encoder.h"

enum { M = 1536, FULL_N = 2560, IN_N = 2048, OUT_N = 1024, ROW_MAX_DEG = 6 };
enum { LDPC_CFG = 1 };

typedef enum {
    PAT_PRBS31 = 0,
    PAT_X83 = 1
} pattern_t;

typedef enum {
    LLR_AWGN = 0,
    LLR_HARD = 1
} llr_mode_t;

static void die(const char *msg) {
    fprintf(stderr, "Error: %s\n", msg);
    exit(1);
}

static int clamp31(int x) {
    if (x > 31) return 31;
    if (x < -31) return -31;
    return x;
}

static int abs_i(int x) { return x < 0 ? -x : x; }

static void usage(const char *argv0) {
    fprintf(stderr, "Usage: %s [--pattern prbs31|x83] [--ebn0_db X] [--seed_prbs N] [--seed_noise N] [--llr awgn|hard] [--invert 0|1]\n", argv0);
    fprintf(stderr, "Defaults: --pattern prbs31 --ebn0_db 3.0 --seed_prbs 1 --seed_noise 2 --llr awgn --invert 0\n");
}

static int streq(const char *a, const char *b) {
    return a && b && strcmp(a, b) == 0;
}

static int parse_u32(const char *s, uint32_t *out) {
    char *end = NULL;
    unsigned long v = strtoul(s, &end, 10);
    if (!s[0] || (end && *end)) return -1;
    *out = (uint32_t)v;
    return 0;
}

static int parse_f32(const char *s, float *out) {
    char *end = NULL;
    float v = strtof(s, &end);
    if (!s[0] || (end && *end)) return -1;
    *out = v;
    return 0;
}

static int8_t quantize_llr_to_i6(float x, float clip) {
    const int qmax = 31;
    if (!(clip > 0.0f)) clip = 8.0f;
    if (x > clip) x = clip;
    if (x < -clip) x = -clip;
    float scaled = x * ((float)qmax / clip);
    int qi = (int)lrintf(scaled);
    if (qi > qmax) qi = qmax;
    if (qi < -qmax) qi = -qmax;
    return (int8_t)qi;
}

static void qpsk_llr_gray_local(complexf_t s, float sigma2_dim, float *llr_b0, float *llr_b1) {
    const float inv_sqrt2 = 0.7071067811865475f;
    float inv = (sigma2_dim > 0.0f) ? (1.0f / sigma2_dim) : 0.0f;
    *llr_b0 = 2.0f * inv_sqrt2 * s.q * inv;
    *llr_b1 = 2.0f * inv_sqrt2 * s.i * inv;
}

static float noise_var_coded(float ebn0_db, float sps, float code_rate) {
    if (!(code_rate > 0.0f && code_rate <= 1.0f)) return 0.0f;
    float ebn0 = powf(10.0f, ebn0_db / 10.0f);
    int bits_per_sym = 2;
    float snr = (ebn0 * (float)bits_per_sym * code_rate) / sps;
    if (!(snr > 0.0f)) return 0.0f;
    float sig_pwr = 1.0f / sps;
    return sig_pwr / snr;
}

static int qpsk_awgn_llrs_block_i6(
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
    int8_t *llr_out_i6,
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
                    qpsk_llr_gray_local(yrx, sigma2_dim, &llr0, &llr1);
                    if (bits_to_discard > 0) {
                        bits_to_discard -= 2;
                        if (bits_to_discard < 0) bits_to_discard = 0;
                    } else {
                        llr_out_i6[llr_count++] = quantize_llr_to_i6(llr0, llr_clip);
                        llr_out_i6[llr_count++] = quantize_llr_to_i6(llr1, llr_clip);
                        if (llr_count >= data_bits_n) return 0;
                    }
                }
            }
            sample_count++;
        }
    }

    return -4;
}

static void load_rows(const char *path, uint16_t rows[M][ROW_MAX_DEG]) {
    FILE *fp = fopen(path, "r");
    if (!fp) die("cannot open H_1_2_1024.mat");

    int rows_n = 0, cols_n = 0;
    unsigned long long nnz = 0;
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (sscanf(line, "# rows: %d", &rows_n) == 1) continue;
        if (sscanf(line, "# columns: %d", &cols_n) == 1) continue;
        if (line[0] == '#' && line[1] == ' ' && line[2] == 'n' && line[3] == 'n' && line[4] == 'z') {
            char *p = line;
            while (*p && *p != ':') p++;
            if (*p == ':') nnz = strtoull(p + 1, NULL, 10);
            continue;
        }
        if (line[0] >= '0' && line[0] <= '9') break;
    }
    if (rows_n != M || cols_n != FULL_N || nnz == 0) die("unexpected H dimensions");

    int row_count[M];
    for (int r = 0; r < M; r++) {
        row_count[r] = 0;
        for (int k = 0; k < ROW_MAX_DEG; k++) rows[r][k] = 0;
    }

    do {
        int r1, c1, v;
        if (sscanf(line, "%d %d %d", &r1, &c1, &v) == 3) {
            if (v == 1) {
                int r = r1 - 1;
                int c = c1 - 1;
                if (r >= 0 && r < M && c >= 0 && c < FULL_N) {
                    int n = row_count[r];
                    if (n < ROW_MAX_DEG) {
                        rows[r][n] = (uint16_t)c; /* 0-based VN index */
                        row_count[r] = n + 1;
                    }
                }
            }
        }
    } while (fgets(line, sizeof(line), fp));

    fclose(fp);
}

static void run_decoder(
    const uint16_t h_rows[M][ROW_MAX_DEG],
    const int8_t llr_in[IN_N],
    int iters,
    int offset_q,
    uint8_t bits_out[OUT_N]
) {
    int8_t llr[FULL_N];
    int8_t cn_msg[M][ROW_MAX_DEG];

    for (int i = 0; i < FULL_N; i++) llr[i] = 0;
    for (int i = 0; i < IN_N; i++) llr[i] = llr_in[i];
    for (int r = 0; r < M; r++) for (int k = 0; k < ROW_MAX_DEG; k++) cn_msg[r][k] = 0;

    for (int iter = 0; iter < iters; iter++) {
        for (int r = 0; r < M; r++) {
            int v2c[ROW_MAX_DEG];
            int av[ROW_MAX_DEG];
            int sgn[ROW_MAX_DEG];
            int sign_prod = 0;

            for (int k = 0; k < ROW_MAX_DEG; k++) {
                int vn = (int)h_rows[r][k];
                int oldm = (int)cn_msg[r][k];
                int x = (int)llr[vn] - oldm;
                v2c[k] = x;
                av[k] = abs_i(x);
                sgn[k] = (x < 0) ? 1 : 0;
                sign_prod ^= sgn[k];
            }

            int min1 = 1000000, min2 = 1000000, min1_k = -1;
            for (int k = 0; k < ROW_MAX_DEG; k++) {
                int a = av[k];
                if (a < min1) {
                    min2 = min1;
                    min1 = a;
                    min1_k = k;
                } else if (a < min2) {
                    min2 = a;
                }
            }

            min1 -= offset_q;
            min2 -= offset_q;
            if (min1 < 0) min1 = 0;
            if (min2 < 0) min2 = 0;
            if (min1 > 31) min1 = 31;
            if (min2 > 31) min2 = 31;

            for (int k = 0; k < ROW_MAX_DEG; k++) {
                int vn = (int)h_rows[r][k];
                int x = v2c[k];
                int mag = (k == min1_k) ? min2 : min1;
                int sign = sign_prod ^ sgn[k];
                int newm = sign ? -mag : mag;
                cn_msg[r][k] = (int8_t)clamp31(newm);
                llr[vn] = (int8_t)clamp31(x + newm);
            }
        }
    }

    for (int i = 0; i < OUT_N; i++) {
        bits_out[i] = (llr[i] < 0) ? 1u : 0u;
    }
}

static void write_llr_file(const char *path, const int8_t llr[IN_N]) {
    FILE *fp = fopen(path, "w");
    if (!fp) die("cannot write llr file");
    for (int i = 0; i < IN_N; i++) fprintf(fp, "%d\n", (int)llr[i]);
    fclose(fp);
}

static void write_bits_file(const char *path, const uint8_t bits[OUT_N]) {
    FILE *fp = fopen(path, "w");
    if (!fp) die("cannot write bits file");
    for (int i = 0; i < OUT_N; i++) fprintf(fp, "%u\n", (unsigned)bits[i]);
    fclose(fp);
}

int main(int argc, char **argv) {
    const char *h_path = "..\\..\\c\\build_h\\H_1_2_1024.mat";

    uint16_t h_rows[M][ROW_MAX_DEG];
    load_rows(h_path, h_rows);

    int8_t llr_zero[IN_N];
    for (int i = 0; i < IN_N; i++) llr_zero[i] = 0;

    /* Chain-generated LLRs (encoded PRBS through QPSK+RRC+AWGN+LLR) */
    int8_t llr_chain[IN_N];
    memset(llr_chain, 0, sizeof(llr_chain));

    const qc_encoder_config *enc = qc_encoder_get_config(LDPC_CFG);
    if (!enc) die("qc_encoder_get_config failed");
    if (enc->info_length != 1024 || enc->transmitted_length != 2048 || enc->full_length != 2560) {
        die("unexpected encoder config lengths");
    }

    uint8_t msg_bits[1024];
    uint8_t tx_bits[2048];

    pattern_t pattern = PAT_PRBS31;
    llr_mode_t llr_mode = LLR_AWGN;
    float ebn0_db = 3.0f;
    uint32_t seed_prbs = 1u;
    uint32_t seed_noise = 2u;
    int invert = 0;

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (streq(a, "--pattern") && i + 1 < argc) {
            const char *p = argv[++i];
            if (streq(p, "prbs31")) pattern = PAT_PRBS31;
            else if (streq(p, "x83")) pattern = PAT_X83;
            else { usage(argv[0]); die("invalid --pattern"); }
        } else if (streq(a, "--llr") && i + 1 < argc) {
            const char *m = argv[++i];
            if (streq(m, "awgn")) llr_mode = LLR_AWGN;
            else if (streq(m, "hard")) llr_mode = LLR_HARD;
            else { usage(argv[0]); die("invalid --llr"); }
        } else if (streq(a, "--ebn0_db") && i + 1 < argc) {
            if (parse_f32(argv[++i], &ebn0_db) != 0) { usage(argv[0]); die("invalid --ebn0_db"); }
        } else if (streq(a, "--seed_prbs") && i + 1 < argc) {
            if (parse_u32(argv[++i], &seed_prbs) != 0) { usage(argv[0]); die("invalid --seed_prbs"); }
        } else if (streq(a, "--seed_noise") && i + 1 < argc) {
            if (parse_u32(argv[++i], &seed_noise) != 0) { usage(argv[0]); die("invalid --seed_noise"); }
        } else if (streq(a, "--invert") && i + 1 < argc) {
            uint32_t tmp = 0;
            if (parse_u32(argv[++i], &tmp) != 0) { usage(argv[0]); die("invalid --invert"); }
            invert = (tmp != 0u) ? 1 : 0;
        } else if (streq(a, "--help") || streq(a, "-h")) {
            usage(argv[0]);
            return 0;
        } else {
            usage(argv[0]);
            die("unknown argument");
        }
    }

    if (pattern == PAT_PRBS31) {
        prbs31_t prbs;
        prbs31_init(&prbs, seed_prbs);
        for (int i = 0; i < enc->info_length; i++) msg_bits[i] = prbs31_next_bit(&prbs);
    } else {
        /* Repeating 0x83 pattern, MSB-first per byte: 0b1000_0011 */
        for (int i = 0; i < enc->info_length; i++) {
            int bit = (0x83 >> (7 - (i & 7))) & 1;
            msg_bits[i] = (uint8_t)bit;
        }
    }

    if (invert) {
        for (int i = 0; i < enc->info_length; i++) msg_bits[i] ^= 1u;
    }
    qc_encoder_encode(enc, msg_bits, tx_bits);

    const float sps = 2.0f;
    const float rolloff = 0.5f;
    const int taps = 101;
    const float llr_clip = 8.0f;

    if (llr_mode == LLR_HARD) {
        for (int i = 0; i < IN_N; i++) {
            llr_chain[i] = tx_bits[i] ? (int8_t)-31 : (int8_t)31;
        }
    } else {
        rrc_filter_desc_t rrc;
        if (rrc_design(&rrc, rolloff, taps, sps) != 0) die("rrc_design failed");

        fir_cplx_t tx, rx;
        fir_cplx_init(&tx, rrc.h, rrc.taps);
        fir_cplx_init(&rx, rrc.h, rrc.taps);

        rng32_t rng;
        rng32_init(&rng, seed_noise);

        float code_rate = (float)enc->info_length / (float)enc->transmitted_length;
        float var_c = noise_var_coded(ebn0_db, sps, code_rate);
        if (!(var_c > 0.0f)) die("noise_var_coded failed");
        float sigma = sqrtf(0.5f * var_c);

        int warmup_bits = (taps - 1);
        int tail_bits = (taps - 1);
        int total_delay = (taps - 1);
        int decim_phase = total_delay % 2;

        if (qpsk_awgn_llrs_block_i6(
                sigma,
                &tx,
                &rx,
                &rng,
                tx_bits,
                enc->transmitted_length,
                warmup_bits,
                tail_bits,
                decim_phase,
                total_delay,
                llr_chain,
                llr_clip
            ) != 0) {
            die("qpsk_awgn_llrs_block_i6 failed");
        }
    }

    uint8_t bits[OUT_N];

    write_llr_file("tb\\vectors\\llr_zero.txt", llr_zero);
    run_decoder((const uint16_t (*)[ROW_MAX_DEG])h_rows, llr_zero, 10, 1, bits);
    write_bits_file("tb\\vectors\\bits_zero_it10.txt", bits);

    write_llr_file("tb\\vectors\\llr_chain.txt", llr_chain);
    run_decoder((const uint16_t (*)[ROW_MAX_DEG])h_rows, llr_chain, 5, 1, bits);
    write_bits_file("tb\\vectors\\bits_chain_it5.txt", bits);
    run_decoder((const uint16_t (*)[ROW_MAX_DEG])h_rows, llr_chain, 10, 1, bits);
    write_bits_file("tb\\vectors\\bits_chain_it10.txt", bits);

    return 0;
}
