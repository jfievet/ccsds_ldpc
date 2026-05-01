library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity ldpc_message_buffer is
  port (
    clock_i         : in  std_logic;
    reset_i         : in  std_logic;
    data_i          : in  std_logic;
    data_en_i       : in  std_logic;
    data_start_i    : in  std_logic;
    ram_wr_en_o     : out std_logic;
    ram_wr_addr_o   : out std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    ram_wr_data_o   : out std_logic;
    message_valid_o : out std_logic
  );
end entity ldpc_message_buffer;

architecture rtl of ldpc_message_buffer is
  signal write_index : natural range 0 to LDPC_K - 1 := 0;
  signal capturing   : std_logic := '0';
begin
  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        ram_wr_en_o     <= '0';
        ram_wr_addr_o   <= (others => '0');
        ram_wr_data_o   <= '0';
        write_index     <= 0;
        capturing       <= '0';
        message_valid_o <= '0';
      else
        ram_wr_en_o <= '0';
        message_valid_o <= '0';

        if data_en_i = '1' then
          if data_start_i = '1' then
            ram_wr_en_o <= '1';
            ram_wr_addr_o <= (others => '0');
            ram_wr_data_o <= data_i;
            if LDPC_K = 1 then
              write_index <= 0;
              capturing <= '0';
              message_valid_o <= '1';
            else
              write_index <= 1;
              capturing <= '1';
            end if;
          elsif capturing = '1' then
            ram_wr_en_o <= '1';
            ram_wr_addr_o <= std_logic_vector(to_unsigned(write_index, LDPC_MESSAGE_INDEX_WIDTH));
            ram_wr_data_o <= data_i;
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