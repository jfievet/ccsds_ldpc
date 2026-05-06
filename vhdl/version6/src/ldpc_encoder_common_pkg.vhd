library ieee;
use ieee.std_logic_1164.all;

package ldpc_encoder_common_pkg is
  constant C_LDPC_QC_ROM_STYLE : string := "auto";--"block";
  type t_std_logic_vector_array is array (natural range <>) of std_logic_vector;
end package ldpc_encoder_common_pkg;