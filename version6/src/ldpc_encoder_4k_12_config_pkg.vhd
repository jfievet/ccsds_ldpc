library ieee;
use ieee.std_logic_1164.all;

package ldpc_encoder_4k_12_config_pkg is
  constant LDPC_K : natural := 4096;
  constant LDPC_N : natural := 8192;
  constant LDPC_TOTAL_LENGTH : natural := 10240;
  constant LDPC_M : natural := 2048;

  constant LDPC_QC_ROW_BLOCKS : natural := 8;
  constant LDPC_QC_COL_BLOCKS : natural := 8;
  constant LDPC_QC_BLOCK_SIZE : natural := 512;
  constant LDPC_QC_PARITY_LENGTH : natural := 4096;
end package ldpc_encoder_4k_12_config_pkg;
