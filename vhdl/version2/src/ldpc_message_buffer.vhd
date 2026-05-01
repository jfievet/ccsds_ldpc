library ieee;
use ieee.std_logic_1164.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity ldpc_message_buffer is
  port (
    clock_i         : in  std_logic;
    reset_i         : in  std_logic;
    data_i          : in  std_logic;
    data_en_i       : in  std_logic;
    data_start_i    : in  std_logic;
    message_bits_o  : out std_logic_vector(0 to LDPC_K - 1);
    message_valid_o : out std_logic
  );
end entity ldpc_message_buffer;

architecture rtl of ldpc_message_buffer is
  signal message_bits : std_logic_vector(0 to LDPC_K - 1) := (others => '0');
  signal write_index  : natural range 0 to LDPC_K - 1 := 0;
  signal capturing    : std_logic := '0';
begin
  message_bits_o <= message_bits;

  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        message_bits    <= (others => '0');
        write_index     <= 0;
        capturing       <= '0';
        message_valid_o <= '0';
      else
        message_valid_o <= '0';

        if data_en_i = '1' then
          if data_start_i = '1' then
            message_bits(0) <= data_i;
            if LDPC_K = 1 then
              write_index <= 0;
              capturing <= '0';
              message_valid_o <= '1';
            else
              write_index <= 1;
              capturing <= '1';
            end if;
          elsif capturing = '1' then
            message_bits(write_index) <= data_i;
            if write_index = LDPC_K - 1 then
              write_index <= 0;
              capturing <= '0';
              message_valid_o <= '1';
            else
              write_index <= write_index + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;