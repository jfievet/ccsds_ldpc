library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_offset_min_sum_decoder is
  generic (
    runner_cfg : string;
    vector_dir : string := "../tb/vectors"
  );
end entity;

architecture tb of tb_offset_min_sum_decoder is
  constant C_CLK_PERIOD : time := 10 ns;

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';

  signal data_i        : std_logic_vector(5 downto 0) := (others => '0');
  signal data_valid_i  : std_logic := '0';
  signal data_start_i  : std_logic := '0';
  signal iter_cfg_i    : std_logic_vector(7 downto 0) := (others => '0');

  signal data_o        : std_logic;
  signal data_valid_o  : std_logic;
  signal data_start_o  : std_logic;

  signal step          : integer:=0;

  procedure drive_frame(
    signal iter_cfg_o   : out std_logic_vector(7 downto 0);
    signal data_start_o : out std_logic;
    signal data_o       : out std_logic_vector(5 downto 0);
    signal data_valid_o : out std_logic;
    signal clk_i        : in  std_logic;
    constant llr_path   : in  string;
    constant iters      : in  integer
  ) is
    file f : text open read_mode is llr_path;
    variable l : line;
    variable v : integer;
  begin
    iter_cfg_o <= std_logic_vector(to_unsigned(iters, 8));
    data_start_o <= '1';
    wait until rising_edge(clk_i);
    data_start_o <= '0';

    for i in 0 to 2047 loop
      readline(f, l);
      read(l, v);
      data_o <= std_logic_vector(to_signed(v, 6));
      data_valid_o <= '1';
      wait until rising_edge(clk_i);
    end loop;
    data_valid_o <= '0';
    file_close(f);
  end procedure;

    procedure drive_null_frame(
    signal iter_cfg_o   : out std_logic_vector(7 downto 0);
    signal data_start_o : out std_logic;
    signal data_o       : out std_logic_vector(5 downto 0);
    signal data_valid_o : out std_logic;
    signal clk_i        : in  std_logic;
    constant iters      : in  integer
  ) is
  begin
    iter_cfg_o <= std_logic_vector(to_unsigned(iters, 8));
    data_start_o <= '1';
    wait until rising_edge(clk_i);
    data_start_o <= '0';

    for i in 0 to 2047 loop
      data_o <= "011111";
      data_valid_o <= '1';
      wait until rising_edge(clk_i);
    end loop;
    data_valid_o <= '0';
  end procedure;

begin
  clk <= not clk after C_CLK_PERIOD/2;

  u_dut : entity work.offset_min_sum_decoder
    generic map (G_OFFSET_Q => 0)
    port map (
      clk_i => clk,
      rst_i => rst,
      data_i => data_i,
      data_valid_i => data_valid_i,
      data_start_i => data_start_i,
      iter_cfg_i => iter_cfg_i,
      data_o => data_o,
      data_valid_o => data_valid_o,
      data_start_o => data_start_o
    );

  p_stim : process
    file fbits : text;
    variable l : line;
    variable v : integer;
    variable exp : std_logic;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("test_001_main") then
        step <= 0;
        rst <= '1';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

--    step <= 1;
--    drive_frame(iter_cfg_i, data_start_i, data_i, data_valid_i, clk, "../tb/vectors/llr_zero.txt", 10);
--    file_open(fbits, "../tb/vectors/bits_zero_it10.txt", read_mode);
--    --wait until rising_edge(clk) and data_start_o = '1';
--    step <= 11;
--    for i in 0 to 1023 loop
--      wait until rising_edge(clk) and data_valid_o = '1';
--      readline(fbits, l); read(l, v);
--      exp := '0' when v = 0 else '1';
--      assert data_o = exp report "Mismatch at bit " & integer'image(i) severity failure;
--    end loop;
--    step <= 111;
--    file_close(fbits);

        step <= 2;
        drive_frame(iter_cfg_i, data_start_i, data_i, data_valid_i, clk, vector_dir & "/llr_chain.txt", 5);
        wait for 0.5 ms;
--    file_open(fbits, "../tb/vectors/bits_chain_it5.txt", read_mode);
--    --wait until rising_edge(clk) and data_start_o = '1';
--    for i in 0 to 1023 loop
--      wait until rising_edge(clk) and data_valid_o = '1';
--      readline(fbits, l); read(l, v);
--      exp := '0' when v = 0 else '1';
--      assert data_o = exp report "Mismatch at bit " & integer'image(i) severity failure;
--    end loop;
--    file_close(fbits);
--
--    step <= 3;
--    drive_frame(iter_cfg_i, data_start_i, data_i, data_valid_i, clk, "../tb/vectors/llr_chain.txt", 10);
--    file_open(fbits, "../tb/vectors/bits_chain_it10.txt", read_mode);
--    --wait until rising_edge(clk) and data_start_o = '1';
--    for i in 0 to 1023 loop
--      wait until rising_edge(clk) and data_valid_o = '1';
--      readline(fbits, l); read(l, v);
--      exp := '0' when v = 0 else '1';
--      assert data_o = exp report "Mismatch at bit " & integer'image(i) severity failure;
--    end loop;
--    file_close(fbits);
--
--    step <= 4;
--    report "TB PASSED" severity note;
--    wait;
    end if;

    if run("test_002_all_zeros") then
        step <= 0;
        rst <= '1';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        step <= 2;
        drive_null_frame(iter_cfg_i, data_start_i, data_i, data_valid_i, clk, 5);
        wait for 0.5 ms;

    end if;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
