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
    clock_i           : in  std_logic;
    reset_i           : in  std_logic;
    start_i           : in  std_logic;
    message_rd_addr_o : out std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    message_rd_data_i : in  std_logic;
    codeword_wr_en_o  : out std_logic;
    codeword_wr_addr_o : out std_logic_vector(LDPC_CODEWORD_INDEX_WIDTH - 1 downto 0);
    codeword_wr_data_o : out std_logic;
    codeword_valid_o  : out std_logic
  );
end entity ldpc_parity_core;

architecture rtl of ldpc_parity_core is
  type message_bit_ram_t is array (0 to LDPC_K - 1) of std_logic;
  type bit_ram_t is array (0 to LDPC_M - 1) of std_logic;

  type parity_state_t is (
    idle_s,
    load_message_wait_s,
    load_message_capture_s,
    compute_a_setup_s,
    compute_a_wait_s,
    compute_a_accum_s,
    compute_b_setup_s,
    compute_b_dep_wait_s,
    compute_b_addr_s,
    compute_b_wait_s,
    compute_b_accum_s,
    rhs_setup_s,
    rhs_b_wait_s,
    rhs_a_wait_s,
    rhs_accum_s,
    rhs_finalize_s,
    load_parity_3_s,
    forward_swap_s,
    forward_apply_wait_s,
    forward_apply_s,
    backward_setup_s,
    backward_apply_wait_s,
    backward_apply_s,
    parity_2_setup_s,
    parity_2_wait_s,
    parity_2_accum_s,
    parity_1_setup_s,
    parity_1_accum_s,
    assemble_message_request_s,
    assemble_message_wait_s,
    assemble_message_write_s,
    assemble_parity_1_request_s,
    assemble_parity_1_wait_s,
    assemble_parity_1_write_s,
    assemble_parity_2_request_s,
    assemble_parity_2_wait_s,
    assemble_parity_2_write_s
  );

  signal state             : parity_state_t := idle_s;
  signal message_bits_ram  : message_bit_ram_t := (others => '0');
  signal a_times_message_ram : bit_ram_t := (others => '0');
  signal b_times_message_ram : bit_ram_t := (others => '0');
  signal rhs               : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal parity_1_ram      : bit_ram_t := (others => '0');
  signal parity_2_ram      : bit_ram_t := (others => '0');
  signal parity_3          : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal row_index         : natural range 0 to LDPC_M - 1 := 0;
  signal pivot_index       : natural range 0 to LDPC_M - 1 := 0;
  signal dependency_index  : natural := 0;
  signal dependency_limit  : natural := 0;
  signal dependency_accum  : std_logic := '0';
  signal swap_row_index    : natural range 0 to LDPC_M - 1 := 0;
  signal message_load_index : natural range 0 to LDPC_K - 1 := 0;
  signal codeword_write_index : natural range 0 to LDPC_N - 1 := 0;
  signal message_bits_wr_en   : std_logic := '0';
  signal message_bits_wr_addr : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal message_bits_wr_data : std_logic := '0';
  signal message_bits_rd_addr : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal message_bits_rd_data : std_logic := '0';
  signal fwd_target_values_rd_en   : std_logic := '0';
  signal fwd_target_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal fwd_target_values_rd_data : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal bwd_target_values_rd_en   : std_logic := '0';
  signal bwd_target_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal bwd_target_values_rd_data : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal b_dep_values_rd_en   : std_logic := '0';
  signal b_dep_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal b_dep_values_rd_data : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s2_dep_values_rd_en   : std_logic := '0';
  signal s2_dep_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal s2_dep_values_rd_data : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal a_times_message_wr_en   : std_logic := '0';
  signal a_times_message_wr_addr : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal a_times_message_wr_data : std_logic := '0';
  signal a_times_message_rd_addr : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal a_times_message_rd_data : std_logic := '0';
  signal b_times_message_wr_en   : std_logic := '0';
  signal b_times_message_wr_addr : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal b_times_message_wr_data : std_logic := '0';
  signal b_times_message_rd_addr : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal b_times_message_rd_data : std_logic := '0';
  signal parity_1_wr_en    : std_logic := '0';
  signal parity_1_wr_addr  : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal parity_1_wr_data  : std_logic := '0';
  signal parity_1_rd_addr  : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal parity_1_rd_data  : std_logic := '0';
  signal parity_2_wr_en    : std_logic := '0';
  signal parity_2_wr_addr  : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal parity_2_wr_data  : std_logic := '0';
  signal parity_2_rd_addr  : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal parity_2_rd_data  : std_logic := '0';

  attribute ram_style : string;
  attribute ram_style of message_bits_ram : signal is "block";
  attribute ram_style of a_times_message_ram : signal is "block";
  attribute ram_style of b_times_message_ram : signal is "block";
  attribute ram_style of parity_1_ram : signal is "block";
  attribute ram_style of parity_2_ram : signal is "block";
