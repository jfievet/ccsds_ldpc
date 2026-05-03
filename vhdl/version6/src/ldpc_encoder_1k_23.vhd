library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ldpc_encoder_common_pkg.all;
use work.ldpc_encoder_1k_23_config_pkg.all;
use work.ldpc_encoder_1k_23_qc_rom_pkg.all;

entity ldpc_encoder_1k_23 is
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
end entity ldpc_encoder_1k_23;

architecture rtl of ldpc_encoder_1k_23 is
  signal rom_row_block_s : natural range 0 to LDPC_QC_ROW_BLOCKS - 1 := 0;
  signal rom_data_s : t_std_logic_vector_array(0 to LDPC_QC_COL_BLOCKS - 1)(LDPC_QC_BLOCK_SIZE - 1 downto 0) := (others => (others => '0'));
begin
  rom_generate : for rom_index in 0 to LDPC_QC_COL_BLOCKS - 1 generate
  begin
    rom_data_s(rom_index) <= C_LDPC_QC_ROM_BANK_1K_23(rom_index)(rom_row_block_s);
  end generate rom_generate;

  core_inst : entity work.ldpc_qc_encoder_core
    generic map (
      G_LDPC_K             => LDPC_K,
      G_LDPC_N             => LDPC_N,
      G_LDPC_QC_ROW_BLOCKS => LDPC_QC_ROW_BLOCKS,
      G_LDPC_QC_COL_BLOCKS => LDPC_QC_COL_BLOCKS,
      G_LDPC_QC_BLOCK_SIZE => LDPC_QC_BLOCK_SIZE
    )
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      data_i          => data_i,
      data_en_i       => data_en_i,
      data_start_i    => data_start_i,
      rom_row_block_o => rom_row_block_s,
      rom_data_i      => rom_data_s,
      data_o          => data_o,
      data_en_o       => data_en_o,
      data_start_o    => data_start_o,
      data_message_o  => data_message_o,
      data_parity_o   => data_parity_o
    );
end architecture rtl;
