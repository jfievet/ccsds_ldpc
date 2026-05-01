library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;
use work.ldpc_encoder_1k_1_2_a_tables_pkg.all;
use work.ldpc_encoder_1k_1_2_b_tables_pkg.all;
use work.ldpc_encoder_1k_1_2_parity_tables_pkg.all;
use work.ldpc_encoder_1k_1_2_solver_tables_pkg.all;

entity ldpc_parity_core is
  port (
    clock_i          : in  std_logic;
    reset_i          : in  std_logic;
    start_i          : in  std_logic;
    message_rd_addr_o : out std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    message_rd_data_i : in  std_logic;
    codeword_bits_o  : out std_logic_vector(0 to LDPC_N - 1);
    codeword_valid_o : out std_logic
  );
end entity ldpc_parity_core;

architecture rtl of ldpc_parity_core is
  type parity_state_t is (
    idle_s,
    load_message_wait_s,
    load_message_capture_s,
    compute_a_setup_s,
    compute_a_accum_s,
    compute_b_setup_s,
    compute_b_accum_s,
    rhs_setup_s,
    rhs_accum_s,
    load_parity_3_s,
    forward_swap_s,
    forward_apply_s,
    backward_setup_s,
    backward_apply_s,
    parity_2_setup_s,
    parity_2_accum_s,
    parity_1_setup_s,
    parity_1_accum_s,
    assemble_codeword_s
  );

  signal state             : parity_state_t := idle_s;
  signal message_bits_reg  : std_logic_vector(0 to LDPC_K - 1) := (others => '0');
  signal a_times_message   : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal b_times_message   : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal rhs               : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal parity_1          : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal parity_2          : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal parity_3          : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal codeword_bits     : std_logic_vector(0 to LDPC_N - 1) := (others => '0');
  signal row_index         : natural range 0 to LDPC_M - 1 := 0;
  signal pivot_index       : natural range 0 to LDPC_M - 1 := 0;
  signal dependency_index  : natural := 0;
  signal dependency_limit  : natural := 0;
  signal dependency_accum  : std_logic := '0';
  signal swap_row_index    : natural range 0 to LDPC_M - 1 := 0;
  signal message_load_index : natural range 0 to LDPC_K - 1 := 0;
