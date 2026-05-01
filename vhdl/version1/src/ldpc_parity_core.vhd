library ieee;
use ieee.std_logic_1164.all;

use work.ldpc_encoder_1k_1_2_constants_pkg.all;

entity ldpc_parity_core is
  port (
    clock_i          : in  std_logic;
    reset_i          : in  std_logic;
    start_i          : in  std_logic;
    message_bits_i   : in  std_logic_vector(0 to LDPC_K - 1);
    codeword_bits_o  : out std_logic_vector(0 to LDPC_N - 1);
    codeword_valid_o : out std_logic
  );
end entity ldpc_parity_core;

architecture rtl of ldpc_parity_core is
  function xor_dependencies(
    data_bits : std_logic_vector;
    offsets   : natural_vector_t;
    values    : natural_vector_t;
    row_index : natural
  ) return std_logic is
    variable accum      : std_logic := '0';
    variable start_idx  : natural;
    variable finish_idx : natural;
  begin
    start_idx := offsets(row_index);
    finish_idx := offsets(row_index + 1);

    if start_idx < finish_idx then
      for dep_index in start_idx to finish_idx - 1 loop
        accum := accum xor data_bits(values(dep_index));
      end loop;
    end if;

    return accum;
  end function xor_dependencies;

  signal codeword_bits : std_logic_vector(0 to LDPC_N - 1) := (others => '0');
begin
  codeword_bits_o <= codeword_bits;

  process (clock_i)
    variable a_times_message : std_logic_vector(0 to LDPC_M - 1);
    variable b_times_message : std_logic_vector(0 to LDPC_M - 1);
    variable rhs             : std_logic_vector(0 to LDPC_M - 1);
    variable parity_1        : std_logic_vector(0 to LDPC_M - 1);
    variable parity_2        : std_logic_vector(0 to LDPC_M - 1);
    variable parity_3        : std_logic_vector(0 to LDPC_M - 1);
    variable next_codeword   : std_logic_vector(0 to LDPC_N - 1);
    variable pivot_row       : natural;
    variable saved_bit       : std_logic;
    variable start_idx       : natural;
    variable finish_idx      : natural;
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        codeword_bits    <= (others => '0');
        codeword_valid_o <= '0';
      else
        codeword_valid_o <= '0';

        if start_i = '1' then
          for row_index in 0 to LDPC_M - 1 loop
            a_times_message(row_index) := xor_dependencies(message_bits_i, A_DEP_OFFSETS, A_DEP_VALUES, row_index);
            b_times_message(row_index) := xor_dependencies(message_bits_i, B_DEP_OFFSETS, B_DEP_VALUES, row_index);
          end loop;

          for row_index in 0 to LDPC_M - 1 loop
            rhs(row_index) := b_times_message(row_index) xor
                              xor_dependencies(a_times_message, S4_DEP_OFFSETS, S4_DEP_VALUES, row_index);
          end loop;

          parity_3 := rhs;
          for pivot in 0 to LDPC_M - 1 loop
            pivot_row := FWD_SWAP_ROWS(pivot);
            if pivot_row /= pivot then
              saved_bit := parity_3(pivot);
              parity_3(pivot) := parity_3(pivot_row);
              parity_3(pivot_row) := saved_bit;
            end if;

            if parity_3(pivot) = '1' then
              start_idx := FWD_TARGET_OFFSETS(pivot);
              finish_idx := FWD_TARGET_OFFSETS(pivot + 1);
              if start_idx < finish_idx then
                for target_index in start_idx to finish_idx - 1 loop
                  parity_3(FWD_TARGET_VALUES(target_index)) := not parity_3(FWD_TARGET_VALUES(target_index));
                end loop;
              end if;
            end if;
          end loop;

          for pivot in LDPC_M - 1 downto 0 loop
            if parity_3(pivot) = '1' then
              start_idx := BWD_TARGET_OFFSETS(pivot);
              finish_idx := BWD_TARGET_OFFSETS(pivot + 1);
              if start_idx < finish_idx then
                for target_index in start_idx to finish_idx - 1 loop
                  parity_3(BWD_TARGET_VALUES(target_index)) := not parity_3(BWD_TARGET_VALUES(target_index));
                end loop;
              end if;
            end if;
          end loop;

          for row_index in 0 to LDPC_M - 1 loop
            parity_2(row_index) := a_times_message(row_index) xor
                                   xor_dependencies(parity_3, S2_DEP_OFFSETS, S2_DEP_VALUES, row_index);
            parity_1(row_index) := xor_dependencies(parity_3, P1_DEP_OFFSETS, P1_DEP_VALUES, row_index);
          end loop;

          next_codeword(0 to LDPC_K - 1) := message_bits_i;
          next_codeword(LDPC_K to LDPC_K + LDPC_M - 1) := parity_1;
          next_codeword(LDPC_K + LDPC_M to LDPC_N - 1) := parity_2;

          codeword_bits <= next_codeword;
          codeword_valid_o <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture rtl;