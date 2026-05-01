library ieee;
use ieee.std_logic_1164.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity ldpc_encoder_1k_1_2 is
  port (
    clock_i         : in  std_logic;
    reset_i         : in  std_logic;
    data_i          : in  std_logic;
    data_en_i       : in  std_logic;
    data_start_i    : in  std_logic;
    data_o          : out std_logic;
    data_en_o       : out std_logic;
    data_start_o    : out std_logic;
    data_message_o  : out std_logic;
    data_parity_o   : out std_logic
  );
end entity ldpc_encoder_1k_1_2;

architecture rtl of ldpc_encoder_1k_1_2 is
  signal message_bits   : std_logic_vector(0 to LDPC_K - 1);
  signal message_valid  : std_logic;
  signal codeword_bits  : std_logic_vector(0 to LDPC_N - 1);
  signal codeword_valid : std_logic;
begin
  message_buffer_inst : entity work.ldpc_message_buffer
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      data_i          => data_i,
      data_en_i       => data_en_i,
      data_start_i    => data_start_i,
      message_bits_o  => message_bits,
      message_valid_o => message_valid
    );

  parity_core_inst : entity work.ldpc_parity_core
    port map (
      clock_i          => clock_i,
      reset_i          => reset_i,
      start_i          => message_valid,
      message_bits_i   => message_bits,
      codeword_bits_o  => codeword_bits,
      codeword_valid_o => codeword_valid
    );

  serializer_inst : entity work.ldpc_output_serializer
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      load_i          => codeword_valid,
      codeword_bits_i => codeword_bits,
      data_o          => data_o,
      data_en_o       => data_en_o,
      data_start_o    => data_start_o,
      data_message_o  => data_message_o,
      data_parity_o   => data_parity_o
    );
end architecture rtl;