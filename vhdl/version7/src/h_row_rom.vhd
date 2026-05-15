library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.h_row_rom_pkg.all;

entity h_row_rom is
  generic (
    G_M     : positive := 1536;
    G_IDX_W : positive := 12
  );
  port (
    clk_i : in  std_logic;
    en_i  : in  std_logic;
    row_i : in  std_logic_vector(10 downto 0); -- log2(1536)=11

    idx0_o : out std_logic_vector(G_IDX_W-1 downto 0);
    idx1_o : out std_logic_vector(G_IDX_W-1 downto 0);
    idx2_o : out std_logic_vector(G_IDX_W-1 downto 0);
    idx3_o : out std_logic_vector(G_IDX_W-1 downto 0);
    idx4_o : out std_logic_vector(G_IDX_W-1 downto 0);
    idx5_o : out std_logic_vector(G_IDX_W-1 downto 0)
  );
end entity;

architecture rtl of h_row_rom is
  signal r0, r1, r2 : std_logic_vector(2*G_IDX_W-1 downto 0) := (others => '0');
begin
  p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if en_i = '1' then
        r0 <= H_ROM0(to_integer(unsigned(row_i)));
        r1 <= H_ROM1(to_integer(unsigned(row_i)));
        r2 <= H_ROM2(to_integer(unsigned(row_i)));
      end if;
    end if;
  end process;

  idx0_o <= r0(2*G_IDX_W-1 downto 1*G_IDX_W);
  idx1_o <= r0(1*G_IDX_W-1 downto 0*G_IDX_W);
  idx2_o <= r1(2*G_IDX_W-1 downto 1*G_IDX_W);
  idx3_o <= r1(1*G_IDX_W-1 downto 0*G_IDX_W);
  idx4_o <= r2(2*G_IDX_W-1 downto 1*G_IDX_W);
  idx5_o <= r2(1*G_IDX_W-1 downto 0*G_IDX_W);
end architecture;

