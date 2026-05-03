#ifndef QC_ENCODER_CONSTANTS_H
#define QC_ENCODER_CONSTANTS_H

#include <stdint.h>

#define QC_ROW_BLOCKS 8
#define QC_COL_BLOCKS 8
#define QC_BLOCK_SIZE 128
#define QC_INFO_LENGTH 1024
#define QC_TRANSMITTED_PARITY_LENGTH 1024

static const uint64_t qc_circulant_first_rows[QC_ROW_BLOCKS][QC_COL_BLOCKS][2] = {
    {
        { UINT64_C(0x1b05a5f92f29e5f3), UINT64_C(0xdd157e53f1b8cdd1) },
        { UINT64_C(0xc701a165177e75e5), UINT64_C(0x214d9acc879f4497) },
        { UINT64_C(0x1efd6b4f1754ef89), UINT64_C(0xc62bdb3cdc1f850c) },
        { UINT64_C(0x0ec906f83703a973), UINT64_C(0x7839440e1389e7eb) },
        { UINT64_C(0x21e14706fbfcf78e), UINT64_C(0x3b937ba14db2c91e) },
        { UINT64_C(0xb3d6d100c083a970), UINT64_C(0x0844ce753a1f5b4b) },
        { UINT64_C(0xf6a5df83c17764c1), UINT64_C(0x4fe7f8cdbb4da8bb) },
        { UINT64_C(0xbde63c1fc2dd05dc), UINT64_C(0x4672f75627756f85) }
    },
    {
        { UINT64_C(0x535915301ec10a6a), UINT64_C(0xac7511152df330e5) },
        { UINT64_C(0x334069370b5f0848), UINT64_C(0xc5699cb6150d6931) },
        { UINT64_C(0x432a2ce5bbfe0d03), UINT64_C(0x017200abd4efa94a) },
        { UINT64_C(0x938640c3fce9f335), UINT64_C(0xbd6005d3055a4a09) },
        { UINT64_C(0x1fefa02590f9e0f9), UINT64_C(0x7e54f69094219b5e) },
        { UINT64_C(0x2760321dc8d931d7), UINT64_C(0x14a395916e25c214) },
        { UINT64_C(0xf3b19afae858555b), UINT64_C(0x9e2b5c253642b5db) },
        { UINT64_C(0xd71cfae764c1e5d8), UINT64_C(0xa4265c0ca2590b76) }
    },
    {
        { UINT64_C(0x8a059dedcc042f12), UINT64_C(0x1978940939c13b92) },
        { UINT64_C(0x64343e50a7d734d9), UINT64_C(0x91ac602e6be763f2) },
        { UINT64_C(0xd6084efd757b6daf), UINT64_C(0x2c8e8326a6e66795) },
        { UINT64_C(0x898ac4b1aa2a9ab6), UINT64_C(0x2c67100eb11f550a) },
        { UINT64_C(0xfa5261d5df4695f8), UINT64_C(0x55e1072f36b93e61) },
        { UINT64_C(0x31b8d25d2e655eba), UINT64_C(0xdc4dcb8f618975eb) },
        { UINT64_C(0x6de97789e488fe20), UINT64_C(0xa9729dcff1adedfc) },
        { UINT64_C(0x1d663a6c659c7dc9), UINT64_C(0xdaf4e5a6968cb5ee) }
    },
    {
        { UINT64_C(0x63b00392711f1ad8), UINT64_C(0x1105144ffdaa1acd) },
        { UINT64_C(0xd6637786de2b713a), UINT64_C(0xcf37d3a676df200a) },
        { UINT64_C(0x7a49017f19991eee), UINT64_C(0xdafa32070eafec40) },
        { UINT64_C(0x41c3fed7866ee6b7), UINT64_C(0x310103169babad5a) },
        { UINT64_C(0x82fc9a98d141dbd4), UINT64_C(0x36c8fb82b0b1d8e6) },
        { UINT64_C(0x0570fcd93caae2d3), UINT64_C(0xbe567ac32aa83368) },
        { UINT64_C(0x71904b8957fe1ae9), UINT64_C(0x651a61e33ce57648) },
        { UINT64_C(0x5361810488e987b5), UINT64_C(0xa23096a85e82e3a9) }
    },
    {
        { UINT64_C(0x9b9cc911b968397d), UINT64_C(0xef9bf3a156e932a6) },
        { UINT64_C(0x5b48e2dc712823e2), UINT64_C(0x5cbce18eb58b5dc5) },
        { UINT64_C(0x9dd7a342c30c6b38), UINT64_C(0x717294f7d97b5c18) },
        { UINT64_C(0xaef69fa5ee03280e), UINT64_C(0x380b269661366a7d) },
        { UINT64_C(0x6684b5ac5c2354e7), UINT64_C(0xdd9feed9a4cdd74e) },
        { UINT64_C(0x0f85f29890d15b18), UINT64_C(0xf9c56b9301056e17) },
        { UINT64_C(0x971711bc5168d901), UINT64_C(0x43b434c4a73a99bc) },
        { UINT64_C(0x5146fc6c5225f3e3), UINT64_C(0xf69f5319c362b166) }
    },
    {
        { UINT64_C(0x8535e47524ddbeab), UINT64_C(0x6108551d8571f68e) },
        { UINT64_C(0xabf8f6152f69eede), UINT64_C(0xca916380b56eae32) },
        { UINT64_C(0x6c41224099e7dae7), UINT64_C(0x0df555ef1a6960f1) },
        { UINT64_C(0xa4b1e7a9ef5cfae9), UINT64_C(0x6feed2f2d8e38e1a) },
        { UINT64_C(0xb4154dd9ac39b3a6), UINT64_C(0x82bbd668e007caca) },
        { UINT64_C(0x8de40db28ce22a34), UINT64_C(0x8b19c0b58e00c8d0) },
        { UINT64_C(0x056f3dd65e3d987b), UINT64_C(0xa504948fd55840ff) },
        { UINT64_C(0x94791f5212b75d1a), UINT64_C(0x96cb8f730e83db2b) }
    },
    {
        { UINT64_C(0x3ada8788b4d0cc32), UINT64_C(0x651cca06907a81cd) },
        { UINT64_C(0x1470782ac58bc7ae), UINT64_C(0x79513cb16b6aa6f2) },
        { UINT64_C(0x4b346dbe94dcdda7), UINT64_C(0x2f05e6969990fe09) },
        { UINT64_C(0x4a5251347775ccff), UINT64_C(0x39c3aacb9c3af33f) },
        { UINT64_C(0x0733d65d590fa7fa), UINT64_C(0x4357e1fa7802ce54) },
        { UINT64_C(0xfb0e6eaf2f40eaeb), UINT64_C(0x577c4af40038d0e5) },
        { UINT64_C(0xd3042ba074738736), UINT64_C(0x95ca71d668037e61) },
        { UINT64_C(0xb1a0cc3858019fb9), UINT64_C(0x9ddd1e4e7505688b) }
    },
    {
        { UINT64_C(0xdbf1bb49e30d0f32), UINT64_C(0xbc66fed4f675737c) },
        { UINT64_C(0x3283e27694385608), UINT64_C(0xadf7beaba20d1928) },
        { UINT64_C(0xc3c6409e31b6f169), UINT64_C(0x84f8309f7e0cf3ca) },
        { UINT64_C(0x1a72866f4c6d6766), UINT64_C(0xc518eec3690f7e64) },
        { UINT64_C(0x6d7c99708ba762bc), UINT64_C(0xd85b7a11f18a81fb) },
        { UINT64_C(0xb971dd12bf18aff6), UINT64_C(0x91d7af2f0352b7db) },
        { UINT64_C(0x9ecdba6584b2633d), UINT64_C(0xff908f843b2747d5) },
        { UINT64_C(0xbce902bade730374), UINT64_C(0x08f6380dc8ef37c8) }
    }
};

#endif
