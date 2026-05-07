#include "qpsk_chain.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

static double now_seconds(void) {
#ifdef _WIN32
    static LARGE_INTEGER freq;
    static int inited = 0;
    LARGE_INTEGER c;
    if (!inited) {
        QueryPerformanceFrequency(&freq);
        inited = 1;
    }
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart / (double)freq.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + 1e-9 * (double)ts.tv_nsec;
#endif
}

static float qpsk_theoretical_ber(float ebn0_db) {
    /* Gray-coded QPSK over AWGN: same bit BER as BPSK: Q(sqrt(2*Eb/N0)) = 0.5*erfc(sqrt(Eb/N0)) */
    float ebn0 = powf(10.0f, ebn0_db / 10.0f);
    return 0.5f * erfcf(sqrtf(ebn0));
}

static void usage(const char *argv0) {
    printf("Usage: %s [--ebn0_db A,B,C] [--bits N] [--target_errors E] [--seed_prbs S] [--seed_noise S]\n", argv0);
    printf("          [--rolloff R] [--rrc_taps T]\n");
    printf("          [--out FILE]\n");
    printf("          [--bits_table N0,N1,...]\n");
    printf("\nDefaults:\n");
    printf("  ebn0_db = 0,1,2,3,4,5,6,7,8,9,10\n");
    printf("  bits = 1000000\n");
    printf("  bits_table = prefilled per point (override with --bits_table or --bits)\n");
    printf("  target_errors = 0 (disabled)\n");
    printf("  seed_prbs = 1\n");
    printf("  seed_noise = 2\n");
    printf("  rolloff = 0.5\n");
    printf("  rrc_taps = 101\n");
    printf("  out = ber_results.txt\n");
}

static int parse_u64(const char *s, uint64_t *out) {
    char *end = NULL;
    unsigned long long v = strtoull(s, &end, 10);
    if (!s[0] || (end && *end)) return -1;
    *out = (uint64_t)v;
    return 0;
}

static int parse_u32(const char *s, uint32_t *out) {
    char *end = NULL;
    unsigned long v = strtoul(s, &end, 10);
    if (!s[0] || (end && *end)) return -1;
    *out = (uint32_t)v;
    return 0;
}

static int parse_i32(const char *s, int *out) {
    char *end = NULL;
    long v = strtol(s, &end, 10);
    if (!s[0] || (end && *end)) return -1;
    *out = (int)v;
    return 0;
}

static int parse_f32(const char *s, float *out) {
    char *end = NULL;
    float v = strtof(s, &end);
    if (!s[0] || (end && *end)) return -1;
    *out = v;
    return 0;
}

static int split_csv_floats(const char *csv, float *vals, int max_vals, int *n_out) {
    int n = 0;
    const char *p = csv;
    while (*p) {
        if (n >= max_vals) return -3;
        while (*p == ' ' || *p == '\t') p++;
        char *end = NULL;
        float v = strtof(p, &end);
        if (end == p) return -2;
        vals[n++] = v;
        p = end;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == ',') {
            p++;
            continue;
        }
        if (*p == '\0') break;
        return -2;
    }
    *n_out = n;
    return (n > 0) ? 0 : -4;
}

static int split_csv_u64s(const char *csv, uint64_t *vals, int max_vals, int *n_out) {
    int n = 0;
    const char *p = csv;
    while (*p) {
        if (n >= max_vals) return -3;
        while (*p == ' ' || *p == '\t') p++;
        char *end = NULL;
        unsigned long long v = strtoull(p, &end, 10);
        if (end == p) return -2;
        vals[n++] = (uint64_t)v;
        p = end;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == ',') {
            p++;
            continue;
        }
        if (*p == '\0') break;
        return -2;
    }
    *n_out = n;
    return (n > 0) ? 0 : -4;
}

static void fill_u64(uint64_t *dst, int n, uint64_t v) {
    for (int i = 0; i < n; i++) dst[i] = v;
}

static void fill_bits_table_default(uint64_t *dst, int n, uint64_t fallback) {
    /* Prefilled per-point bits table (requirements 7e).
       Pattern repeats if the Eb/N0 list is longer than the preset. */
    static const uint64_t preset[] = {
        1000000ull, 1000000ull, 1000000ull, 1000000ull, 1000000ull,
        1000000ull, 1000000ull, 1000000ull, 1000000ull, 10000000ull, 50000000ull, 200000000ull, 1000000000ull
    };
    const int preset_n = (int)(sizeof(preset) / sizeof(preset[0]));
    for (int i = 0; i < n; i++) {
        uint64_t v = preset[i % preset_n];
        if (v == 0ull) v = fallback;
        if (v & 1ull) v += 1ull;
        dst[i] = v;
    }
}