begin
  b_dep_values_rom_inst : entity work.ldpc_b_dep_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => b_dep_values_rd_en,
      rd_addr_i => b_dep_values_rd_addr,
      rd_data_o => b_dep_values_rd_data
    );

  s2_dep_values_rom_inst : entity work.ldpc_s2_dep_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => s2_dep_values_rd_en,
      rd_addr_i => s2_dep_values_rd_addr,
      rd_data_o => s2_dep_values_rd_data
    );

  fwd_target_values_rom_inst : entity work.ldpc_fwd_target_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => fwd_target_values_rd_en,
      rd_addr_i => fwd_target_values_rd_addr,
      rd_data_o => fwd_target_values_rd_data
    );

  bwd_target_values_rom_inst : entity work.ldpc_bwd_target_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => bwd_target_values_rd_en,
      rd_addr_i => bwd_target_values_rd_addr,
      rd_data_o => bwd_target_values_rd_data
    );

  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if message_bits_wr_en = '1' then
        message_bits_ram(to_integer(unsigned(message_bits_wr_addr))) <= message_bits_wr_data;
      end if;
      message_bits_rd_data <= message_bits_ram(to_integer(unsigned(message_bits_rd_addr)));

      if a_times_message_wr_en = '1' then
        a_times_message_ram(to_integer(unsigned(a_times_message_wr_addr))) <= a_times_message_wr_data;
      end if;
      a_times_message_rd_data <= a_times_message_ram(to_integer(unsigned(a_times_message_rd_addr)));

      if b_times_message_wr_en = '1' then
        b_times_message_ram(to_integer(unsigned(b_times_message_wr_addr))) <= b_times_message_wr_data;
      end if;
      b_times_message_rd_data <= b_times_message_ram(to_integer(unsigned(b_times_message_rd_addr)));

      if parity_1_wr_en = '1' then
        parity_1_ram(to_integer(unsigned(parity_1_wr_addr))) <= parity_1_wr_data;
      end if;
      parity_1_rd_data <= parity_1_ram(to_integer(unsigned(parity_1_rd_addr)));

      if parity_2_wr_en = '1' then
        parity_2_ram(to_integer(unsigned(parity_2_wr_addr))) <= parity_2_wr_data;
      end if;
      parity_2_rd_data <= parity_2_ram(to_integer(unsigned(parity_2_rd_addr)));
    end if;
  end process;

  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        state            <= idle_s;
        rhs              <= (others => '0');
        parity_3         <= (others => '0');
        row_index        <= 0;
        pivot_index      <= 0;
        dependency_index <= 0;
        dependency_limit <= 0;
        dependency_accum <= '0';
        swap_row_index   <= 0;
        message_load_index <= 0;
        codeword_write_index <= 0;
        message_bits_wr_en   <= '0';
        message_bits_wr_addr <= (others => '0');
        message_bits_wr_data <= '0';
        message_bits_rd_addr <= (others => '0');
        b_dep_values_rd_en <= '0';
        b_dep_values_rd_addr <= (others => '0');
        fwd_target_values_rd_en <= '0';
        fwd_target_values_rd_addr <= (others => '0');
        bwd_target_values_rd_en <= '0';
        bwd_target_values_rd_addr <= (others => '0');
        s2_dep_values_rd_en <= '0';
        s2_dep_values_rd_addr <= (others => '0');
        a_times_message_wr_en   <= '0';
        a_times_message_wr_addr <= (others => '0');
        a_times_message_wr_data <= '0';
        a_times_message_rd_addr <= (others => '0');
        b_times_message_wr_en   <= '0';
        b_times_message_wr_addr <= (others => '0');
        b_times_message_wr_data <= '0';
        b_times_message_rd_addr <= (others => '0');
        parity_1_wr_en   <= '0';
        parity_1_wr_addr <= (others => '0');
        parity_1_wr_data <= '0';
        parity_1_rd_addr <= (others => '0');
        parity_2_wr_en   <= '0';
        parity_2_wr_addr <= (others => '0');
        parity_2_wr_data <= '0';
        parity_2_rd_addr <= (others => '0');
        message_rd_addr_o <= (others => '0');
        codeword_wr_en_o <= '0';
        codeword_wr_addr_o <= (others => '0');
        codeword_wr_data_o <= '0';
        codeword_valid_o <= '0';
      else
        message_bits_wr_en <= '0';
        b_dep_values_rd_en <= '0';
        fwd_target_values_rd_en <= '0';
        bwd_target_values_rd_en <= '0';
        s2_dep_values_rd_en <= '0';
        a_times_message_wr_en <= '0';
        b_times_message_wr_en <= '0';
        parity_1_wr_en <= '0';
        parity_2_wr_en <= '0';
        codeword_wr_en_o <= '0';
        codeword_valid_o <= '0';

        case state is
          when idle_s =>
            if start_i = '1' then
              message_rd_addr_o <= (others => '0');
              message_load_index <= 0;
              rhs <= (others => '0');
              parity_3 <= (others => '0');
              codeword_write_index <= 0;
              message_bits_rd_addr <= (others => '0');
              fwd_target_values_rd_addr <= (others => '0');
              bwd_target_values_rd_addr <= (others => '0');
              a_times_message_rd_addr <= (others => '0');
              b_times_message_rd_addr <= (others => '0');
              parity_1_rd_addr <= (others => '0');
              parity_2_rd_addr <= (others => '0');
              row_index <= 0;
              state <= load_message_wait_s;
            end if;

          when load_message_wait_s =>
            state <= load_message_capture_s;

          when load_message_capture_s =>
            message_bits_wr_en <= '1';
            message_bits_wr_addr <= std_logic_vector(to_unsigned(message_load_index, LDPC_MESSAGE_INDEX_WIDTH));
            message_bits_wr_data <= message_rd_data_i;
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
            if to_integer(unsigned(A_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))) <
               to_integer(unsigned(A_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH))) then
              message_bits_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(A_DEP_VALUES_BITS(
                    (to_integer(unsigned(A_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))) + 1) * LDPC_MESSAGE_INDEX_WIDTH - 1 downto
                    to_integer(unsigned(A_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))) * LDPC_MESSAGE_INDEX_WIDTH
                  ))),
                  LDPC_MESSAGE_INDEX_WIDTH
                )
              );
              state <= compute_a_wait_s;
            else
              a_times_message_wr_en <= '1';
              a_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              a_times_message_wr_data <= '0';
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= compute_b_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_a_setup_s;
              end if;
            end if;

          when compute_a_wait_s =>
            state <= compute_a_accum_s;

          when compute_a_accum_s =>
            if dependency_index + 1 < dependency_limit then
              dependency_accum <= dependency_accum xor message_bits_rd_data;
              dependency_index <= dependency_index + 1;
              message_bits_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(A_DEP_VALUES_BITS((dependency_index + 2) * LDPC_MESSAGE_INDEX_WIDTH - 1 downto (dependency_index + 1) * LDPC_MESSAGE_INDEX_WIDTH))),
                  LDPC_MESSAGE_INDEX_WIDTH
                )
              );
              state <= compute_a_wait_s;
            else
              a_times_message_wr_en <= '1';
              a_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              a_times_message_wr_data <= dependency_accum xor message_bits_rd_data;
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
            if to_integer(unsigned(B_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))) <
               to_integer(unsigned(B_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH))) then
              b_dep_values_rd_en <= '1';
              b_dep_values_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(B_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= compute_b_dep_wait_s;
            else
              b_times_message_wr_en <= '1';
              b_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              b_times_message_wr_data <= '0';
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= rhs_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_b_setup_s;
              end if;
            end if;

          when compute_b_dep_wait_s =>
            state <= compute_b_addr_s;

          when compute_b_addr_s =>
            message_bits_rd_addr <= b_dep_values_rd_data;
            state <= compute_b_wait_s;

          when compute_b_wait_s =>
            state <= compute_b_accum_s;

          when compute_b_accum_s =>
            if dependency_index + 1 < dependency_limit then
              dependency_accum <= dependency_accum xor message_bits_rd_data;
              dependency_index <= dependency_index + 1;
              b_dep_values_rd_en <= '1';
              b_dep_values_rd_addr <= std_logic_vector(to_unsigned(dependency_index + 1, LDPC_OFFSET_WIDTH));
              state <= compute_b_dep_wait_s;
            else
              b_times_message_wr_en <= '1';
              b_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              b_times_message_wr_data <= dependency_accum xor message_bits_rd_data;
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
            b_times_message_rd_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
            state <= rhs_b_wait_s;

          when rhs_b_wait_s =>
            if dependency_index < dependency_limit then
              a_times_message_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(S4_DEP_VALUES_BITS((dependency_index + 1) * LDPC_ROW_INDEX_WIDTH - 1 downto dependency_index * LDPC_ROW_INDEX_WIDTH))),
                  LDPC_ROW_INDEX_WIDTH
                )
              );
              state <= rhs_a_wait_s;
            else
              state <= rhs_finalize_s;
            end if;

          when rhs_a_wait_s =>
            state <= rhs_accum_s;

          when rhs_accum_s =>
            dependency_accum <= dependency_accum xor a_times_message_rd_data;

            if dependency_index + 1 < dependency_limit then
              dependency_index <= dependency_index + 1;
              a_times_message_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(S4_DEP_VALUES_BITS((dependency_index + 2) * LDPC_ROW_INDEX_WIDTH - 1 downto (dependency_index + 1) * LDPC_ROW_INDEX_WIDTH))),
                  LDPC_ROW_INDEX_WIDTH
                )
              );
              state <= rhs_a_wait_s;
            else
              dependency_index <= dependency_index + 1;
              state <= rhs_finalize_s;
            end if;

          when rhs_finalize_s =>
            rhs(row_index) <= b_times_message_rd_data xor dependency_accum;
            if row_index = LDPC_M - 1 then
              state <= load_parity_3_s;
            else
              row_index <= row_index + 1;
              state <= rhs_setup_s;
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
            if to_integer(unsigned(FWD_TARGET_OFFSETS_BITS((pivot_index + 1) * LDPC_OFFSET_WIDTH - 1 downto pivot_index * LDPC_OFFSET_WIDTH))) <
               to_integer(unsigned(FWD_TARGET_OFFSETS_BITS((pivot_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (pivot_index + 1) * LDPC_OFFSET_WIDTH))) then
              fwd_target_values_rd_en <= '1';
              fwd_target_values_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(FWD_TARGET_OFFSETS_BITS((pivot_index + 1) * LDPC_OFFSET_WIDTH - 1 downto pivot_index * LDPC_OFFSET_WIDTH))),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= forward_apply_wait_s;
            elsif pivot_index = LDPC_M - 1 then
              pivot_index <= LDPC_M - 1;
              state <= backward_setup_s;
            else
              pivot_index <= pivot_index + 1;
              state <= forward_swap_s;
            end if;

          when forward_apply_wait_s =>
            state <= forward_apply_s;

          when forward_apply_s =>
            if parity_3(pivot_index) = '1' then
              parity_3(to_integer(unsigned(fwd_target_values_rd_data))) <= not parity_3(to_integer(unsigned(fwd_target_values_rd_data)));
            end if;

            if dependency_index + 1 < dependency_limit then
              dependency_index <= dependency_index + 1;
              fwd_target_values_rd_en <= '1';
              fwd_target_values_rd_addr <= std_logic_vector(to_unsigned(dependency_index + 1, LDPC_OFFSET_WIDTH));
              state <= forward_apply_wait_s;
            elsif pivot_index = LDPC_M - 1 then
              pivot_index <= LDPC_M - 1;
              state <= backward_setup_s;
            else
              pivot_index <= pivot_index + 1;
              state <= forward_swap_s;
            end if;

          when backward_setup_s =>
            dependency_index <= to_integer(unsigned(BWD_TARGET_OFFSETS_BITS((pivot_index + 1) * LDPC_OFFSET_WIDTH - 1 downto pivot_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(BWD_TARGET_OFFSETS_BITS((pivot_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (pivot_index + 1) * LDPC_OFFSET_WIDTH)));
            if to_integer(unsigned(BWD_TARGET_OFFSETS_BITS((pivot_index + 1) * LDPC_OFFSET_WIDTH - 1 downto pivot_index * LDPC_OFFSET_WIDTH))) <
               to_integer(unsigned(BWD_TARGET_OFFSETS_BITS((pivot_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (pivot_index + 1) * LDPC_OFFSET_WIDTH))) then
              bwd_target_values_rd_en <= '1';
              bwd_target_values_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(BWD_TARGET_OFFSETS_BITS((pivot_index + 1) * LDPC_OFFSET_WIDTH - 1 downto pivot_index * LDPC_OFFSET_WIDTH))),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= backward_apply_wait_s;
            elsif pivot_index = 0 then
              row_index <= 0;
              state <= parity_2_setup_s;
            else
              pivot_index <= pivot_index - 1;
              state <= backward_setup_s;
            end if;

          when backward_apply_wait_s =>
            state <= backward_apply_s;

          when backward_apply_s =>
            if parity_3(pivot_index) = '1' then
              parity_3(to_integer(unsigned(bwd_target_values_rd_data))) <= not parity_3(to_integer(unsigned(bwd_target_values_rd_data)));
            end if;

            if dependency_index + 1 < dependency_limit then
              dependency_index <= dependency_index + 1;
              bwd_target_values_rd_en <= '1';
              bwd_target_values_rd_addr <= std_logic_vector(to_unsigned(dependency_index + 1, LDPC_OFFSET_WIDTH));
              state <= backward_apply_wait_s;
            elsif pivot_index = 0 then
              row_index <= 0;
              state <= parity_2_setup_s;
            else
              pivot_index <= pivot_index - 1;
              state <= backward_setup_s;
            end if;

          when parity_2_setup_s =>
            dependency_index <= to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            a_times_message_rd_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
            if to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))) <
               to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH))) then
              s2_dep_values_rd_en <= '1';
              s2_dep_values_rd_addr <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= parity_2_wait_s;
            else
              state <= parity_2_accum_s;
            end if;

          when parity_2_wait_s =>
            state <= parity_2_accum_s;

          when parity_2_accum_s =>
            if dependency_index < dependency_limit then
              dependency_accum <= dependency_accum xor parity_3(to_integer(unsigned(s2_dep_values_rd_data)));
              if dependency_index + 1 < dependency_limit then
                dependency_index <= dependency_index + 1;
                s2_dep_values_rd_en <= '1';
                s2_dep_values_rd_addr <= std_logic_vector(to_unsigned(dependency_index + 1, LDPC_OFFSET_WIDTH));
                state <= parity_2_wait_s;
              else
                dependency_index <= dependency_index + 1;
              end if;
            else
              parity_2_wr_en <= '1';
              parity_2_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              parity_2_wr_data <= a_times_message_rd_data xor dependency_accum;
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
              parity_1_wr_en <= '1';
              parity_1_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              parity_1_wr_data <= dependency_accum;
              if row_index = LDPC_M - 1 then
                codeword_write_index <= 0;
                state <= assemble_message_request_s;
              else
                row_index <= row_index + 1;
                state <= parity_1_setup_s;
              end if;
            end if;

          when assemble_message_request_s =>
            message_bits_rd_addr <= std_logic_vector(to_unsigned(codeword_write_index, LDPC_MESSAGE_INDEX_WIDTH));
            state <= assemble_message_wait_s;

          when assemble_message_wait_s =>
            state <= assemble_message_write_s;

          when assemble_message_write_s =>
            codeword_wr_en_o <= '1';
            codeword_wr_addr_o <= std_logic_vector(to_unsigned(codeword_write_index, LDPC_CODEWORD_INDEX_WIDTH));
            codeword_wr_data_o <= message_bits_rd_data;

            if codeword_write_index = LDPC_K - 1 then
              codeword_write_index <= LDPC_K;
              row_index <= 0;
              state <= assemble_parity_1_request_s;
            else
              codeword_write_index <= codeword_write_index + 1;
              state <= assemble_message_request_s;
            end if;

          when assemble_parity_1_request_s =>
            parity_1_rd_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
            state <= assemble_parity_1_wait_s;

          when assemble_parity_1_wait_s =>
            state <= assemble_parity_1_write_s;

          when assemble_parity_1_write_s =>
            codeword_wr_en_o <= '1';
            codeword_wr_addr_o <= std_logic_vector(to_unsigned(codeword_write_index, LDPC_CODEWORD_INDEX_WIDTH));
            codeword_wr_data_o <= parity_1_rd_data;

            if row_index = LDPC_M - 1 then
              codeword_write_index <= LDPC_K + LDPC_M;
              row_index <= 0;
              state <= assemble_parity_2_request_s;
            else
              codeword_write_index <= codeword_write_index + 1;
              row_index <= row_index + 1;
              state <= assemble_parity_1_request_s;
            end if;

          when assemble_parity_2_request_s =>
            parity_2_rd_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
            state <= assemble_parity_2_wait_s;

          when assemble_parity_2_wait_s =>
            state <= assemble_parity_2_write_s;

          when assemble_parity_2_write_s =>
            codeword_wr_en_o <= '1';
            codeword_wr_addr_o <= std_logic_vector(to_unsigned(codeword_write_index, LDPC_CODEWORD_INDEX_WIDTH));
            codeword_wr_data_o <= parity_2_rd_data;

            if row_index = LDPC_M - 1 then
              codeword_valid_o <= '1';
              state <= idle_s;
            else
              codeword_write_index <= codeword_write_index + 1;
              row_index <= row_index + 1;
              state <= assemble_parity_2_request_s;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;