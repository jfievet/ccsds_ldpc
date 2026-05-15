library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tdp_ram_rf_rf is
  generic (
    G_ADDR_W : positive := 12;
    G_DATA_W : positive := 6
  );
  port (
    clk_i : in  std_logic;

    -- Port A
    ena_i   : in  std_logic;
    wea_i   : in  std_logic;
    addra_i : in  std_logic_vector(G_ADDR_W-1 downto 0);
    dia_i   : in  std_logic_vector(G_DATA_W-1 downto 0);
    doa_o   : out std_logic_vector(G_DATA_W-1 downto 0);

    -- Port B
    enb_i   : in  std_logic;
    web_i   : in  std_logic;
    addrb_i : in  std_logic_vector(G_ADDR_W-1 downto 0);
    dib_i   : in  std_logic_vector(G_DATA_W-1 downto 0);
    dob_o   : out std_logic_vector(G_DATA_W-1 downto 0)
  );
end entity;

architecture rtl of tdp_ram_rf_rf is
  
  constant C_DEPTH : integer := 2**G_ADDR_W;
  type ram_t is array (0 to C_DEPTH-1) of std_logic_vector(G_DATA_W-1 downto 0);
  signal ram : ram_t := (others => (others => '0'));
  signal doa_r : std_logic_vector(G_DATA_W-1 downto 0) := (others => '0');
  signal dob_r : std_logic_vector(G_DATA_W-1 downto 0) := (others => '0');

begin

  doa_o <= doa_r;
  dob_o <= dob_r;

  -- Read-first behavior on each port, single shared clock.
  pr : process(clk_i)
  begin
    if rising_edge(clk_i) then

      if ena_i = '1' then
        doa_r <= ram(to_integer(unsigned(addra_i)));
        if wea_i = '1' then
          ram(to_integer(unsigned(addra_i))) <= dia_i;
        end if;
      end if;

      if enb_i = '1' then
        dob_r <= ram(to_integer(unsigned(addrb_i)));
        if web_i = '1' then
          ram(to_integer(unsigned(addrb_i))) <= dib_i;
        end if;
      end if;
      
    end if;
  end process;

end architecture;