begin
  codeword_bits_o <= codeword_bits;

  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        state            <= idle_s;
        message_bits_reg <= (others => '0');
        a_times_message  <= (others => '0');
        b_times_message  <= (others => '0');
        rhs              <= (others => '0');
        parity_1         <= (others => '0');
        parity_2         <= (others => '0');
        parity_3         <= (others => '0');
        codeword_bits    <= (others => '0');
        row_index        <= 0;
        pivot_index      <= 0;
        dependency_index <= 0;
        dependency_limit <= 0;
        dependency_accum <= '0';
        swap_row_index   <= 0;
        message_load_index <= 0;
        message_rd_addr_o <= (others => '0');
        codeword_valid_o <= '0';
      else
        codeword_valid_o <= '0';

        case state is
          when idle_s =>
            if start_i = '1' then
              message_rd_addr_o <= (others => '0');
              message_load_index <= 0;
              message_bits_reg <= (others => '0');
              a_times_message <= (others => '0');
              b_times_message <= (others => '0');
              rhs <= (others => '0');
              parity_1 <= (others => '0');
              parity_2 <= (others => '0');
              parity_3 <= (others => '0');
              row_index <= 0;
              state <= load_message_wait_s;
            end if;

          when load_message_wait_s =>
            state <= load_message_capture_s;

          when load_message_capture_s =>
            message_bits_reg(message_load_index) <= message_rd_data_i;
            if message_load_index = LDPC_K - 1 then
              row_index <= 0;
              state <= compute_a_setup_s;
            else
              message_load_index <= message_load_index + 1;
              message_rd_addr_o <= std_logic_vector(to_unsigned(message_load_index + 1, LDPC_MESSAGE_INDEX_WIDTH));
              state <= load_message_wait_s;
            end if;

          when compute_a_setup_s =>
            dependency_index <= to_integer(unsigned(A_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(A_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            state <= compute_a_accum_s;

          when compute_a_accum_s =>
            if dependency_index < dependency_limit then
              dependency_accum <= dependency_accum xor message_bits_reg(
                to_integer(unsigned(A_DEP_VALUES_BITS((dependency_index + 1) * LDPC_MESSAGE_INDEX_WIDTH - 1 downto dependency_index * LDPC_MESSAGE_INDEX_WIDTH)))
              );
              dependency_index <= dependency_index + 1;
            else
              a_times_message(row_index) <= dependency_accum;
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= compute_b_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_a_setup_s;
              end if;
            end if;

          when compute_b_setup_s =>
            dependency_index <= to_integer(unsigned(B_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(B_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            state <= compute_b_accum_s;

          when compute_b_accum_s =>
            if dependency_index < dependency_limit then
              dependency_accum <= dependency_accum xor message_bits_reg(
                to_integer(unsigned(B_DEP_VALUES_BITS((dependency_index + 1) * LDPC_MESSAGE_INDEX_WIDTH - 1 downto dependency_index * LDPC_MESSAGE_INDEX_WIDTH)))
              );
              dependency_index <= dependency_index + 1;
            else
              b_times_message(row_index) <= dependency_accum;
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= rhs_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_b_setup_s;
              end if;
            end if;

          when rhs_setup_s =>
            dependency_index <= to_integer(unsigned(S4_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(S4_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            state <= rhs_accum_s;

          when rhs_accum_s =>
            if dependency_index < dependency_limit then
              dependency_accum <= dependency_accum xor a_times_message(
                to_integer(unsigned(S4_DEP_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH)))
              );
              dependency_index <= dependency_index + 1;
            else
              rhs(row_index) <= b_times_message(row_index) xor dependency_accum;
              if row_index = LDPC_M - 1 then
                state <= load_parity_3_s;
              else
                row_index <= row_index + 1;
                state <= rhs_setup_s;
              end if;
            end if;

          when load_parity_3_s =>
            parity_3 <= rhs;
            pivot_index <= 0;
            state <= forward_swap_s;

          when forward_swap_s =>
            swap_row_index <= to_integer(unsigned(FWD_SWAP_ROWS_BITS((pivot_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto pivot_index * LDPC_ROW_INDEX_WIDTH)));
            if to_integer(unsigned(FWD_SWAP_ROWS_BITS((pivot_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto pivot_index * LDPC_ROW_INDEX_WIDTH))) /= pivot_index then
              parity_3(pivot_index) <= parity_3(to_integer(unsigned(FWD_SWAP_ROWS_BITS((pivot_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto pivot_index * LDPC_ROW_INDEX_WIDTH))));
              parity_3(to_integer(unsigned(FWD_SWAP_ROWS_BITS((pivot_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto pivot_index * LDPC_ROW_INDEX_WIDTH)))) <= parity_3(pivot_index);
            end if;
            dependency_index <= to_integer(unsigned(FWD_TARGET_OFFSETS_BITS((pivot_index + 1) * LDPC_OFFSET_WIDTH - 1 downto pivot_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(FWD_TARGET_OFFSETS_BITS((pivot_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (pivot_index + 1) * LDPC_OFFSET_WIDTH)));
            state <= forward_apply_s;

          when forward_apply_s =>
            if dependency_index < dependency_limit then
              if parity_3(pivot_index) = '1' then
                parity_3(
                  to_integer(unsigned(FWD_TARGET_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH)))
                ) <= not parity_3(
                  to_integer(unsigned(FWD_TARGET_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH)))
                );
              end if;
              dependency_index <= dependency_index + 1;
            else
              if pivot_index = LDPC_M - 1 then
                pivot_index <= LDPC_M - 1;
                state <= backward_setup_s;
              else
                pivot_index <= pivot_index + 1;
                state <= forward_swap_s;
              end if;
            end if;

          when backward_setup_s =>
            dependency_index <= to_integer(unsigned(BWD_TARGET_OFFSETS_BITS((pivot_index + 1) * LDPC_OFFSET_WIDTH - 1 downto pivot_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(BWD_TARGET_OFFSETS_BITS((pivot_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (pivot_index + 1) * LDPC_OFFSET_WIDTH)));
            state <= backward_apply_s;

          when backward_apply_s =>
            if dependency_index < dependency_limit then
              if parity_3(pivot_index) = '1' then
                parity_3(
                  to_integer(unsigned(BWD_TARGET_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH)))
                ) <= not parity_3(
                  to_integer(unsigned(BWD_TARGET_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH)))
                );
              end if;
              dependency_index <= dependency_index + 1;
            else
              if pivot_index = 0 then
                row_index <= 0;
                state <= parity_2_setup_s;
              else
                pivot_index <= pivot_index - 1;
                state <= backward_setup_s;
              end if;
            end if;

          when parity_2_setup_s =>
            dependency_index <= to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            state <= parity_2_accum_s;

          when parity_2_accum_s =>
            if dependency_index < dependency_limit then
              dependency_accum <= dependency_accum xor parity_3(
                to_integer(unsigned(S2_DEP_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH)))
              );
              dependency_index <= dependency_index + 1;
            else
              parity_2(row_index) <= a_times_message(row_index) xor dependency_accum;
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= parity_1_setup_s;
              else
                row_index <= row_index + 1;
                state <= parity_2_setup_s;
              end if;
            end if;

          when parity_1_setup_s =>
            dependency_index <= to_integer(unsigned(P1_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(P1_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            state <= parity_1_accum_s;

          when parity_1_accum_s =>
            if dependency_index < dependency_limit then
              dependency_accum <= dependency_accum xor parity_3(
                to_integer(unsigned(P1_DEP_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH)))
              );
              dependency_index <= dependency_index + 1;
            else
              parity_1(row_index) <= dependency_accum;
              if row_index = LDPC_M - 1 then
                state <= assemble_codeword_s;
              else
                row_index <= row_index + 1;
                state <= parity_1_setup_s;
              end if;
            end if;

          when assemble_codeword_s =>
            codeword_bits(0 to LDPC_K - 1) <= message_bits_reg;
            codeword_bits(LDPC_K to LDPC_K + LDPC_M - 1) <= parity_1;
            codeword_bits(LDPC_K + LDPC_M to LDPC_N - 1) <= parity_2;
            codeword_valid_o <= '1';
            state <= idle_s;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;