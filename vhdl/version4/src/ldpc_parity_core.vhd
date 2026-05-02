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
    a_dep_values_rd_en_o   : out std_logic;
    a_dep_values_rd_addr_o : out std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
    a_dep_values_rd_data_0_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    a_dep_values_rd_data_1_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    a_dep_values_rd_data_2_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    a_dep_values_rd_data_3_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    b_dep_values_rd_en_o   : out std_logic;
    b_dep_values_rd_addr_o : out std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
    b_dep_values_rd_data_0_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    b_dep_values_rd_data_1_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    b_dep_values_rd_data_2_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    b_dep_values_rd_data_3_i : in  std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);
    p1_dep_values_rd_en_o   : out std_logic;
    p1_dep_values_rd_addr_o : out std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
    p1_dep_values_rd_data_0_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    p1_dep_values_rd_data_1_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    p1_dep_values_rd_data_2_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    p1_dep_values_rd_data_3_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s2_dep_values_rd_en_o   : out std_logic;
    s2_dep_values_rd_addr_o : out std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
    s2_dep_values_rd_data_0_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s2_dep_values_rd_data_1_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s2_dep_values_rd_data_2_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s2_dep_values_rd_data_3_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s4_dep_values_rd_en_o   : out std_logic;
    s4_dep_values_rd_addr_o : out std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
    s4_dep_values_rd_data_0_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s4_dep_values_rd_data_1_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s4_dep_values_rd_data_2_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    s4_dep_values_rd_data_3_i : in  std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0);
    fwd_target_masks_rd_en_o   : out std_logic;
    fwd_target_masks_rd_addr_o : out std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
    fwd_target_masks_rd_data_0_i : in  std_logic_vector(63 downto 0);
    fwd_target_masks_rd_data_1_i : in  std_logic_vector(63 downto 0);
    fwd_target_masks_rd_data_2_i : in  std_logic_vector(63 downto 0);
    fwd_target_masks_rd_data_3_i : in  std_logic_vector(63 downto 0);
    fwd_target_masks_rd_data_4_i : in  std_logic_vector(63 downto 0);
    fwd_target_masks_rd_data_5_i : in  std_logic_vector(63 downto 0);
    fwd_target_masks_rd_data_6_i : in  std_logic_vector(63 downto 0);
    fwd_target_masks_rd_data_7_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_en_o   : out std_logic;
    bwd_target_masks_rd_addr_o : out std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
    bwd_target_masks_rd_data_0_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_data_1_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_data_2_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_data_3_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_data_4_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_data_5_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_data_6_i : in  std_logic_vector(63 downto 0);
    bwd_target_masks_rd_data_7_i : in  std_logic_vector(63 downto 0);
    codeword_wr_en_o  : out std_logic;
    codeword_wr_addr_o : out std_logic_vector(LDPC_CODEWORD_INDEX_WIDTH - 1 downto 0);
    codeword_wr_data_o : out std_logic;
    codeword_valid_o  : out std_logic
  );
end entity ldpc_parity_core;

