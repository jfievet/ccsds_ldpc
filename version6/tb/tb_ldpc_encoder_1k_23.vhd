library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

library work;
use work.ldpc_encoder_1k_23_config_pkg.all;
use work.ldpc_encoder_1k_23_vectors_pkg.all;

entity tb_ldpc_encoder_1k_23 is
end entity tb_ldpc_encoder_1k_23;

architecture sim of tb_ldpc_encoder_1k_23 is
  constant CLK_PERIOD : time := 10 ns;

  signal clock_i            : std_logic := '0';
  signal reset_i            : std_logic := '1';
  signal data_i             : std_logic := '0';
  signal data_en_i          : std_logic := '0';
  signal data_start_i       : std_logic := '0';
  signal data_o             : std_logic := '0';
  signal data_en_o          : std_logic := '0';
  signal data_start_o       : std_logic := '0';
  signal data_message_o     : std_logic := '0';
  signal data_parity_o      : std_logic := '0';
  signal observed_index     : natural range 0 to LDPC_N := 0;
  signal frame_done         : std_logic := '0';
  signal cycle_counter      : natural := 0;
  signal input_start_cycle  : natural := 0;
  signal first_output_cycle : natural := 0;
  signal frame_done_cycle   : natural := 0;
  signal input_started      : std_logic := '0';
  signal first_output_seen  : std_logic := '0';
begin
  clock_i <= not clock_i after CLK_PERIOD / 2;

  dut : entity work.ldpc_encoder_1k_23
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
    report "TB LATENCY: total_cycles=" & integer'image(frame_done_cycle - input_start_cycle) &
           ", output_start_cycles=" & integer'image(first_output_cycle - input_start_cycle) &
           ", output_stream_cycles=" & integer'image(frame_done_cycle - first_output_cycle + 1)
      severity note;
    report "TB PASS: encoded frame matches reference vector" severity note;
    finish;
  end process;

  monitor : process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        observed_index <= 0;
        frame_done <= '0';
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

        if data_en_o = '1' then
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
            frame_done_cycle <= cycle_counter;
          else
            observed_index <= observed_index + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture sim;
