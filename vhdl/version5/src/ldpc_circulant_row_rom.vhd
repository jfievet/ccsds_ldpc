library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ldpc_encoder_1k_1_2_config_pkg.all;
use work.ldpc_encoder_1k_1_2_qc_rom_pkg.all;

entity ldpc_circulant_row_rom is
  generic (
    G_ROM_INDEX : natural range 0 to LDPC_QC_COL_BLOCKS - 1 := 0
  );
  port (
    row_block_i : in natural range 0 to LDPC_QC_ROW_BLOCKS - 1;
    data_o      : out t_ldpc_block
  );
end entity ldpc_circulant_row_rom;

architecture rtl of ldpc_circulant_row_rom is
begin
  data_o <= C_LDPC_QC_ROM_BANK(G_ROM_INDEX)(row_block_i);
end architecture rtl;