library ieee;
use ieee.std_logic_1164.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity ldpc_encoder_1k_1_2 is
  port (
    clock_i         : in  std_logic;
    reset_i         : in  std_logic;
    data_i          : in  std_logic;
    data_en_i       : in  std_logic;
    data_start_i    : in  std_logic;
    data_o          : out std_logic;
    data_en_o       : out std_logic;
    data_start_o    : out std_logic;
    data_message_o  : out std_logic;
    data_parity_o   : out std_logic
  );
end entity ldpc_encoder_1k_1_2;

architecture rtl of ldpc_encoder_1k_1_2 is
  signal message_ram_wr_en   : std_logic := '0';
  signal message_ram_wr_addr : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal message_ram_wr_data : std_logic := '0';
  signal parity_message_ram_rd_addr : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal serializer_message_ram_rd_addr : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal message_ram_rd_addr : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal message_ram_rd_data : std_logic := '0';
  signal codeword_ram_wr_en   : std_logic := '0';
  signal codeword_ram_wr_addr : std_logic_vector(LDPC_CODEWORD_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal codeword_ram_wr_data : std_logic := '0';
  signal codeword_ram_rd_addr : std_logic_vector(LDPC_CODEWORD_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal codeword_ram_rd_data : std_logic := '0';
  signal message_valid        : std_logic := '0';
  signal codeword_valid       : std_logic := '0';
  signal serializer_active    : std_logic := '0';
  signal a_dep_values_rd_en   : std_logic := '0';
  signal a_dep_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal a_dep_values_rd_data_0 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal a_dep_values_rd_data_1 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal a_dep_values_rd_data_2 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal a_dep_values_rd_data_3 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal b_dep_values_rd_en   : std_logic := '0';
  signal b_dep_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal b_dep_values_rd_data_0 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal b_dep_values_rd_data_1 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal b_dep_values_rd_data_2 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal b_dep_values_rd_data_3 : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal p1_dep_values_rd_en   : std_logic := '0';
  signal p1_dep_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal p1_dep_values_rd_data_0 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal p1_dep_values_rd_data_1 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal p1_dep_values_rd_data_2 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal p1_dep_values_rd_data_3 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s2_dep_values_rd_en   : std_logic := '0';
  signal s2_dep_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal s2_dep_values_rd_data_0 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s2_dep_values_rd_data_1 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s2_dep_values_rd_data_2 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s2_dep_values_rd_data_3 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s4_dep_values_rd_en   : std_logic := '0';
  signal s4_dep_values_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal s4_dep_values_rd_data_0 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s4_dep_values_rd_data_1 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s4_dep_values_rd_data_2 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal s4_dep_values_rd_data_3 : std_logic_vector(LDPC_ROW_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal fwd_target_masks_rd_en   : std_logic := '0';
  signal fwd_target_masks_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_0 : std_logic_vector(63 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_1 : std_logic_vector(63 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_2 : std_logic_vector(63 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_3 : std_logic_vector(63 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_4 : std_logic_vector(63 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_5 : std_logic_vector(63 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_6 : std_logic_vector(63 downto 0) := (others => '0');
  signal fwd_target_masks_rd_data_7 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_en   : std_logic := '0';
  signal bwd_target_masks_rd_addr : std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_0 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_1 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_2 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_3 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_4 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_5 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_6 : std_logic_vector(63 downto 0) := (others => '0');
  signal bwd_target_masks_rd_data_7 : std_logic_vector(63 downto 0) := (others => '0');
begin
  message_ram_rd_addr <= serializer_message_ram_rd_addr when serializer_active = '1' else parity_message_ram_rd_addr;

  message_buffer_inst : entity work.ldpc_message_buffer
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      data_i          => data_i,
      data_en_i       => data_en_i,
      data_start_i    => data_start_i,
      ram_wr_en_o     => message_ram_wr_en,
      ram_wr_addr_o   => message_ram_wr_addr,
      ram_wr_data_o   => message_ram_wr_data,
      message_valid_o => message_valid
    );

  message_ram_inst : entity work.ldpc_message_ram
    port map (
      clock_i   => clock_i,
      wr_en_i   => message_ram_wr_en,
      wr_addr_i => message_ram_wr_addr,
      wr_data_i => message_ram_wr_data,
      rd_addr_i => message_ram_rd_addr,
      rd_data_o => message_ram_rd_data
    );

  codeword_ram_inst : entity work.ldpc_codeword_ram
    port map (
      clock_i   => clock_i,
      wr_en_i   => codeword_ram_wr_en,
      wr_addr_i => codeword_ram_wr_addr,
      wr_data_i => codeword_ram_wr_data,
      rd_addr_i => codeword_ram_rd_addr,
      rd_data_o => codeword_ram_rd_data
    );

  a_dep_values_rom_inst : entity work.ldpc_a_dep_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => a_dep_values_rd_en,
      rd_addr_i => a_dep_values_rd_addr,
      rd_data_0_o => a_dep_values_rd_data_0,
      rd_data_1_o => a_dep_values_rd_data_1,
      rd_data_2_o => a_dep_values_rd_data_2,
      rd_data_3_o => a_dep_values_rd_data_3
    );

  b_dep_values_rom_inst : entity work.ldpc_b_dep_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => b_dep_values_rd_en,
      rd_addr_i => b_dep_values_rd_addr,
      rd_data_0_o => b_dep_values_rd_data_0,
      rd_data_1_o => b_dep_values_rd_data_1,
      rd_data_2_o => b_dep_values_rd_data_2,
      rd_data_3_o => b_dep_values_rd_data_3
    );

  p1_dep_values_rom_inst : entity work.ldpc_p1_dep_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => p1_dep_values_rd_en,
      rd_addr_i => p1_dep_values_rd_addr,
      rd_data_0_o => p1_dep_values_rd_data_0,
      rd_data_1_o => p1_dep_values_rd_data_1,
      rd_data_2_o => p1_dep_values_rd_data_2,
      rd_data_3_o => p1_dep_values_rd_data_3
    );

  s2_dep_values_rom_inst : entity work.ldpc_s2_dep_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => s2_dep_values_rd_en,
      rd_addr_i => s2_dep_values_rd_addr,
      rd_data_0_o => s2_dep_values_rd_data_0,
      rd_data_1_o => s2_dep_values_rd_data_1,
      rd_data_2_o => s2_dep_values_rd_data_2,
      rd_data_3_o => s2_dep_values_rd_data_3
    );

  s4_dep_values_rom_inst : entity work.ldpc_s4_dep_values_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => s4_dep_values_rd_en,
      rd_addr_i => s4_dep_values_rd_addr,
      rd_data_0_o => s4_dep_values_rd_data_0,
      rd_data_1_o => s4_dep_values_rd_data_1,
      rd_data_2_o => s4_dep_values_rd_data_2,
      rd_data_3_o => s4_dep_values_rd_data_3
    );

  fwd_target_masks_rom_inst : entity work.ldpc_fwd_target_masks_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => fwd_target_masks_rd_en,
      rd_addr_i => fwd_target_masks_rd_addr,
      rd_data_0_o => fwd_target_masks_rd_data_0,
      rd_data_1_o => fwd_target_masks_rd_data_1,
      rd_data_2_o => fwd_target_masks_rd_data_2,
      rd_data_3_o => fwd_target_masks_rd_data_3,
      rd_data_4_o => fwd_target_masks_rd_data_4,
      rd_data_5_o => fwd_target_masks_rd_data_5,
      rd_data_6_o => fwd_target_masks_rd_data_6,
      rd_data_7_o => fwd_target_masks_rd_data_7
    );

  bwd_target_masks_rom_inst : entity work.ldpc_bwd_target_masks_rom
    port map (
      clock_i   => clock_i,
      rd_en_i   => bwd_target_masks_rd_en,
      rd_addr_i => bwd_target_masks_rd_addr,
      rd_data_0_o => bwd_target_masks_rd_data_0,
      rd_data_1_o => bwd_target_masks_rd_data_1,
      rd_data_2_o => bwd_target_masks_rd_data_2,
      rd_data_3_o => bwd_target_masks_rd_data_3,
      rd_data_4_o => bwd_target_masks_rd_data_4,
      rd_data_5_o => bwd_target_masks_rd_data_5,
      rd_data_6_o => bwd_target_masks_rd_data_6,
      rd_data_7_o => bwd_target_masks_rd_data_7
    );

  parity_core_inst : entity work.ldpc_parity_core
    port map (
      clock_i           => clock_i,
      reset_i           => reset_i,
      start_i           => message_valid,
      message_rd_addr_o => parity_message_ram_rd_addr,
      message_rd_data_i => message_ram_rd_data,
      a_dep_values_rd_en_o => a_dep_values_rd_en,
      a_dep_values_rd_addr_o => a_dep_values_rd_addr,
      a_dep_values_rd_data_0_i => a_dep_values_rd_data_0,
      a_dep_values_rd_data_1_i => a_dep_values_rd_data_1,
      a_dep_values_rd_data_2_i => a_dep_values_rd_data_2,
      a_dep_values_rd_data_3_i => a_dep_values_rd_data_3,
      b_dep_values_rd_en_o => b_dep_values_rd_en,
      b_dep_values_rd_addr_o => b_dep_values_rd_addr,
      b_dep_values_rd_data_0_i => b_dep_values_rd_data_0,
      b_dep_values_rd_data_1_i => b_dep_values_rd_data_1,
      b_dep_values_rd_data_2_i => b_dep_values_rd_data_2,
      b_dep_values_rd_data_3_i => b_dep_values_rd_data_3,
      p1_dep_values_rd_en_o => p1_dep_values_rd_en,
      p1_dep_values_rd_addr_o => p1_dep_values_rd_addr,
      p1_dep_values_rd_data_0_i => p1_dep_values_rd_data_0,
      p1_dep_values_rd_data_1_i => p1_dep_values_rd_data_1,
      p1_dep_values_rd_data_2_i => p1_dep_values_rd_data_2,
      p1_dep_values_rd_data_3_i => p1_dep_values_rd_data_3,
      s2_dep_values_rd_en_o => s2_dep_values_rd_en,
      s2_dep_values_rd_addr_o => s2_dep_values_rd_addr,
      s2_dep_values_rd_data_0_i => s2_dep_values_rd_data_0,
      s2_dep_values_rd_data_1_i => s2_dep_values_rd_data_1,
      s2_dep_values_rd_data_2_i => s2_dep_values_rd_data_2,
      s2_dep_values_rd_data_3_i => s2_dep_values_rd_data_3,
      s4_dep_values_rd_en_o => s4_dep_values_rd_en,
      s4_dep_values_rd_addr_o => s4_dep_values_rd_addr,
      s4_dep_values_rd_data_0_i => s4_dep_values_rd_data_0,
      s4_dep_values_rd_data_1_i => s4_dep_values_rd_data_1,
      s4_dep_values_rd_data_2_i => s4_dep_values_rd_data_2,
      s4_dep_values_rd_data_3_i => s4_dep_values_rd_data_3,
      fwd_target_masks_rd_en_o => fwd_target_masks_rd_en,
      fwd_target_masks_rd_addr_o => fwd_target_masks_rd_addr,
      fwd_target_masks_rd_data_0_i => fwd_target_masks_rd_data_0,
      fwd_target_masks_rd_data_1_i => fwd_target_masks_rd_data_1,
      fwd_target_masks_rd_data_2_i => fwd_target_masks_rd_data_2,
      fwd_target_masks_rd_data_3_i => fwd_target_masks_rd_data_3,
      fwd_target_masks_rd_data_4_i => fwd_target_masks_rd_data_4,
      fwd_target_masks_rd_data_5_i => fwd_target_masks_rd_data_5,
      fwd_target_masks_rd_data_6_i => fwd_target_masks_rd_data_6,
      fwd_target_masks_rd_data_7_i => fwd_target_masks_rd_data_7,
      bwd_target_masks_rd_en_o => bwd_target_masks_rd_en,
      bwd_target_masks_rd_addr_o => bwd_target_masks_rd_addr,
      bwd_target_masks_rd_data_0_i => bwd_target_masks_rd_data_0,
      bwd_target_masks_rd_data_1_i => bwd_target_masks_rd_data_1,
      bwd_target_masks_rd_data_2_i => bwd_target_masks_rd_data_2,
      bwd_target_masks_rd_data_3_i => bwd_target_masks_rd_data_3,
      bwd_target_masks_rd_data_4_i => bwd_target_masks_rd_data_4,
      bwd_target_masks_rd_data_5_i => bwd_target_masks_rd_data_5,
      bwd_target_masks_rd_data_6_i => bwd_target_masks_rd_data_6,
      bwd_target_masks_rd_data_7_i => bwd_target_masks_rd_data_7,
      codeword_wr_en_o  => codeword_ram_wr_en,
      codeword_wr_addr_o => codeword_ram_wr_addr,
      codeword_wr_data_o => codeword_ram_wr_data,
      codeword_valid_o  => codeword_valid
    );

  serializer_inst : entity work.ldpc_output_serializer
    port map (
      clock_i            => clock_i,
      reset_i            => reset_i,
      load_i             => codeword_valid,
      active_o           => serializer_active,
      message_rd_addr_o  => serializer_message_ram_rd_addr,
      message_rd_data_i  => message_ram_rd_data,
      codeword_rd_addr_o => codeword_ram_rd_addr,
      codeword_rd_data_i => codeword_ram_rd_data,
      data_o             => data_o,
      data_en_o          => data_en_o,
      data_start_o       => data_start_o,
      data_message_o     => data_message_o,
      data_parity_o      => data_parity_o
    );
end architecture rtl;