#include "decoder.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct
{
    int row;
    int col;
} edge_t;

static void* checked_malloc(size_t size)
{
    void *p = malloc(size);

    if(!p)
    {
        fprintf(stderr, "malloc failed\n");
        exit(EXIT_FAILURE);
    }

    return p;
}

static int edge_compare(
    const void *a,
    const void *b)
{
    const edge_t *ea = a;
    const edge_t *eb = b;

    if(ea->row < eb->row)
        return -1;

    if(ea->row > eb->row)
        return 1;

    if(ea->col < eb->col)
        return -1;

    if(ea->col > eb->col)
        return 1;

    return 0;
}

int ldpc_load_mat(
    const char *filename,
    ldpc_matrix_t *H)
{
    FILE *fp;

    char line[256];

    int rows = 0;
    int cols = 0;
    int nnz  = 0;

    edge_t *edges = NULL;

    fp = fopen(filename, "r");

    if(!fp)
    {
        fprintf(stderr,
            "cannot open %s\n",
            filename);

        return -1;
    }

    while(fgets(line, sizeof(line), fp))
    {
        if(sscanf(line,
            "# rows: %d",
            &rows) == 1)
        {
            continue;
        }

        if(sscanf(line,
            "# columns: %d",
            &cols) == 1)
        {
            continue;
        }

        if(sscanf(line,
            "# nnz: %d",
            &nnz) == 1)
        {
            continue;
        }

        if(line[0] >= '0' &&
           line[0] <= '9')
        {
            break;
        }
    }

    if(rows <= 0 ||
       cols <= 0 ||
       nnz <= 0)
    {
        fprintf(stderr,
            "invalid .mat header\n");

        fclose(fp);

        return -1;
    }

    edges =
        checked_malloc(
            nnz * sizeof(edge_t));

    int r, c, v;

    sscanf(line, "%d %d %d", &r, &c, &v);

    edges[0].row = r - 1;
    edges[0].col = c - 1;

    for(int i = 1; i < nnz; i++)
    {
        if(!fgets(line, sizeof(line), fp))
        {
            fprintf(stderr,
                "unexpected EOF\n");

            free(edges);
            fclose(fp);

            return -1;
        }

        sscanf(line,
            "%d %d %d",
            &r,
            &c,
            &v);

        edges[i].row = r - 1;
        edges[i].col = c - 1;
    }

    fclose(fp);

    qsort(
        edges,
        nnz,
        sizeof(edge_t),
        edge_compare);

    H->M = rows;
    H->N = cols;
    H->E = nnz;

    H->row_ptr =
        checked_malloc(
            (rows + 1) * sizeof(int));

    H->col_idx =
        checked_malloc(
            nnz * sizeof(int));

    int edge_index = 0;

    H->row_ptr[0] = 0;

    for(int row = 0; row < rows; row++)
    {
        while(edge_index < nnz &&
              edges[edge_index].row == row)
        {
            edge_index++;
        }

        H->row_ptr[row + 1] =
            edge_index;
    }

    for(int i = 0; i < nnz; i++)
    {
        H->col_idx[i] =
            edges[i].col;
    }

    free(edges);

    return 0;
}

void ldpc_free(
    ldpc_matrix_t *H)
{
    free(H->row_ptr);
    free(H->col_idx);

    H->row_ptr = NULL;
    H->col_idx = NULL;

    H->M = 0;
    H->N = 0;
    H->E = 0;
}

static int ldpc_check_syndrome(
    const ldpc_matrix_t *H,
    const uint8_t *bits)
{
    for(int m = 0; m < H->M; m++)
    {
        int parity = 0;

        for(int e = H->row_ptr[m];
            e < H->row_ptr[m + 1];
            e++)
        {
            int vn = H->col_idx[e];

            parity ^= bits[vn];
        }

        if(parity)
        {
            return 0;
        }
    }

    return 1;
}

int ldpc_decode_layered_oms(
    const ldpc_matrix_t *H,
    const float *llr_in,
    uint8_t *bits_out,
    int max_iterations,
    float offset)
{
    float *llr;
    float *cn_msg;

    llr =
        checked_malloc(
            H->N * sizeof(float));

    cn_msg =
        checked_malloc(
            H->E * sizeof(float));

    memcpy(
        llr,
        llr_in,
        H->N * sizeof(float));

    memset(
        cn_msg,
        0,
        H->E * sizeof(float));

    for(int iter = 0;
        iter < max_iterations;
        iter++)
    {
        for(int m = 0; m < H->M; m++)
        {
            int start =
                H->row_ptr[m];

            int end =
                H->row_ptr[m + 1];

            float min1 = 1e30f;
            float min2 = 1e30f;

            int min1_edge = -1;

            int sign_product = 0;

            //
            // First pass
            //

            for(int e = start;
                e < end;
                e++)
            {
                int vn =
                    H->col_idx[e];

                float v2c =
                    llr[vn] - cn_msg[e];

                float av =
                    fabsf(v2c);

                if(av < min1)
                {
                    min2 = min1;
                    min1 = av;
                    min1_edge = e;
                }
                else if(av < min2)
                {
                    min2 = av;
                }

                if(v2c < 0.0f)
                {
                    sign_product ^= 1;
                }
            }

            min1 -= offset;
            min2 -= offset;

            if(min1 < 0.0f)
                min1 = 0.0f;

            if(min2 < 0.0f)
                min2 = 0.0f;

            //
            // Second pass
            //

            for(int e = start;
                e < end;
                e++)
            {
                int vn =
                    H->col_idx[e];

                float old_msg =
                    cn_msg[e];

                float v2c =
                    llr[vn] - old_msg;

                float magnitude;

                if(e == min1_edge)
                {
                    magnitude = min2;
                }
                else
                {
                    magnitude = min1;
                }

                int sign =
                    sign_product;

                if(v2c < 0.0f)
                {
                    sign ^= 1;
                }

                float new_msg;

                if(sign)
                {
                    new_msg = -magnitude;
                }
                else
                {
                    new_msg = magnitude;
                }

                cn_msg[e] = new_msg;

                //
                // Layered VN update
                //

                llr[vn] =
                    v2c + new_msg;
            }
        }

        //
        // Hard decision
        //

        for(int n = 0; n < H->N; n++)
        {
            if(llr[n] < 0.0f)
            {
                bits_out[n] = 1;
            }
            else
            {
                bits_out[n] = 0;
            }
        }

        //
        // Early stop
        //

        if(ldpc_check_syndrome(H, bits_out))
        {
            free(llr);
            free(cn_msg);

            return iter + 1;
        }
    }

    free(llr);
    free(cn_msg);

    return max_iterations;
}