library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;
use work.ldpc_encoder_1k_1_2_b_tables_pkg.all;

entity ldpc_b_dep_values_rom is
    port (
        clock_i   : in  std_logic;
        rd_en_i   : in  std_logic;
        rd_addr_i : in  std_logic_vector(LDPC_OFFSET_WIDTH - 1 downto 0);
        rd_data_o : out std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0)
    );
end entity ldpc_b_dep_values_rom;

architecture rtl of ldpc_b_dep_values_rom is
    type rom_t is array (0 to B_DEP_VALUES_COUNT - 1) of std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0);

    function unpack_values return rom_t is
        variable data : rom_t;
    begin
        for index in 0 to B_DEP_VALUES_COUNT - 1 loop
            data(index) := B_DEP_VALUES_BITS((index + 1) * LDPC_MESSAGE_INDEX_WIDTH - 1 downto index * LDPC_MESSAGE_INDEX_WIDTH);
        end loop;
        return data;
    end function unpack_values;

    signal rom     : rom_t := unpack_values;
    signal rd_data : std_logic_vector(LDPC_MESSAGE_INDEX_WIDTH - 1 downto 0) := (others => '0');

    attribute rom_style : string;
    attribute rom_style of rom : signal is "distributed";
begin
    rd_data_o <= rd_data;

    process (clock_i)
        variable address_index : natural;
    begin
        if rising_edge(clock_i) then
            if rd_en_i = '1' then
                address_index := to_integer(unsigned(rd_addr_i));
                if address_index < B_DEP_VALUES_COUNT then
                    rd_data <= rom(address_index);
                else
                    rd_data <= (others => '0');
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
