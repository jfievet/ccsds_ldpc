/*
 * generate_constants.c
 *
 * Exact C equivalent of your Python generator.
 * Fully compatible with qc_encoder.h.
 *
 * Compile:
 *   gcc -O2 -std=c11 generate_constants.c -o generate_constants
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define MAX_LINE 512
#define MAX_CONFIGS 9

/* ============================================================
 * INPUT CONFIG STRUCTURE (internal only)
 * ============================================================ */

typedef struct
{
    int selection;
    const char *name;
    const char *g_path;
    int info_length;
    int transmitted_length;
    int full_length;
    int row_blocks;
    int col_blocks;
    int block_size;
} qc_config_input;

/* ============================================================
 * SUPPORTED CONFIGS
 * ============================================================ */

static const qc_config_input CONFIGS[] =
{
    {1,"rate_1_2_1k","../build_g/G_1_2_1024.mat",1024,2048,2560,8,8,128},
    {2,"rate_1_2_4k","../build_g/G_1_2_4096.mat",4096,8192,10240,8,8,512},
    {3,"rate_1_2_16k","../build_g/G_1_2_16384.mat",16384,32768,40960,8,8,2048},

    {4,"rate_2_3_1k","../build_g/G_2_3_1024.mat",1024,1536,1792,16,8,64},
    {5,"rate_2_3_4k","../build_g/G_2_3_4096.mat",4096,6144,7168,16,8,256},
    {6,"rate_2_3_16k","../build_g/G_2_3_16384.mat",16384,24576,28672,16,8,1024},

    {7,"rate_4_5_1k","../build_g/G_4_5_1024.mat",1024,1280,1408,32,8,32},
    {8,"rate_4_5_4k","../build_g/G_4_5_4096.mat",4096,5120,5632,32,8,128},
    {9,"rate_4_5_16k","../build_g/G_4_5_16384.mat",16384,20480,22528,32,8,512}
};

static const int CONFIG_COUNT =
    sizeof(CONFIGS)/sizeof(CONFIGS[0]);

/* ============================================================
 * LOAD OCTAVE SPARSE MATRIX
 * ============================================================ */

static uint64_t *load_octave_sparse_text_mat(
    const qc_config_input *cfg,
    int *out_block_words)
{
    FILE *fp = fopen(cfg->g_path,"r");
    if(!fp)
    {
        fprintf(stderr,"Cannot open %s\n",cfg->g_path);
        return NULL;
    }

    int rows=-1, cols=-1;
    int block_words = (cfg->block_size + 63)/64;
    *out_block_words = block_words;

    uint64_t *block_rows = NULL;

    char line[MAX_LINE];

    while(fgets(line,sizeof(line),fp))
    {
        if(line[0]=='#')
        {
            if(strncmp(line,"# rows:",7)==0)
                rows = atoi(line+7);

            else if(strncmp(line,"# columns:",10)==0)
            {
                cols = atoi(line+10);

                block_rows = calloc(
                    rows *
                    cfg->col_blocks *
                    block_words,
                    sizeof(uint64_t));

                if(!block_rows)
                {
                    fclose(fp);
                    return NULL;
                }
            }
            continue;
        }

        if(!block_rows)
            continue;

        int row,col,value;

        if(sscanf(line,"%d %d %d",&row,&col,&value)!=3)
            continue;

        row--; col--;

        if(!value)
            continue;

        if((row % cfg->block_size)==0 &&
           col>=cfg->info_length &&
           col<cfg->transmitted_length)
        {
            int transmitted_col = col - cfg->info_length;
            int col_block = transmitted_col / cfg->block_size;
            int bit_index = transmitted_col % cfg->block_size;

            int word_index = bit_index / 64;
            int bit_offset = bit_index % 64;

            block_rows[
                row * cfg->col_blocks * block_words +
                col_block * block_words +
                word_index
            ] |= ((uint64_t)1 << bit_offset);
        }
    }

    fclose(fp);

    if(rows!=cfg->info_length ||
       cols!=cfg->full_length)
    {
        fprintf(stderr,"Dimension mismatch in %s\n",cfg->g_path);
        free(block_rows);
        return NULL;
    }

    return block_rows;
}

/* ============================================================
 * HEADER GENERATION (MATCHES qc_encoder.h)
 * ============================================================ */

