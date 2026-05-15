library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sp_ram_rf is
  generic (
    G_ADDR_W : positive := 11;
    G_DATA_W : positive := 36
  );
  port (
    clk_i  : in  std_logic;
    en_i   : in  std_logic;
    we_i   : in  std_logic;
    addr_i : in  std_logic_vector(G_ADDR_W-1 downto 0);
    di_i   : in  std_logic_vector(G_DATA_W-1 downto 0);
    do_o   : out std_logic_vector(G_DATA_W-1 downto 0)
  );
end entity;

architecture rtl of sp_ram_rf is
  constant C_DEPTH : integer := 2**G_ADDR_W;
  type ram_t is array (0 to C_DEPTH-1) of std_logic_vector(G_DATA_W-1 downto 0);
  signal ram : ram_t := (others => (others => '0'));
  signal do_r : std_logic_vector(G_DATA_W-1 downto 0) := (others => '0');
begin
  do_o <= do_r;
  p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if en_i = '1' then
        do_r <= ram(to_integer(unsigned(addr_i)));
        if we_i = '1' then
          ram(to_integer(unsigned(addr_i))) <= di_i;
        end if;
      end if;
    end if;
  end process;
end architecture;