architecture rtl of ldpc_parity_core is
  type message_bit_ram_t is array (0 to LDPC_K - 1) of std_logic;
  type bit_ram_t is array (0 to LDPC_M - 1) of std_logic;

  function offset_bits_value(bits : std_logic_vector; index : natural) return natural is
  begin
    return to_integer(unsigned(bits(index * LDPC_OFFSET_WIDTH - 1 downto (index - 1) * LDPC_OFFSET_WIDTH)));
  end function offset_bits_value;

  function row_bits_value(bits : std_logic_vector; index : natural) return natural is
  begin
    return to_integer(unsigned(bits(index * LDPC_ROW_INDEX_WIDTH - 1 downto (index - 1) * LDPC_ROW_INDEX_WIDTH)));
  end function row_bits_value;

  function forward_active_pivot(slot_index : natural) return natural is
  begin
    return row_bits_value(FWD_ACTIVE_PIVOTS_BITS, slot_index + 1);
  end function forward_active_pivot;

  function backward_pivot_has_targets(index : natural) return boolean is
  begin
    return offset_bits_value(BWD_TARGET_OFFSETS_BITS, index + 1) < offset_bits_value(BWD_TARGET_OFFSETS_BITS, index + 2);
  end function backward_pivot_has_targets;

  function next_backward_pivot_index(start_index : natural) return natural is
  begin
    if start_index < LDPC_M then
      if backward_pivot_has_targets(start_index) then
        return start_index;
      elsif start_index > 0 then
        return next_backward_pivot_index(start_index - 1);
      end if;
    end if;
    return LDPC_M;
  end function next_backward_pivot_index;

  type parity_state_t is (
    idle_s,
    load_message_wait_s,
    load_message_capture_s,
    compute_a_setup_s,
    compute_a_dep_wait_s,
    compute_a_addr_s,
    compute_a_wait_s,
    compute_a_accum_s,
    compute_b_setup_s,
    compute_b_dep_wait_s,
    compute_b_addr_s,
    compute_b_wait_s,
    compute_b_accum_s,
    rhs_setup_s,
    rhs_b_wait_s,
    rhs_s4_wait_s,
    rhs_s4_addr_s,
    rhs_a_wait_s,
    rhs_accum_s,
    rhs_finalize_s,
    load_parity_3_s,
    forward_swap_s,
    forward_apply_wait_s,
    forward_apply_load_s,
    forward_apply_bank_s,
    backward_setup_s,
    backward_apply_wait_s,
    backward_apply_load_s,
    backward_apply_bank_s,
    parity_2_setup_s,
    parity_2_wait_s,
    parity_2_accum_s,
    parity_1_setup_s,
    parity_1_wait_s,
    parity_1_accum_s
  );

  signal state             : parity_state_t := idle_s;
  signal message_bits_bank_0 : message_bit_ram_t := (others => '0');
  signal message_bits_bank_1 : message_bit_ram_t := (others => '0');
  signal message_bits_bank_2 : message_bit_ram_t := (others => '0');
  signal message_bits_bank_3 : message_bit_ram_t := (others => '0');
  signal a_times_message_ram : bit_ram_t := (others => '0');
  signal b_times_message_ram : bit_ram_t := (others => '0');
  signal rhs               : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal parity_3          : std_logic_vector(0 to LDPC_M - 1) := (others => '0');
  signal row_index         : natural range 0 to LDPC_M - 1 := 0;
  signal pivot_index       : natural range 0 to LDPC_M - 1 := 0;
  signal dependency_index  : natural := 0;
  signal dependency_limit  : natural := 0;
  signal dependency_accum  : std_logic := '0';
  signal swap_row_index    : natural range 0 to LDPC_M - 1 := 0;
  signal forward_active_pivot_slot : natural range 0 to LDPC_M - 1 := 0;
  signal apply_bank_index  : natural range 0 to 7 := 0;
  signal apply_pivot_bit   : std_logic := '0';
  signal message_load_index : natural range 0 to LDPC_K - 1 := 0;
  signal message_bits_wr_en   : std_logic := '0';
  signal message_bits_wr_addr : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal message_bits_wr_data : std_logic := '0';
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
  signal active_mask_0 : std_logic_vector(63 downto 0) := (others => '0');
  signal active_mask_1 : std_logic_vector(63 downto 0) := (others => '0');
  signal active_mask_2 : std_logic_vector(63 downto 0) := (others => '0');
  signal active_mask_3 : std_logic_vector(63 downto 0) := (others => '0');
  signal active_mask_4 : std_logic_vector(63 downto 0) := (others => '0');
  signal active_mask_5 : std_logic_vector(63 downto 0) := (others => '0');
  signal active_mask_6 : std_logic_vector(63 downto 0) := (others => '0');
  signal active_mask_7 : std_logic_vector(63 downto 0) := (others => '0');
  signal load_phase_cycles : natural := 0;
  signal compute_a_phase_cycles : natural := 0;
  signal compute_b_phase_cycles : natural := 0;
  signal rhs_phase_cycles : natural := 0;
  signal forward_phase_cycles : natural := 0;
  signal backward_phase_cycles : natural := 0;
  signal parity_2_phase_cycles : natural := 0;
  signal parity_1_phase_cycles : natural := 0;
  signal control_phase_cycles : natural := 0;

  attribute ram_style : string;
  attribute ram_style of message_bits_bank_0 : signal is "distributed";
  attribute ram_style of message_bits_bank_1 : signal is "distributed";
  attribute ram_style of message_bits_bank_2 : signal is "distributed";
  attribute ram_style of message_bits_bank_3 : signal is "distributed";
  attribute ram_style of a_times_message_ram : signal is "block";
  attribute ram_style of b_times_message_ram : signal is "block";