static int emit_header(
    const qc_config_input *configs,
    uint64_t **flat_data,
    int *flat_sizes,
    int *block_words_array,
    int config_count)
{
    FILE *fp = fopen("qc_encoder_constants.h","w");
    if(!fp)
        return -1;

    fprintf(fp,"#ifndef QC_ENCODER_CONSTANTS_H\n");
    fprintf(fp,"#define QC_ENCODER_CONSTANTS_H\n\n");
    fprintf(fp,"#include <stdint.h>\n");
    fprintf(fp,"#include \"qc_encoder.h\"\n\n");

    /* ---- Circulant arrays ---- */

    for(int c=0;c<config_count;c++)
    {
        const qc_config_input *cfg=&configs[c];

        fprintf(fp,
        "static const uint64_t qc_circulant_first_rows_cfg_%d[] = {\n",
        cfg->selection);

        for(int i=0;i<flat_sizes[c];i++)
        {
            fprintf(fp,"    UINT64_C(0x%016llx)%s\n",
                (unsigned long long)flat_data[c][i],
                (i+1<flat_sizes[c])?",":"");
        }

        fprintf(fp,"};\n\n");
    }

    /* ---- Config table ---- */

    fprintf(fp,"static const qc_encoder_config k_qc_encoder_configs[] = {\n");

    for(int c=0;c<config_count;c++)
    {
        const qc_config_input *cfg=&configs[c];
        int block_words = block_words_array[c];
        int parity = cfg->transmitted_length - cfg->info_length;

        fprintf(fp,"    {\n");
        fprintf(fp,"        %d,\n",cfg->selection);
        fprintf(fp,"        \"%s\",\n",cfg->name);
        fprintf(fp,"        \"%s\",\n",cfg->g_path);   // maps to g_matrix_path
        fprintf(fp,"        %d,\n",cfg->info_length);
        fprintf(fp,"        %d,\n",cfg->transmitted_length);
        fprintf(fp,"        %d,\n",cfg->full_length);
        fprintf(fp,"        %d,\n",cfg->row_blocks);
        fprintf(fp,"        %d,\n",cfg->col_blocks);
        fprintf(fp,"        %d,\n",cfg->block_size);
        fprintf(fp,"        %d,\n",block_words);
        fprintf(fp,"        %d,\n",parity);
        fprintf(fp,"        qc_circulant_first_rows_cfg_%d\n",
                cfg->selection);               // maps to first_rows
        fprintf(fp,"    },\n");
    }

    fprintf(fp,"};\n\n");

    fprintf(fp,
    "static const int k_qc_encoder_config_count = "
    "(int)(sizeof(k_qc_encoder_configs) / "
    "sizeof(k_qc_encoder_configs[0]));\n\n");

    fprintf(fp,"#endif\n");

    fclose(fp);
    return 0;
}

/* ============================================================
 * MAIN
 * ============================================================ */

int main(void)
{
    uint64_t *flat_data[MAX_CONFIGS]={0};
    int flat_sizes[MAX_CONFIGS]={0};
    int block_words_array[MAX_CONFIGS]={0};

    for(int c=0;c<CONFIG_COUNT;c++)
    {
        const qc_config_input *cfg=&CONFIGS[c];

        int block_words=0;
        uint64_t *block_rows=
            load_octave_sparse_text_mat(cfg,&block_words);

        if(!block_rows)
            return EXIT_FAILURE;

        block_words_array[c]=block_words;

        int total_words =
            cfg->row_blocks *
            cfg->col_blocks *
            block_words;

        uint64_t *flat=
            malloc(total_words*sizeof(uint64_t));

        if(!flat)
            return EXIT_FAILURE;

        int out_index=0;

        for(int rb=0;rb<cfg->row_blocks;rb++)
        {
            int row_start = rb * cfg->block_size;

            for(int cb=0;cb<cfg->col_blocks;cb++)
            {
                uint64_t *first_row =
                    &block_rows[
                        row_start *
                        cfg->col_blocks *
                        block_words +
                        cb * block_words];

                for(int w=0;w<block_words;w++)
                    flat[out_index++]=first_row[w];
            }
        }

        flat_data[c]=flat;
        flat_sizes[c]=total_words;

        free(block_rows);

        printf("Validated config %d: %s\n",
               cfg->selection,cfg->name);
    }

    if(emit_header(CONFIGS,
                   flat_data,
                   flat_sizes,
                   block_words_array,
                   CONFIG_COUNT)!=0)
        return EXIT_FAILURE;

    printf("Wrote qc_encoder_constants.h\n");

    for(int i=0;i<CONFIG_COUNT;i++)
        free(flat_data[i]);

    return EXIT_SUCCESS;
}