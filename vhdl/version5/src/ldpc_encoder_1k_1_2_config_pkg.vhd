library ieee;
use ieee.std_logic_1164.all;

package ldpc_encoder_1k_1_2_config_pkg is
  constant LDPC_K : natural := 1024;
  constant LDPC_N : natural := 2048;
  constant LDPC_TOTAL_LENGTH : natural := 2560;
  constant LDPC_M : natural := 512;

  constant LDPC_QC_ROW_BLOCKS : natural := 8;
  constant LDPC_QC_COL_BLOCKS : natural := 8;
  constant LDPC_QC_BLOCK_SIZE : natural := 128;
  constant LDPC_QC_PARITY_LENGTH : natural := 1024;

  subtype t_ldpc_block is std_logic_vector(LDPC_QC_BLOCK_SIZE - 1 downto 0);
  type t_ldpc_block_array is array (0 to LDPC_QC_COL_BLOCKS - 1) of t_ldpc_block;
end package ldpc_encoder_1k_1_2_config_pkg;