begin
  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if message_bits_wr_en = '1' then
        message_bits_bank_0(to_integer(unsigned(message_bits_wr_addr))) <= message_bits_wr_data;
        message_bits_bank_1(to_integer(unsigned(message_bits_wr_addr))) <= message_bits_wr_data;
        message_bits_bank_2(to_integer(unsigned(message_bits_wr_addr))) <= message_bits_wr_data;
        message_bits_bank_3(to_integer(unsigned(message_bits_wr_addr))) <= message_bits_wr_data;
      end if;

      if a_times_message_wr_en = '1' then
        a_times_message_ram(to_integer(unsigned(a_times_message_wr_addr))) <= a_times_message_wr_data;
      end if;
      a_times_message_rd_data <= a_times_message_ram(to_integer(unsigned(a_times_message_rd_addr)));

      if b_times_message_wr_en = '1' then
        b_times_message_ram(to_integer(unsigned(b_times_message_wr_addr))) <= b_times_message_wr_data;
      end if;
      b_times_message_rd_data <= b_times_message_ram(to_integer(unsigned(b_times_message_rd_addr)));
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
        forward_active_pivot_slot <= 0;
        apply_bank_index <= 0;
        apply_pivot_bit <= '0';
        message_load_index <= 0;
        message_bits_wr_en <= '0';
        message_bits_wr_addr <= (others => '0');
        message_bits_wr_data <= '0';
        a_dep_values_rd_en_o <= '0';
        a_dep_values_rd_addr_o <= (others => '0');
        b_dep_values_rd_en_o <= '0';
        b_dep_values_rd_addr_o <= (others => '0');
        p1_dep_values_rd_en_o <= '0';
        p1_dep_values_rd_addr_o <= (others => '0');
        s2_dep_values_rd_en_o <= '0';
        s2_dep_values_rd_addr_o <= (others => '0');
        s4_dep_values_rd_en_o <= '0';
        s4_dep_values_rd_addr_o <= (others => '0');
        fwd_target_masks_rd_en_o <= '0';
        fwd_target_masks_rd_addr_o <= (others => '0');
        bwd_target_masks_rd_en_o <= '0';
        bwd_target_masks_rd_addr_o <= (others => '0');
        a_times_message_wr_en   <= '0';
        a_times_message_wr_addr <= (others => '0');
        a_times_message_wr_data <= '0';
        a_times_message_rd_addr <= (others => '0');
        b_times_message_wr_en   <= '0';
        b_times_message_wr_addr <= (others => '0');
        b_times_message_wr_data <= '0';
        b_times_message_rd_addr <= (others => '0');
        active_mask_0 <= (others => '0');
        active_mask_1 <= (others => '0');
        active_mask_2 <= (others => '0');
        active_mask_3 <= (others => '0');
        active_mask_4 <= (others => '0');
        active_mask_5 <= (others => '0');
        active_mask_6 <= (others => '0');
        active_mask_7 <= (others => '0');
        load_phase_cycles <= 0;
        compute_a_phase_cycles <= 0;
        compute_b_phase_cycles <= 0;
        rhs_phase_cycles <= 0;
        forward_phase_cycles <= 0;
        backward_phase_cycles <= 0;
        parity_2_phase_cycles <= 0;
        parity_1_phase_cycles <= 0;
        control_phase_cycles <= 0;
        message_rd_addr_o <= (others => '0');
        codeword_wr_en_o <= '0';
        codeword_wr_addr_o <= (others => '0');
        codeword_wr_data_o <= '0';
        codeword_valid_o <= '0';
      else
        message_bits_wr_en <= '0';
        a_dep_values_rd_en_o <= '0';
        b_dep_values_rd_en_o <= '0';
        p1_dep_values_rd_en_o <= '0';
        s2_dep_values_rd_en_o <= '0';
        s4_dep_values_rd_en_o <= '0';
        fwd_target_masks_rd_en_o <= '0';
        bwd_target_masks_rd_en_o <= '0';
        a_times_message_wr_en <= '0';
        b_times_message_wr_en <= '0';
        codeword_wr_en_o <= '0';
        codeword_valid_o <= '0';

        if state /= idle_s then
          case state is
            when load_message_wait_s | load_message_capture_s =>
              load_phase_cycles <= load_phase_cycles + 1;
            when compute_a_setup_s | compute_a_dep_wait_s | compute_a_addr_s | compute_a_wait_s | compute_a_accum_s =>
              compute_a_phase_cycles <= compute_a_phase_cycles + 1;
            when compute_b_setup_s | compute_b_dep_wait_s | compute_b_addr_s | compute_b_wait_s | compute_b_accum_s =>
              compute_b_phase_cycles <= compute_b_phase_cycles + 1;
            when rhs_setup_s | rhs_b_wait_s | rhs_s4_wait_s | rhs_s4_addr_s | rhs_a_wait_s | rhs_accum_s | rhs_finalize_s =>
              rhs_phase_cycles <= rhs_phase_cycles + 1;
            when load_parity_3_s | forward_swap_s | forward_apply_wait_s | forward_apply_load_s | forward_apply_bank_s =>
              forward_phase_cycles <= forward_phase_cycles + 1;
            when backward_setup_s | backward_apply_wait_s | backward_apply_load_s | backward_apply_bank_s =>
              backward_phase_cycles <= backward_phase_cycles + 1;
            when parity_2_setup_s | parity_2_wait_s | parity_2_accum_s =>
              parity_2_phase_cycles <= parity_2_phase_cycles + 1;
            when parity_1_setup_s | parity_1_wait_s | parity_1_accum_s =>
              parity_1_phase_cycles <= parity_1_phase_cycles + 1;
            when others =>
              null;
          end case;

          case state is
            when load_message_wait_s | compute_a_setup_s | compute_a_dep_wait_s | compute_a_addr_s | compute_a_wait_s |
                 compute_b_setup_s | compute_b_dep_wait_s | compute_b_addr_s | compute_b_wait_s |
                 rhs_setup_s | rhs_b_wait_s | rhs_s4_wait_s | rhs_s4_addr_s | rhs_a_wait_s |
                  forward_swap_s | forward_apply_wait_s | forward_apply_load_s | backward_setup_s | backward_apply_wait_s | backward_apply_load_s |
                 parity_2_setup_s | parity_2_wait_s | parity_1_setup_s | parity_1_wait_s =>
              control_phase_cycles <= control_phase_cycles + 1;
            when others =>
              null;
          end case;
        end if;

        case state is
          when idle_s =>
            if start_i = '1' then
              message_rd_addr_o <= (others => '0');
              message_load_index <= 0;
              rhs <= (others => '0');
              parity_3 <= (others => '0');
              a_dep_values_rd_addr_o <= (others => '0');
              b_dep_values_rd_addr_o <= (others => '0');
              p1_dep_values_rd_addr_o <= (others => '0');
              s2_dep_values_rd_addr_o <= (others => '0');
              s4_dep_values_rd_addr_o <= (others => '0');
              fwd_target_masks_rd_addr_o <= (others => '0');
              bwd_target_masks_rd_addr_o <= (others => '0');
              a_times_message_rd_addr <= (others => '0');
              b_times_message_rd_addr <= (others => '0');
              load_phase_cycles <= 0;
              compute_a_phase_cycles <= 0;
              compute_b_phase_cycles <= 0;
              rhs_phase_cycles <= 0;
              forward_phase_cycles <= 0;
              backward_phase_cycles <= 0;
              parity_2_phase_cycles <= 0;
              parity_1_phase_cycles <= 0;
              control_phase_cycles <= 0;
              row_index <= 0;
              forward_active_pivot_slot <= 0;
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
              a_dep_values_rd_en_o <= '1';
              a_dep_values_rd_addr_o <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(A_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= compute_a_dep_wait_s;
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

          when compute_a_dep_wait_s =>
            state <= compute_a_accum_s;

          when compute_a_addr_s =>
            state <= compute_a_accum_s;

          when compute_a_wait_s =>
            state <= compute_a_accum_s;

          when compute_a_accum_s =>
            if dependency_index + 3 < dependency_limit then
              if dependency_index + 4 < dependency_limit then
                dependency_accum <= dependency_accum xor
                  message_bits_bank_0(to_integer(unsigned(a_dep_values_rd_data_0_i))) xor
                  message_bits_bank_1(to_integer(unsigned(a_dep_values_rd_data_1_i))) xor
                  message_bits_bank_2(to_integer(unsigned(a_dep_values_rd_data_2_i))) xor
                  message_bits_bank_3(to_integer(unsigned(a_dep_values_rd_data_3_i)));
                dependency_index <= dependency_index + 4;
                a_dep_values_rd_en_o <= '1';
                a_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(dependency_index + 4, LDPC_OFFSET_WIDTH));
                state <= compute_a_dep_wait_s;
              else
                a_times_message_wr_en <= '1';
                a_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
                a_times_message_wr_data <= dependency_accum xor
                  message_bits_bank_0(to_integer(unsigned(a_dep_values_rd_data_0_i))) xor
                  message_bits_bank_1(to_integer(unsigned(a_dep_values_rd_data_1_i))) xor
                  message_bits_bank_2(to_integer(unsigned(a_dep_values_rd_data_2_i))) xor
                  message_bits_bank_3(to_integer(unsigned(a_dep_values_rd_data_3_i)));
                if row_index = LDPC_M - 1 then
                  row_index <= 0;
                  state <= compute_b_setup_s;
                else
                  row_index <= row_index + 1;
                  state <= compute_a_setup_s;
                end if;
              end if;
            elsif dependency_index + 2 < dependency_limit then
              a_times_message_wr_en <= '1';
              a_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              a_times_message_wr_data <= dependency_accum xor
                message_bits_bank_0(to_integer(unsigned(a_dep_values_rd_data_0_i))) xor
                message_bits_bank_1(to_integer(unsigned(a_dep_values_rd_data_1_i))) xor
                message_bits_bank_2(to_integer(unsigned(a_dep_values_rd_data_2_i)));
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= compute_b_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_a_setup_s;
              end if;
            elsif dependency_index + 1 < dependency_limit then
              a_times_message_wr_en <= '1';
              a_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              a_times_message_wr_data <= dependency_accum xor
                message_bits_bank_0(to_integer(unsigned(a_dep_values_rd_data_0_i))) xor
                message_bits_bank_1(to_integer(unsigned(a_dep_values_rd_data_1_i)));
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= compute_b_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_a_setup_s;
              end if;
            else
              a_times_message_wr_en <= '1';
              a_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              a_times_message_wr_data <= dependency_accum xor message_bits_bank_0(to_integer(unsigned(a_dep_values_rd_data_0_i)));
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
              b_dep_values_rd_en_o <= '1';
              b_dep_values_rd_addr_o <= std_logic_vector(
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
            state <= compute_b_accum_s;

          when compute_b_addr_s =>
            state <= compute_b_accum_s;

          when compute_b_wait_s =>
            state <= compute_b_accum_s;

          when compute_b_accum_s =>
            if dependency_index + 3 < dependency_limit then
              if dependency_index + 4 < dependency_limit then
                dependency_accum <= dependency_accum xor
                  message_bits_bank_0(to_integer(unsigned(b_dep_values_rd_data_0_i))) xor
                  message_bits_bank_1(to_integer(unsigned(b_dep_values_rd_data_1_i))) xor
                  message_bits_bank_2(to_integer(unsigned(b_dep_values_rd_data_2_i))) xor
                  message_bits_bank_3(to_integer(unsigned(b_dep_values_rd_data_3_i)));
                dependency_index <= dependency_index + 4;
                b_dep_values_rd_en_o <= '1';
                b_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(dependency_index + 4, LDPC_OFFSET_WIDTH));
                state <= compute_b_dep_wait_s;
              else
                b_times_message_wr_en <= '1';
                b_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
                b_times_message_wr_data <= dependency_accum xor
                  message_bits_bank_0(to_integer(unsigned(b_dep_values_rd_data_0_i))) xor
                  message_bits_bank_1(to_integer(unsigned(b_dep_values_rd_data_1_i))) xor
                  message_bits_bank_2(to_integer(unsigned(b_dep_values_rd_data_2_i))) xor
                  message_bits_bank_3(to_integer(unsigned(b_dep_values_rd_data_3_i)));
                if row_index = LDPC_M - 1 then
                  row_index <= 0;
                  state <= rhs_setup_s;
                else
                  row_index <= row_index + 1;
                  state <= compute_b_setup_s;
                end if;
              end if;
            elsif dependency_index + 2 < dependency_limit then
              b_times_message_wr_en <= '1';
              b_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              b_times_message_wr_data <= dependency_accum xor
                message_bits_bank_0(to_integer(unsigned(b_dep_values_rd_data_0_i))) xor
                message_bits_bank_1(to_integer(unsigned(b_dep_values_rd_data_1_i))) xor
                message_bits_bank_2(to_integer(unsigned(b_dep_values_rd_data_2_i)));
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= rhs_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_b_setup_s;
              end if;
            elsif dependency_index + 1 < dependency_limit then
              b_times_message_wr_en <= '1';
              b_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              b_times_message_wr_data <= dependency_accum xor
                message_bits_bank_0(to_integer(unsigned(b_dep_values_rd_data_0_i))) xor
                message_bits_bank_1(to_integer(unsigned(b_dep_values_rd_data_1_i)));
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= rhs_setup_s;
              else
                row_index <= row_index + 1;
                state <= compute_b_setup_s;
              end if;
            else
              b_times_message_wr_en <= '1';
              b_times_message_wr_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
              b_times_message_wr_data <= dependency_accum xor message_bits_bank_0(to_integer(unsigned(b_dep_values_rd_data_0_i)));
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
              s4_dep_values_rd_en_o <= '1';
              s4_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(dependency_index, LDPC_OFFSET_WIDTH));
              state <= rhs_s4_wait_s;
            else
              state <= rhs_finalize_s;
            end if;

          when rhs_s4_wait_s =>
            state <= rhs_accum_s;

          when rhs_s4_addr_s =>
            state <= rhs_accum_s;

          when rhs_a_wait_s =>
            state <= rhs_accum_s;

          when rhs_accum_s =>
            if dependency_index + 3 < dependency_limit then
              if dependency_index + 4 < dependency_limit then
                dependency_accum <= dependency_accum xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_0_i))) xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_1_i))) xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_2_i))) xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_3_i)));
                dependency_index <= dependency_index + 4;
                s4_dep_values_rd_en_o <= '1';
                s4_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(dependency_index + 4, LDPC_OFFSET_WIDTH));
                state <= rhs_s4_wait_s;
              else
                dependency_accum <= dependency_accum xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_0_i))) xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_1_i))) xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_2_i))) xor
                  a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_3_i)));
                dependency_index <= dependency_index + 4;
                state <= rhs_finalize_s;
              end if;
            elsif dependency_index + 2 < dependency_limit then
              dependency_accum <= dependency_accum xor
                a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_0_i))) xor
                a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_1_i))) xor
                a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_2_i)));
              dependency_index <= dependency_index + 3;
              state <= rhs_finalize_s;
            elsif dependency_index + 1 < dependency_limit then
              dependency_accum <= dependency_accum xor
                a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_0_i))) xor
                a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_1_i)));
              dependency_index <= dependency_index + 2;
              state <= rhs_finalize_s;
            else
              dependency_accum <= dependency_accum xor a_times_message_ram(to_integer(unsigned(s4_dep_values_rd_data_0_i)));
              dependency_index <= dependency_index + 1;
              state <= rhs_finalize_s;
            end if;

          when rhs_finalize_s =>
            rhs(row_index) <= b_times_message_rd_data xor dependency_accum;
            if row_index = LDPC_M - 1 then
              state <= load_parity_3_s;
            else
              row_index <= row_index + 1;
              dependency_index <= offset_bits_value(S4_DEP_OFFSETS_BITS, row_index + 2);
              dependency_limit <= offset_bits_value(S4_DEP_OFFSETS_BITS, row_index + 3);
              dependency_accum <= '0';
              b_times_message_rd_addr <= std_logic_vector(to_unsigned(row_index + 1, LDPC_ROW_INDEX_WIDTH));
              if offset_bits_value(S4_DEP_OFFSETS_BITS, row_index + 2) < offset_bits_value(S4_DEP_OFFSETS_BITS, row_index + 3) then
                s4_dep_values_rd_en_o <= '1';
                s4_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(offset_bits_value(S4_DEP_OFFSETS_BITS, row_index + 2), LDPC_OFFSET_WIDTH));
                state <= rhs_s4_wait_s;
              else
                state <= rhs_b_wait_s;
              end if;
            end if;

          when load_parity_3_s =>
            parity_3 <= rhs;
            if FWD_ACTIVE_PIVOTS_COUNT > 0 then
              forward_active_pivot_slot <= 0;
              pivot_index <= forward_active_pivot(0);
              state <= forward_swap_s;
            elsif next_backward_pivot_index(LDPC_M - 1) < LDPC_M then
              pivot_index <= next_backward_pivot_index(LDPC_M - 1);
              dependency_index <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(LDPC_M - 1) + 1);
              dependency_limit <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(LDPC_M - 1) + 2);
              bwd_target_masks_rd_en_o <= '1';
              bwd_target_masks_rd_addr_o <= std_logic_vector(
                to_unsigned(
                  next_backward_pivot_index(LDPC_M - 1),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= backward_apply_wait_s;
            else
              row_index <= 0;
              state <= parity_2_setup_s;
            end if;

          when forward_swap_s =>
            swap_row_index <= row_bits_value(FWD_SWAP_ROWS_BITS, pivot_index + 1);
            if row_bits_value(FWD_SWAP_ROWS_BITS, pivot_index + 1) /= pivot_index then
              parity_3(pivot_index) <= parity_3(row_bits_value(FWD_SWAP_ROWS_BITS, pivot_index + 1));
              parity_3(row_bits_value(FWD_SWAP_ROWS_BITS, pivot_index + 1)) <= parity_3(pivot_index);
            end if;
            dependency_index <= offset_bits_value(FWD_TARGET_OFFSETS_BITS, pivot_index + 1);
            dependency_limit <= offset_bits_value(FWD_TARGET_OFFSETS_BITS, pivot_index + 2);
            fwd_target_masks_rd_en_o <= '1';
            fwd_target_masks_rd_addr_o <= std_logic_vector(
              to_unsigned(
                pivot_index,
                LDPC_OFFSET_WIDTH
              )
            );
            state <= forward_apply_wait_s;

          when forward_apply_wait_s =>
            state <= forward_apply_load_s;

          when forward_apply_load_s =>
            active_mask_0 <= fwd_target_masks_rd_data_0_i;
            active_mask_1 <= fwd_target_masks_rd_data_1_i;
            active_mask_2 <= fwd_target_masks_rd_data_2_i;
            active_mask_3 <= fwd_target_masks_rd_data_3_i;
            active_mask_4 <= fwd_target_masks_rd_data_4_i;
            active_mask_5 <= fwd_target_masks_rd_data_5_i;
            active_mask_6 <= fwd_target_masks_rd_data_6_i;
            active_mask_7 <= fwd_target_masks_rd_data_7_i;
            apply_pivot_bit <= parity_3(pivot_index);
            apply_bank_index <= 0;
            state <= forward_apply_bank_s;

          when forward_apply_bank_s =>
            if apply_pivot_bit = '1' then
              case apply_bank_index is
                when 0 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_0(mask_index) = '1' then
                      parity_3(mask_index) <= not parity_3(mask_index);
                    end if;
                  end loop;
                when 1 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_1(mask_index) = '1' then
                      parity_3(mask_index + 64) <= not parity_3(mask_index + 64);
                    end if;
                  end loop;
                when 2 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_2(mask_index) = '1' then
                      parity_3(mask_index + 128) <= not parity_3(mask_index + 128);
                    end if;
                  end loop;
                when 3 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_3(mask_index) = '1' then
                      parity_3(mask_index + 192) <= not parity_3(mask_index + 192);
                    end if;
                  end loop;
                when 4 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_4(mask_index) = '1' then
                      parity_3(mask_index + 256) <= not parity_3(mask_index + 256);
                    end if;
                  end loop;
                when 5 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_5(mask_index) = '1' then
                      parity_3(mask_index + 320) <= not parity_3(mask_index + 320);
                    end if;
                  end loop;
                when 6 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_6(mask_index) = '1' then
                      parity_3(mask_index + 384) <= not parity_3(mask_index + 384);
                    end if;
                  end loop;
                when others =>
                  for mask_index in 0 to 63 loop
                    if active_mask_7(mask_index) = '1' then
                      parity_3(mask_index + 448) <= not parity_3(mask_index + 448);
                    end if;
                  end loop;
              end case;
            end if;

            if apply_bank_index < 7 then
              apply_bank_index <= apply_bank_index + 1;
            elsif forward_active_pivot_slot + 1 < FWD_ACTIVE_PIVOTS_COUNT then
              forward_active_pivot_slot <= forward_active_pivot_slot + 1;
              pivot_index <= forward_active_pivot(forward_active_pivot_slot + 1);
              state <= forward_swap_s;
            elsif next_backward_pivot_index(LDPC_M - 1) < LDPC_M then
              pivot_index <= next_backward_pivot_index(LDPC_M - 1);
              dependency_index <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(LDPC_M - 1) + 1);
              dependency_limit <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(LDPC_M - 1) + 2);
              bwd_target_masks_rd_en_o <= '1';
              bwd_target_masks_rd_addr_o <= std_logic_vector(
                to_unsigned(
                  next_backward_pivot_index(LDPC_M - 1),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= backward_apply_wait_s;
            else
              row_index <= 0;
              state <= parity_2_setup_s;
            end if;

          when backward_setup_s =>
            dependency_index <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, pivot_index + 1);
            dependency_limit <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, pivot_index + 2);
            if offset_bits_value(BWD_TARGET_OFFSETS_BITS, pivot_index + 1) <
               offset_bits_value(BWD_TARGET_OFFSETS_BITS, pivot_index + 2) then
              bwd_target_masks_rd_en_o <= '1';
              bwd_target_masks_rd_addr_o <= std_logic_vector(
                to_unsigned(
                  pivot_index,
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= backward_apply_wait_s;
            elsif next_backward_pivot_index(pivot_index) < LDPC_M and next_backward_pivot_index(pivot_index) /= pivot_index then
              pivot_index <= next_backward_pivot_index(pivot_index);
              dependency_index <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(pivot_index) + 1);
              dependency_limit <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(pivot_index) + 2);
              bwd_target_masks_rd_en_o <= '1';
              bwd_target_masks_rd_addr_o <= std_logic_vector(
                to_unsigned(
                  next_backward_pivot_index(pivot_index),
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
            state <= backward_apply_load_s;

          when backward_apply_load_s =>
            active_mask_0 <= bwd_target_masks_rd_data_0_i;
            active_mask_1 <= bwd_target_masks_rd_data_1_i;
            active_mask_2 <= bwd_target_masks_rd_data_2_i;
            active_mask_3 <= bwd_target_masks_rd_data_3_i;
            active_mask_4 <= bwd_target_masks_rd_data_4_i;
            active_mask_5 <= bwd_target_masks_rd_data_5_i;
            active_mask_6 <= bwd_target_masks_rd_data_6_i;
            active_mask_7 <= bwd_target_masks_rd_data_7_i;
            apply_pivot_bit <= parity_3(pivot_index);
            apply_bank_index <= 0;
            state <= backward_apply_bank_s;

          when backward_apply_bank_s =>
            if apply_pivot_bit = '1' then
              case apply_bank_index is
                when 0 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_0(mask_index) = '1' then
                      parity_3(mask_index) <= not parity_3(mask_index);
                    end if;
                  end loop;
                when 1 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_1(mask_index) = '1' then
                      parity_3(mask_index + 64) <= not parity_3(mask_index + 64);
                    end if;
                  end loop;
                when 2 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_2(mask_index) = '1' then
                      parity_3(mask_index + 128) <= not parity_3(mask_index + 128);
                    end if;
                  end loop;
                when 3 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_3(mask_index) = '1' then
                      parity_3(mask_index + 192) <= not parity_3(mask_index + 192);
                    end if;
                  end loop;
                when 4 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_4(mask_index) = '1' then
                      parity_3(mask_index + 256) <= not parity_3(mask_index + 256);
                    end if;
                  end loop;
                when 5 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_5(mask_index) = '1' then
                      parity_3(mask_index + 320) <= not parity_3(mask_index + 320);
                    end if;
                  end loop;
                when 6 =>
                  for mask_index in 0 to 63 loop
                    if active_mask_6(mask_index) = '1' then
                      parity_3(mask_index + 384) <= not parity_3(mask_index + 384);
                    end if;
                  end loop;
                when others =>
                  for mask_index in 0 to 63 loop
                    if active_mask_7(mask_index) = '1' then
                      parity_3(mask_index + 448) <= not parity_3(mask_index + 448);
                    end if;
                  end loop;
              end case;
            end if;

            if apply_bank_index < 7 then
              apply_bank_index <= apply_bank_index + 1;
            elsif pivot_index = 0 then
              row_index <= 0;
              state <= parity_2_setup_s;
            else
              if next_backward_pivot_index(pivot_index - 1) < LDPC_M then
                pivot_index <= next_backward_pivot_index(pivot_index - 1);
                dependency_index <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(pivot_index - 1) + 1);
                dependency_limit <= offset_bits_value(BWD_TARGET_OFFSETS_BITS, next_backward_pivot_index(pivot_index - 1) + 2);
                bwd_target_masks_rd_en_o <= '1';
                bwd_target_masks_rd_addr_o <= std_logic_vector(
                  to_unsigned(
                    next_backward_pivot_index(pivot_index - 1),
                    LDPC_OFFSET_WIDTH
                  )
                );
                state <= backward_apply_wait_s;
              else
                row_index <= 0;
                state <= parity_2_setup_s;
              end if;
            end if;

          when parity_2_setup_s =>
            dependency_index <= to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            a_times_message_rd_addr <= std_logic_vector(to_unsigned(row_index, LDPC_ROW_INDEX_WIDTH));
            if to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))) <
               to_integer(unsigned(S2_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH))) then
              s2_dep_values_rd_en_o <= '1';
              s2_dep_values_rd_addr_o <= std_logic_vector(
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
              if dependency_index + 3 < dependency_limit then
                if dependency_index + 4 < dependency_limit then
                  dependency_accum <= dependency_accum xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_0_i))) xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_1_i))) xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_2_i))) xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_3_i)));
                  dependency_index <= dependency_index + 4;
                  s2_dep_values_rd_en_o <= '1';
                  s2_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(dependency_index + 4, LDPC_OFFSET_WIDTH));
                  state <= parity_2_wait_s;
                else
                  dependency_accum <= dependency_accum xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_0_i))) xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_1_i))) xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_2_i))) xor
                    parity_3(to_integer(unsigned(s2_dep_values_rd_data_3_i)));
                  dependency_index <= dependency_index + 4;
                end if;
              elsif dependency_index + 2 < dependency_limit then
                dependency_accum <= dependency_accum xor
                  parity_3(to_integer(unsigned(s2_dep_values_rd_data_0_i))) xor
                  parity_3(to_integer(unsigned(s2_dep_values_rd_data_1_i))) xor
                  parity_3(to_integer(unsigned(s2_dep_values_rd_data_2_i)));
                dependency_index <= dependency_index + 3;
              elsif dependency_index + 1 < dependency_limit then
                dependency_accum <= dependency_accum xor
                  parity_3(to_integer(unsigned(s2_dep_values_rd_data_0_i))) xor
                  parity_3(to_integer(unsigned(s2_dep_values_rd_data_1_i)));
                dependency_index <= dependency_index + 2;
              else
                dependency_accum <= dependency_accum xor parity_3(to_integer(unsigned(s2_dep_values_rd_data_0_i)));
                dependency_index <= dependency_index + 1;
              end if;
            else
              codeword_wr_en_o <= '1';
              codeword_wr_addr_o <= std_logic_vector(to_unsigned(LDPC_K + LDPC_M + row_index, LDPC_CODEWORD_INDEX_WIDTH));
              codeword_wr_data_o <= a_times_message_rd_data xor dependency_accum;
              if row_index = LDPC_M - 1 then
                row_index <= 0;
                state <= parity_1_setup_s;
              else
                row_index <= row_index + 1;
                dependency_index <= offset_bits_value(S2_DEP_OFFSETS_BITS, row_index + 2);
                dependency_limit <= offset_bits_value(S2_DEP_OFFSETS_BITS, row_index + 3);
                dependency_accum <= '0';
                a_times_message_rd_addr <= std_logic_vector(to_unsigned(row_index + 1, LDPC_ROW_INDEX_WIDTH));
                if offset_bits_value(S2_DEP_OFFSETS_BITS, row_index + 2) < offset_bits_value(S2_DEP_OFFSETS_BITS, row_index + 3) then
                  s2_dep_values_rd_en_o <= '1';
                  s2_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(offset_bits_value(S2_DEP_OFFSETS_BITS, row_index + 2), LDPC_OFFSET_WIDTH));
                end if;
                state <= parity_2_wait_s;
              end if;
            end if;

          when parity_1_setup_s =>
            dependency_index <= to_integer(unsigned(P1_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH)));
            dependency_limit <= to_integer(unsigned(P1_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH)));
            dependency_accum <= '0';
            if to_integer(unsigned(P1_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))) <
               to_integer(unsigned(P1_DEP_OFFSETS_BITS((row_index + 2) * LDPC_OFFSET_WIDTH - 1 downto (row_index + 1) * LDPC_OFFSET_WIDTH))) then
              p1_dep_values_rd_en_o <= '1';
              p1_dep_values_rd_addr_o <= std_logic_vector(
                to_unsigned(
                  to_integer(unsigned(P1_DEP_OFFSETS_BITS((row_index + 1) * LDPC_OFFSET_WIDTH - 1 downto row_index * LDPC_OFFSET_WIDTH))),
                  LDPC_OFFSET_WIDTH
                )
              );
              state <= parity_1_wait_s;
            else
              state <= parity_1_accum_s;
            end if;

          when parity_1_wait_s =>
            state <= parity_1_accum_s;

          when parity_1_accum_s =>
            if dependency_index < dependency_limit then
              if dependency_index + 3 < dependency_limit then
                if dependency_index + 4 < dependency_limit then
                  dependency_accum <= dependency_accum xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_0_i))) xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_1_i))) xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_2_i))) xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_3_i)));
                  dependency_index <= dependency_index + 4;
                  p1_dep_values_rd_en_o <= '1';
                  p1_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(dependency_index + 4, LDPC_OFFSET_WIDTH));
                  state <= parity_1_wait_s;
                else
                  dependency_accum <= dependency_accum xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_0_i))) xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_1_i))) xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_2_i))) xor
                    parity_3(to_integer(unsigned(p1_dep_values_rd_data_3_i)));
                  dependency_index <= dependency_index + 4;
                end if;
              elsif dependency_index + 2 < dependency_limit then
                dependency_accum <= dependency_accum xor
                  parity_3(to_integer(unsigned(p1_dep_values_rd_data_0_i))) xor
                  parity_3(to_integer(unsigned(p1_dep_values_rd_data_1_i))) xor
                  parity_3(to_integer(unsigned(p1_dep_values_rd_data_2_i)));
                dependency_index <= dependency_index + 3;
              elsif dependency_index + 1 < dependency_limit then
                dependency_accum <= dependency_accum xor
                  parity_3(to_integer(unsigned(p1_dep_values_rd_data_0_i))) xor
                  parity_3(to_integer(unsigned(p1_dep_values_rd_data_1_i)));
                dependency_index <= dependency_index + 2;
              else
                dependency_accum <= dependency_accum xor parity_3(to_integer(unsigned(p1_dep_values_rd_data_0_i)));
                dependency_index <= dependency_index + 1;
              end if;
            else
              codeword_wr_en_o <= '1';
              codeword_wr_addr_o <= std_logic_vector(to_unsigned(LDPC_K + row_index, LDPC_CODEWORD_INDEX_WIDTH));
              codeword_wr_data_o <= dependency_accum;
              if row_index = LDPC_M - 1 then
                report "PARITY CORE PHASES: load=" & integer'image(load_phase_cycles) &
                       ", a=" & integer'image(compute_a_phase_cycles) &
                       ", b=" & integer'image(compute_b_phase_cycles) &
                       ", rhs=" & integer'image(rhs_phase_cycles) &
                       ", forward=" & integer'image(forward_phase_cycles) &
                       ", backward=" & integer'image(backward_phase_cycles) &
                       ", parity2=" & integer'image(parity_2_phase_cycles) &
                       ", parity1=" & integer'image(parity_1_phase_cycles + 1) &
                       ", control=" & integer'image(control_phase_cycles)
                  severity note;
                codeword_valid_o <= '1';
                state <= idle_s;
              else
                row_index <= row_index + 1;
                dependency_index <= offset_bits_value(P1_DEP_OFFSETS_BITS, row_index + 2);
                dependency_limit <= offset_bits_value(P1_DEP_OFFSETS_BITS, row_index + 3);
                dependency_accum <= '0';
                if offset_bits_value(P1_DEP_OFFSETS_BITS, row_index + 2) < offset_bits_value(P1_DEP_OFFSETS_BITS, row_index + 3) then
                  p1_dep_values_rd_en_o <= '1';
                  p1_dep_values_rd_addr_o <= std_logic_vector(to_unsigned(offset_bits_value(P1_DEP_OFFSETS_BITS, row_index + 2), LDPC_OFFSET_WIDTH));
                  state <= parity_1_wait_s;
                else
                  state <= parity_1_accum_s;
                end if;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;