int main(int argc, char **argv) {
    float ebn0_list[64];
    int ebn0_n = 0;
    (void)split_csv_floats("0,1,2,3,4,5,6,7,8,9,10,10.5,11", ebn0_list, 64, &ebn0_n);

    qpsk_ber_cfg_t cfg;
    uint64_t default_bits = 1000000ull;
    cfg.nbits = default_bits;
    cfg.target_errors = 0ull;
    cfg.seed_prbs = 1u;
    cfg.seed_noise = 2u;
    cfg.rolloff = 0.5f;
    cfg.rrc_taps = 101;

    const char *out_path = "ber_results.txt";
    uint64_t bits_table[64];
    fill_bits_table_default(bits_table, ebn0_n, default_bits);

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (!strcmp(a, "--help") || !strcmp(a, "-h")) {
            usage(argv[0]);
            return 0;
        } else if (!strcmp(a, "--ebn0_db") && i + 1 < argc) {
            if (split_csv_floats(argv[++i], ebn0_list, 64, &ebn0_n) != 0) {
                fprintf(stderr, "Invalid --ebn0_db list\n");
                return 2;
            }
            fill_bits_table_default(bits_table, ebn0_n, default_bits);
        } else if (!strcmp(a, "--bits") && i + 1 < argc) {
            if (parse_u64(argv[++i], &default_bits) != 0) return 2;
            if (default_bits & 1ull) {
                fprintf(stderr, "--bits must be even (QPSK = 2 bits/symbol)\n");
                return 2;
            }
            fill_u64(bits_table, ebn0_n, default_bits);
        } else if (!strcmp(a, "--target_errors") && i + 1 < argc) {
            if (parse_u64(argv[++i], &cfg.target_errors) != 0) return 2;
        } else if (!strcmp(a, "--seed_prbs") && i + 1 < argc) {
            if (parse_u32(argv[++i], &cfg.seed_prbs) != 0) return 2;
        } else if (!strcmp(a, "--seed_noise") && i + 1 < argc) {
            if (parse_u32(argv[++i], &cfg.seed_noise) != 0) return 2;
        } else if (!strcmp(a, "--rolloff") && i + 1 < argc) {
            if (parse_f32(argv[++i], &cfg.rolloff) != 0) return 2;
        } else if (!strcmp(a, "--rrc_taps") && i + 1 < argc) {
            if (parse_i32(argv[++i], &cfg.rrc_taps) != 0) return 2;
        } else if (!strcmp(a, "--out") && i + 1 < argc) {
            out_path = argv[++i];
        } else if (!strcmp(a, "--bits_table") && i + 1 < argc) {
            int n = 0;
            if (split_csv_u64s(argv[++i], bits_table, 64, &n) != 0 || n != ebn0_n) {
                fprintf(stderr, "Invalid --bits_table (need %d comma-separated values)\n", ebn0_n);
                return 2;
            }
            for (int k = 0; k < ebn0_n; k++) {
                if (bits_table[k] == 0 || (bits_table[k] & 1ull)) {
                    fprintf(stderr, "--bits_table entries must be non-zero and even\n");
                    return 2;
                }
            }
        } else {
            fprintf(stderr, "Unknown/invalid arg: %s\n", a);
            usage(argv[0]);
            return 2;
        }
    }

    FILE *fout = fopen(out_path, "w");
    if (!fout) {
        fprintf(stderr, "Failed to open output file: %s\n", out_path);
        return 4;
    }

    fprintf(fout, "Eb/N0(dB)  Bits        Errors      BER(meas)    BER(theory)   Time(s)\n");
    fprintf(fout, "--------  ----------  ----------  -----------  -----------  --------\n");
    fflush(fout);

    printf("Eb/N0(dB)  Bits        Errors      BER(meas)    BER(theory)   Time(s)\n");
    printf("--------  ----------  ----------  -----------  -----------  --------\n");
    for (int k = 0; k < ebn0_n; k++) {
        cfg.ebn0_db = ebn0_list[k];
        cfg.nbits = bits_table[k];
        qpsk_ber_result_t r;
        double t0 = now_seconds();
        int rc = qpsk_awgn_chain_ber(&cfg, &r);
        double t1 = now_seconds();
        if (rc != 0) {
            fprintf(stderr, "qpsk_awgn_chain_ber failed (%d)\n", rc);
            fclose(fout);
            return 3;
        }
        float ber_th = qpsk_theoretical_ber(r.ebn0_db);
        double dt = t1 - t0;
        printf("%8.2f  %10llu  %10llu  %11.6g  %11.6g  %8.3f\n",
               r.ebn0_db,
               (unsigned long long)r.bits,
               (unsigned long long)r.errors,
               (double)r.ber,
               (double)ber_th,
               dt);
        fprintf(fout, "%8.2f  %10llu  %10llu  %11.6g  %11.6g  %8.3f\n",
                r.ebn0_db,
                (unsigned long long)r.bits,
                (unsigned long long)r.errors,
                (double)r.ber,
                (double)ber_th,
                dt);
        fflush(stdout);
        fflush(fout);
    }
    fclose(fout);
    return 0;
}
