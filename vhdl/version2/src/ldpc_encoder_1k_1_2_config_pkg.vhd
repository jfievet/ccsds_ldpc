library ieee;
use ieee.std_logic_1164.all;

package ldpc_encoder_1k_1_2_config_pkg is
  constant LDPC_RATE_NUMERATOR : natural := 1;
  constant LDPC_RATE_DENOMINATOR : natural := 2;
  constant LDPC_BLOCK_SIZE : natural := 1024;
  constant LDPC_K : natural := 1024;
  constant LDPC_M : natural := 512;
  constant LDPC_N : natural := 2048;
  constant LDPC_TOTAL_LENGTH : natural := 2560;
  constant LDPC_OFFSET_WIDTH : natural := 16;
  constant LDPC_MESSAGE_INDEX_WIDTH : natural := 10;
  constant LDPC_ROW_INDEX_WIDTH : natural := 9;
end package ldpc_encoder_1k_1_2_config_pkg;
