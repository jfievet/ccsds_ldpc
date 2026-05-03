library ieee;
use ieee.std_logic_1164.all;

package ldpc_encoder_16k_23_config_pkg is
  constant LDPC_K : natural := 16384;
  constant LDPC_N : natural := 24576;
  constant LDPC_TOTAL_LENGTH : natural := 28672;
  constant LDPC_M : natural := 4096;

  constant LDPC_QC_ROW_BLOCKS : natural := 16;
  constant LDPC_QC_COL_BLOCKS : natural := 8;
  constant LDPC_QC_BLOCK_SIZE : natural := 1024;
  constant LDPC_QC_PARITY_LENGTH : natural := 8192;
end package ldpc_encoder_16k_23_config_pkg;
