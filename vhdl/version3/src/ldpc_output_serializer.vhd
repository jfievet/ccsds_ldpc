library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ldpc_encoder_1k_1_2_config_pkg.all;

entity ldpc_output_serializer is
  port (
    clock_i            : in  std_logic;
    reset_i            : in  std_logic;
    load_i             : in  std_logic;
    codeword_rd_addr_o : out std_logic_vector(LDPC_CODEWORD_INDEX_WIDTH - 1 downto 0);
    codeword_rd_data_i : in  std_logic;
    data_o             : out std_logic;
    data_en_o          : out std_logic;
    data_start_o       : out std_logic;
    data_message_o     : out std_logic;
    data_parity_o      : out std_logic
  );
end entity ldpc_output_serializer;

architecture rtl of ldpc_output_serializer is
  type serializer_state_t is (idle_s, prefetch_s, stream_s);

  signal state        : serializer_state_t := idle_s;
  signal request_index : natural range 0 to LDPC_N - 1 := 0;
  signal output_index  : natural range 0 to LDPC_N - 1 := 0;
begin
  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        state              <= idle_s;
        request_index      <= 0;
        output_index       <= 0;
        codeword_rd_addr_o <= (others => '0');
        data_o             <= '0';
        data_en_o          <= '0';
        data_start_o       <= '0';
        data_message_o     <= '0';
        data_parity_o      <= '0';
      else
        data_en_o      <= '0';
        data_start_o   <= '0';
        data_message_o <= '0';
        data_parity_o  <= '0';

        if load_i = '1' then
          request_index <= 0;
          output_index <= 0;
          codeword_rd_addr_o <= (others => '0');
          state <= prefetch_s;
        else
          case state is
            when idle_s =>
              null;

            when prefetch_s =>
              if LDPC_N > 1 then
                request_index <= 1;
                codeword_rd_addr_o <= std_logic_vector(to_unsigned(1, LDPC_CODEWORD_INDEX_WIDTH));
              end if;
              state <= stream_s;

            when stream_s =>
              data_o <= codeword_rd_data_i;
              data_en_o <= '1';

              if output_index = 0 then
                data_start_o <= '1';
              end if;

              if output_index < LDPC_K then
                data_message_o <= '1';
              else
                data_parity_o <= '1';
              end if;

              if output_index = LDPC_N - 1 then
                request_index <= 0;
                output_index <= 0;
                state <= idle_s;
              else
                output_index <= output_index + 1;

                if request_index < LDPC_N - 1 then
                  request_index <= request_index + 1;
                  codeword_rd_addr_o <= std_logic_vector(to_unsigned(request_index + 1, LDPC_CODEWORD_INDEX_WIDTH));
                end if;
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;