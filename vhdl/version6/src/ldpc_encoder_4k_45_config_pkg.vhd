library ieee;
use ieee.std_logic_1164.all;

package ldpc_encoder_4k_45_config_pkg is
  constant LDPC_K : natural := 4096;
  constant LDPC_N : natural := 5120;
  constant LDPC_TOTAL_LENGTH : natural := 5632;
  constant LDPC_M : natural := 512;

  constant LDPC_QC_ROW_BLOCKS : natural := 32;
  constant LDPC_QC_COL_BLOCKS : natural := 8;
  constant LDPC_QC_BLOCK_SIZE : natural := 128;
  constant LDPC_QC_PARITY_LENGTH : natural := 1024;
end package ldpc_encoder_4k_45_config_pkg;
