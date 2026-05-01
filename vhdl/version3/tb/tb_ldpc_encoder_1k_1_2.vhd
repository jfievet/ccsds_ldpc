library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use std.env.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity tb_ldpc_encoder_1k_1_2 is
end entity tb_ldpc_encoder_1k_1_2;

architecture sim of tb_ldpc_encoder_1k_1_2 is
  constant CLK_PERIOD : time := 10 ns;

  impure function load_bits(file_name : string; bit_count : natural) return std_logic_vector is
    file bit_file      : text open read_mode is file_name;
    variable line_in   : line;
    variable value_int : integer;
    variable bits      : std_logic_vector(0 to bit_count - 1) := (others => '0');
    variable index     : natural := 0;
  begin
    while not endfile(bit_file) loop
      readline(bit_file, line_in);
      if line_in'length > 0 then
        read(line_in, value_int);
        assert index < bit_count
          report "Too many bits in " & file_name
          severity failure;
        if value_int = 0 then
          bits(index) := '0';
        else
          bits(index) := '1';
        end if;
        index := index + 1;
      end if;
    end loop;

    assert index = bit_count
      report "Expected " & integer'image(bit_count) & " bits in " & file_name &
             ", got " & integer'image(index)
      severity failure;
    return bits;
  end function load_bits;

  constant MESSAGE_BITS : std_logic_vector(0 to LDPC_K - 1) :=
    load_bits("../sim/message_ldpc_encoder_1k_1_2.txt", LDPC_K);
  constant EXPECTED_CODEWORD : std_logic_vector(0 to LDPC_N - 1) :=
    load_bits("../sim/encoded_frame_ldpc_encoder_1k_1_2.txt", LDPC_N);

  signal clock_i        : std_logic := '0';
  signal reset_i        : std_logic := '1';
  signal data_i         : std_logic := '0';
  signal data_en_i      : std_logic := '0';
  signal data_start_i   : std_logic := '0';
  signal data_o         : std_logic := '0';
  signal data_en_o      : std_logic := '0';
  signal data_start_o   : std_logic := '0';
  signal data_message_o : std_logic := '0';
  signal data_parity_o  : std_logic := '0';

  signal observed_index : natural range 0 to LDPC_N := 0;
  signal frame_done     : std_logic := '0';
begin
  clock_i <= not clock_i after CLK_PERIOD / 2;

  dut : entity work.ldpc_encoder_1k_1_2
    port map (
      clock_i        => clock_i,
      reset_i        => reset_i,
      data_i         => data_i,
      data_en_i      => data_en_i,
      data_start_i   => data_start_i,
      data_o         => data_o,
      data_en_o      => data_en_o,
      data_start_o   => data_start_o,
      data_message_o => data_message_o,
      data_parity_o  => data_parity_o
    );

  reset_process : process
  begin
    reset_i <= '1';
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clock_i);
    reset_i <= '0';
    wait;
  end process;

  stimulus : process
  begin
    wait until reset_i = '0';
    wait until rising_edge(clock_i);

    for bit_index in 0 to LDPC_K - 1 loop
      data_i <= MESSAGE_BITS(bit_index);
      data_en_i <= '1';
      if bit_index = 0 then
        data_start_i <= '1';
      else
        data_start_i <= '0';
      end if;
      wait until rising_edge(clock_i);
    end loop;

    data_i <= '0';
    data_en_i <= '0';
    data_start_i <= '0';

    wait until frame_done = '1';
    wait until rising_edge(clock_i);
    report "TB PASS: encoded frame matches reference vector" severity note;
    wait for 1 us;
  end process;

  monitor : process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        observed_index <= 0;
        frame_done <= '0';
      elsif data_en_o = '1' then
        assert observed_index < LDPC_N
          report "Observed more output bits than expected"
          severity failure;
        assert data_o = EXPECTED_CODEWORD(observed_index)
          report "Encoded bit mismatch at position " & integer'image(observed_index)
          severity failure;

        if observed_index = 0 then
          assert data_start_o = '1'
            report "data_start_o must be asserted on the first output bit"
            severity failure;
        else
          assert data_start_o = '0'
            report "data_start_o must only pulse on the first output bit"
            severity failure;
        end if;

        if observed_index < LDPC_K then
          assert data_message_o = '1' and data_parity_o = '0'
            report "Message/parity qualifiers are incorrect during message output"
            severity failure;
        else
          assert data_message_o = '0' and data_parity_o = '1'
            report "Message/parity qualifiers are incorrect during parity output"
            severity failure;
        end if;

        if observed_index = LDPC_N - 1 then
          observed_index <= LDPC_N;
          frame_done <= '1';
        else
          observed_index <= observed_index + 1;
        end if;
      end if;
    end if;
  end process;
end architecture sim;