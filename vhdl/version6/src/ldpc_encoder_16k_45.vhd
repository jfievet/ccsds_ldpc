library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ldpc_encoder_common_pkg.all;
use work.ldpc_encoder_16k_45_config_pkg.all;
use work.ldpc_encoder_16k_45_qc_rom_pkg.all;

entity ldpc_encoder_16k_45 is
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
end entity ldpc_encoder_16k_45;

architecture rtl of ldpc_encoder_16k_45 is
  subtype t_qc_row_data is std_logic_vector((LDPC_QC_COL_BLOCKS * LDPC_QC_BLOCK_SIZE) - 1 downto 0);
  type t_qc_rom_image is array (0 to LDPC_QC_ROW_BLOCKS - 1) of t_qc_row_data;

  function build_qc_rom return t_qc_rom_image is
    variable rom_v : t_qc_rom_image := (others => (others => '0'));
  begin
    for row_index in 0 to LDPC_QC_ROW_BLOCKS - 1 loop
      for col_index in 0 to LDPC_QC_COL_BLOCKS - 1 loop
        rom_v(row_index)((col_index + 1) * LDPC_QC_BLOCK_SIZE - 1 downto col_index * LDPC_QC_BLOCK_SIZE) :=
          C_LDPC_QC_ROM_BANK_16K_45(col_index)(row_index);
      end loop;
    end loop;

    return rom_v;
  end function build_qc_rom;

  signal rom_row_block_s : natural range 0 to LDPC_QC_ROW_BLOCKS - 1 := 0;
  signal rom_storage_s : t_qc_rom_image := build_qc_rom;
  signal rom_data_s : t_qc_row_data := (others => '0');

  attribute rom_style : string;
  attribute rom_style of rom_storage_s : signal is C_LDPC_QC_ROM_STYLE;
begin
  rom_read_process : process (clock_i)
  begin
    if rising_edge(clock_i) then
      rom_data_s <= rom_storage_s(rom_row_block_s);
    end if;
  end process rom_read_process;

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
