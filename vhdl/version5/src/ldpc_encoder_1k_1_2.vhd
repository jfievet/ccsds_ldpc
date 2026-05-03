library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity ldpc_encoder_1k_1_2 is
  port (
    clock_i        : in std_logic;
    reset_i        : in std_logic;
    data_i         : in std_logic;
    data_en_i      : in std_logic;
    data_start_i   : in std_logic;
    data_o         : out std_logic;
    data_en_o      : out std_logic;
    data_start_o   : out std_logic;
    data_message_o : out std_logic;
    data_parity_o  : out std_logic
  );
end entity ldpc_encoder_1k_1_2;

architecture rtl of ldpc_encoder_1k_1_2 is
  function rotate_block_left(block_i : t_ldpc_block) return t_ldpc_block is
  begin
    return block_i(LDPC_QC_BLOCK_SIZE - 2 downto 0) & block_i(LDPC_QC_BLOCK_SIZE - 1);
  end function rotate_block_left;

  signal rom_data_s : t_ldpc_block_array := (others => (others => '0'));
  signal shift_registers_s : t_ldpc_block_array := (others => (others => '0'));
  signal parity_blocks_s : t_ldpc_block_array := (others => (others => '0'));

  signal input_row_block_s : natural range 0 to LDPC_QC_ROW_BLOCKS - 1 := 0;
  signal input_local_index_s : natural range 0 to LDPC_QC_BLOCK_SIZE - 1 := 0;
  signal input_bit_count_s : natural range 0 to LDPC_K := 0;

  signal message_pipe_bit_s : std_logic := '0';
  signal message_pipe_valid_s : std_logic := '0';
  signal message_pipe_start_s : std_logic := '0';

  signal parity_pending_s : std_logic := '0';
  signal parity_active_s : std_logic := '0';
  signal parity_block_index_s : natural range 0 to LDPC_QC_COL_BLOCKS - 1 := 0;
  signal parity_local_index_s : natural range 0 to LDPC_QC_BLOCK_SIZE - 1 := 0;

  signal data_o_s : std_logic := '0';
  signal data_en_o_s : std_logic := '0';
  signal data_start_o_s : std_logic := '0';
  signal data_message_o_s : std_logic := '0';
  signal data_parity_o_s : std_logic := '0';
