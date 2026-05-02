library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity ldpc_codeword_ram is
  port (
    clock_i   : in  std_logic;
    wr_en_i   : in  std_logic;
    wr_addr_i : in  std_logic_vector(LDPC_CODEWORD_INDEX_WIDTH - 1 downto 0);
    wr_data_i : in  std_logic;
    rd_addr_i : in  std_logic_vector(LDPC_CODEWORD_INDEX_WIDTH - 1 downto 0);
    rd_data_o : out std_logic
  );
end entity ldpc_codeword_ram;

architecture rtl of ldpc_codeword_ram is
  type ram_t is array (0 to LDPC_N - 1) of std_logic;
  signal ram     : ram_t := (others => '0');
  signal rd_data : std_logic := '0';

  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";
begin
  rd_data_o <= rd_data;

  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if wr_en_i = '1' then
        ram(to_integer(unsigned(wr_addr_i))) <= wr_data_i;
      end if;

      rd_data <= ram(to_integer(unsigned(rd_addr_i)));
    end if;
  end process;
end architecture rtl;