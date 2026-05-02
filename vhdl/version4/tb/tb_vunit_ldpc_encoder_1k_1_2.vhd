library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

library work;
use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity tb_ldpc_encoder_1k_1_2 is
generic (
    runner_cfg    : string
);
end entity tb_ldpc_encoder_1k_1_2;

architecture beh of tb_ldpc_encoder_1k_1_2 is
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
    load_bits("../../../sim/message_ldpc_encoder_1k_1_2.txt", LDPC_K);
  constant EXPECTED_CODEWORD : std_logic_vector(0 to LDPC_N - 1) :=
    load_bits("../../../sim/encoded_frame_ldpc_encoder_1k_1_2.txt", LDPC_N);

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
  signal captured_codeword : std_logic_vector(0 to LDPC_N - 1) := (others => '0');
  signal capture_index : natural range 0 to LDPC_N := 0;
  signal cycle_counter : natural := 0;
  signal input_start_cycle : natural := 0;
  signal first_output_cycle : natural := 0;
  signal frame_done_cycle : natural := 0;
  signal input_started : std_logic := '0';
  signal first_output_seen : std_logic := '0';
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
    test_runner_setup(runner, runner_cfg);
	
    if run("test_001_main") then

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

		wait until capture_index = 2048;
		wait until rising_edge(clock_i);

    info(
      "TB LATENCY: total_cycles=" & integer'image(frame_done_cycle - input_start_cycle) &
      ", output_start_cycles=" & integer'image(first_output_cycle - input_start_cycle) &
      ", output_stream_cycles=" & integer'image(frame_done_cycle - first_output_cycle + 1)
    );

    for bit_index in 0 to LDPC_N - 1 loop
      check_equal(
        captured_codeword(bit_index),
        EXPECTED_CODEWORD(bit_index),
        "Mismatch at bit " & integer'image(bit_index)
      );
    end loop;
    info("TB PASS: encoded frame matches reference vector");

    wait for 10 us;

		
	end if;
	
	test_runner_cleanup(runner);
		
  end process;

  capture_output : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        captured_codeword <= (others => '0');
        capture_index     <= 0;
        cycle_counter <= 0;
        input_start_cycle <= 0;
        first_output_cycle <= 0;
        frame_done_cycle <= 0;
        input_started <= '0';
        first_output_seen <= '0';
      else
        cycle_counter <= cycle_counter + 1;

        if input_started = '0' and data_en_i = '1' and data_start_i = '1' then
          input_start_cycle <= cycle_counter;
          input_started <= '1';
        end if;

        if first_output_seen = '0' and data_en_o = '1' then
          first_output_cycle <= cycle_counter;
          first_output_seen <= '1';
        end if;

        if data_start_o = '1' then
          capture_index <= 0;
        end if;

        if data_en_o = '1' then
          captured_codeword(capture_index) <= data_o;
          if capture_index = LDPC_N - 1 then
            frame_done_cycle <= cycle_counter;
          end if;
          capture_index <= capture_index + 1;
        end if;
      end if;
    end if;
  end process;

end beh;