begin
  data_o <= data_o_s;
  data_en_o <= data_en_o_s;
  data_start_o <= data_start_o_s;
  data_message_o <= data_message_o_s;
  data_parity_o <= data_parity_o_s;

  rom_generate : for rom_index in 0 to LDPC_QC_COL_BLOCKS - 1 generate
    rom_inst : entity work.ldpc_circulant_row_rom
      generic map (
        G_ROM_INDEX => rom_index
      )
      port map (
        row_block_i => input_row_block_s,
        data_o      => rom_data_s(rom_index)
      );
  end generate rom_generate;

  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        shift_registers_s <= (others => (others => '0'));
        parity_blocks_s <= (others => (others => '0'));
        input_row_block_s <= 0;
        input_local_index_s <= 0;
        input_bit_count_s <= 0;
        message_pipe_bit_s <= '0';
        message_pipe_valid_s <= '0';
        message_pipe_start_s <= '0';
        parity_pending_s <= '0';
        parity_active_s <= '0';
        parity_block_index_s <= 0;
        parity_local_index_s <= 0;
        data_o_s <= '0';
        data_en_o_s <= '0';
        data_start_o_s <= '0';
        data_message_o_s <= '0';
        data_parity_o_s <= '0';
      else
        data_en_o_s <= '0';
        data_start_o_s <= '0';
        data_message_o_s <= '0';
        data_parity_o_s <= '0';

        if message_pipe_valid_s = '1' then
          data_o_s <= message_pipe_bit_s;
          data_en_o_s <= '1';
          data_start_o_s <= message_pipe_start_s;
          data_message_o_s <= '1';
          data_parity_o_s <= '0';
          message_pipe_valid_s <= '0';
          message_pipe_start_s <= '0';
        elsif parity_pending_s = '1' or parity_active_s = '1' then
          data_o_s <= parity_blocks_s(parity_block_index_s)(parity_local_index_s);
          data_en_o_s <= '1';
          data_start_o_s <= '0';
          data_message_o_s <= '0';
          data_parity_o_s <= '1';

          if parity_block_index_s = LDPC_QC_COL_BLOCKS - 1 and parity_local_index_s = LDPC_QC_BLOCK_SIZE - 1 then
            parity_pending_s <= '0';
            parity_active_s <= '0';
            parity_block_index_s <= 0;
            parity_local_index_s <= 0;
          else
            parity_pending_s <= '0';
            parity_active_s <= '1';
            if parity_local_index_s = LDPC_QC_BLOCK_SIZE - 1 then
              parity_local_index_s <= 0;
              parity_block_index_s <= parity_block_index_s + 1;
            else
              parity_local_index_s <= parity_local_index_s + 1;
            end if;
          end if;
        end if;

        if data_en_i = '1' then
          message_pipe_bit_s <= data_i;
          message_pipe_valid_s <= '1';
          message_pipe_start_s <= data_start_i;

          if data_start_i = '1' then
            parity_pending_s <= '0';
            parity_active_s <= '0';
            parity_block_index_s <= 0;
            parity_local_index_s <= 0;
            input_row_block_s <= 0;
            input_bit_count_s <= 1;

            if data_i = '1' then
              for col_index in 0 to LDPC_QC_COL_BLOCKS - 1 loop
                parity_blocks_s(col_index) <= rom_data_s(col_index);
                shift_registers_s(col_index) <= rotate_block_left(rom_data_s(col_index));
              end loop;
            else
              parity_blocks_s <= (others => (others => '0'));
              for col_index in 0 to LDPC_QC_COL_BLOCKS - 1 loop
                shift_registers_s(col_index) <= rotate_block_left(rom_data_s(col_index));
              end loop;
            end if;

            if LDPC_K = 1 then
              input_local_index_s <= 0;
              input_bit_count_s <= 0;
              parity_pending_s <= '1';
            else
              input_local_index_s <= 1;
            end if;
          else
            if data_i = '1' then
              if input_local_index_s = 0 then
                for col_index in 0 to LDPC_QC_COL_BLOCKS - 1 loop
                  parity_blocks_s(col_index) <= parity_blocks_s(col_index) xor rom_data_s(col_index);
                  shift_registers_s(col_index) <= rotate_block_left(rom_data_s(col_index));
                end loop;
              else
                for col_index in 0 to LDPC_QC_COL_BLOCKS - 1 loop
                  parity_blocks_s(col_index) <= parity_blocks_s(col_index) xor shift_registers_s(col_index);
                  shift_registers_s(col_index) <= rotate_block_left(shift_registers_s(col_index));
                end loop;
              end if;
            else
              if input_local_index_s = 0 then
                for col_index in 0 to LDPC_QC_COL_BLOCKS - 1 loop
                  shift_registers_s(col_index) <= rotate_block_left(rom_data_s(col_index));
                end loop;
              else
                for col_index in 0 to LDPC_QC_COL_BLOCKS - 1 loop
                  shift_registers_s(col_index) <= rotate_block_left(shift_registers_s(col_index));
                end loop;
              end if;
            end if;

            if input_bit_count_s = LDPC_K - 1 then
              input_bit_count_s <= 0;
              input_row_block_s <= 0;
              input_local_index_s <= 0;
              parity_pending_s <= '1';
              parity_block_index_s <= 0;
              parity_local_index_s <= 0;
            else
              input_bit_count_s <= input_bit_count_s + 1;
              if input_local_index_s = LDPC_QC_BLOCK_SIZE - 1 then
                input_local_index_s <= 0;
                if input_row_block_s = LDPC_QC_ROW_BLOCKS - 1 then
                  input_row_block_s <= 0;
                else
                  input_row_block_s <= input_row_block_s + 1;
                end if;
              else
                input_local_index_s <= input_local_index_s + 1;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;