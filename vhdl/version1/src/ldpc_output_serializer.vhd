library ieee;
use ieee.std_logic_1164.all;

use work.ldpc_encoder_1k_1_2_constants_pkg.all;

entity ldpc_output_serializer is
  port (
    clock_i          : in  std_logic;
    reset_i          : in  std_logic;
    load_i           : in  std_logic;
    codeword_bits_i  : in  std_logic_vector(0 to LDPC_N - 1);
    data_o           : out std_logic;
    data_en_o        : out std_logic;
    data_start_o     : out std_logic;
    data_message_o   : out std_logic;
    data_parity_o    : out std_logic
  );
end entity ldpc_output_serializer;

architecture rtl of ldpc_output_serializer is
  signal codeword_bits : std_logic_vector(0 to LDPC_N - 1) := (others => '0');
  signal read_index    : natural range 0 to LDPC_N := 0;
  signal streaming     : std_logic := '0';
begin
  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        codeword_bits   <= (others => '0');
        read_index      <= 0;
        streaming       <= '0';
        data_o          <= '0';
        data_en_o       <= '0';
        data_start_o    <= '0';
        data_message_o  <= '0';
        data_parity_o   <= '0';
      else
        data_en_o      <= '0';
        data_start_o   <= '0';
        data_message_o <= '0';
        data_parity_o  <= '0';

        if load_i = '1' then
          codeword_bits <= codeword_bits_i;
          read_index <= 0;
          streaming <= '1';
        elsif streaming = '1' then
          data_o <= codeword_bits(read_index);
          data_en_o <= '1';
          if read_index = 0 then
            data_start_o <= '1';
          end if;

          if read_index < LDPC_K then
            data_message_o <= '1';
          else
            data_parity_o <= '1';
          end if;

          if read_index = LDPC_N - 1 then
            read_index <= 0;
            streaming <= '0';
          else
            read_index <= read_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;