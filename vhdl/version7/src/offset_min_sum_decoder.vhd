library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity offset_min_sum_decoder is
  generic (
    G_FULL_N  : positive := 2560;
    G_IN_N    : positive := 2048;
    G_OUT_N   : positive := 1024;
    G_M       : positive := 1536;
    G_IDX_W   : positive := 12;
    G_LLR_W   : positive := 6;
    G_OFFSET_Q: natural  := 1
  );
  port (
    clk_i : in  std_logic;
    rst_i : in  std_logic;

    data_i        : in  std_logic_vector(G_LLR_W-1 downto 0);
    data_valid_i  : in  std_logic;
    data_start_i  : in  std_logic;
    iter_cfg_i    : in  std_logic_vector(7 downto 0);

    data_o        : out std_logic;
    data_valid_o  : out std_logic;
    data_start_o  : out std_logic
  );
end entity;

architecture rtl of offset_min_sum_decoder is
  constant C_ADDR_W_VN : integer := 12; -- 0..2559
  constant C_ADDR_W_M  : integer := 11; -- 0..1535
  constant C_CN_W      : integer := 6*G_LLR_W;

  subtype llr_s is signed(G_LLR_W-1 downto 0);
  subtype llr_wide_s is signed(8 downto 0);
  subtype abs_s is unsigned(8 downto 0); -- 0..511

  type llr6_arr is array (0 to 5) of llr_s;
  type abs6_arr is array (0 to 5) of abs_s;
  type bit6_arr is array (0 to 5) of std_logic;
  type slv6_arr is array (0 to 5) of std_logic_vector(G_IDX_W-1 downto 0);
  type idx6_arr is array (0 to 5) of unsigned(G_IDX_W-1 downto 0);
  type wide6_arr is array (0 to 5) of llr_wide_s;

  type state_t is (
    ST_IDLE,
    ST_LOAD,
    ST_PAD0,
    ST_OPERATING,
    ST_OUT
    --ST_ROW_ROM,
    --ST_ROW_ADDR,
    --ST_ROW_RD,
    --ST_VN_RD,
    --ST_COMP,
    --ST_W0,
    --ST_W1,
    --ST_W2,
    --ST_NEXT_ROW,
    --ST_NEXT_ITER,
    --ST_OUT_ADDR,
    --ST_OUT
  );

  signal st : state_t := ST_IDLE;

  signal in_cnt  : unsigned(C_ADDR_W_VN-1 downto 0) := (others => '0');
  signal pad_cnt : unsigned(C_ADDR_W_VN-1 downto 0) := (others => '0');

  signal iter_cnt     : unsigned(7 downto 0) := (others => '0');
  signal iter_target  : unsigned(7 downto 0) := (others => '0');
  signal row_cnt      : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');

  -- ROM outputs (1-based indices; 0 means unused)
  signal idx_raw_slv : slv6_arr := (others => (others => '0'));
  signal idx_raw_u   : idx6_arr := (others => (others => '0'));
  signal idx_vn  : idx6_arr := (others => (others => '0')); -- 0-based VN index when valid
  signal edge_v  : bit6_arr := (others => '0');

  -- VN RAM port signals (three replicated memories)
  signal ram0_addra, ram0_addrb : std_logic_vector(C_ADDR_W_VN-1 downto 0) := (others => '0');
  signal ram1_addra, ram1_addrb : std_logic_vector(C_ADDR_W_VN-1 downto 0) := (others => '0');
  signal ram2_addra, ram2_addrb : std_logic_vector(C_ADDR_W_VN-1 downto 0) := (others => '0');
  signal ram0_dia, ram0_dib : std_logic_vector(G_LLR_W-1 downto 0) := (others => '0');
  signal ram1_dia, ram1_dib : std_logic_vector(G_LLR_W-1 downto 0) := (others => '0');
  signal ram2_dia, ram2_dib : std_logic_vector(G_LLR_W-1 downto 0) := (others => '0');
  signal ram0_wea, ram0_web : std_logic := '0';
  signal ram1_wea, ram1_web : std_logic := '0';
  signal ram2_wea, ram2_web : std_logic := '0';
  signal ram0_ena, ram0_enb : std_logic := '1';
  signal ram1_ena, ram1_enb : std_logic := '1';
  signal ram2_ena, ram2_enb : std_logic := '1';

  signal ram0_doa, ram0_dob : std_logic_vector(G_LLR_W-1 downto 0);
  signal ram1_doa, ram1_dob : std_logic_vector(G_LLR_W-1 downto 0);
  signal ram2_doa, ram2_dob : std_logic_vector(G_LLR_W-1 downto 0);

  -- VN writeback pair (2 edges at a time, replicated to all 3 RAMs)
  signal wr_addr0, wr_addr1 : unsigned(C_ADDR_W_VN-1 downto 0) := (others => '0');
  signal wr_data0, wr_data1 : std_logic_vector(G_LLR_W-1 downto 0) := (others => '0');
  signal wr_en0, wr_en1     : std_logic := '0';

  -- CN message RAM (packed 6x6-bit)

  signal cn_do   : std_logic_vector(C_CN_W-1 downto 0);
  signal cn_old  : llr6_arr := (others => (others => '0'));
  signal cn_new  : llr6_arr := (others => (others => '0'));

  -- Compute stage signals


  -- Output
  signal out_cnt : unsigned(13 downto 0) := (others => '0'); -- Taken large for future 0 to 16384-1

  component tdp_ram_rf_rf is
    generic (G_ADDR_W : positive; G_DATA_W : positive);
    port (
      clk_i : in  std_logic;
      ena_i   : in  std_logic;
      wea_i   : in  std_logic;
      addra_i : in  std_logic_vector(G_ADDR_W-1 downto 0);
      dia_i   : in  std_logic_vector(G_DATA_W-1 downto 0);
      doa_o   : out std_logic_vector(G_DATA_W-1 downto 0);
      enb_i   : in  std_logic;
      web_i   : in  std_logic;
      addrb_i : in  std_logic_vector(G_ADDR_W-1 downto 0);
      dib_i   : in  std_logic_vector(G_DATA_W-1 downto 0);
      dob_o   : out std_logic_vector(G_DATA_W-1 downto 0)
    );
  end component;

  component sp_ram_rf is
    generic (G_ADDR_W : positive; G_DATA_W : positive);
    port (
      clk_i  : in  std_logic;
      en_i   : in  std_logic;
      we_i   : in  std_logic;
      addr_i : in  std_logic_vector(G_ADDR_W-1 downto 0);
      di_i   : in  std_logic_vector(G_DATA_W-1 downto 0);
      do_o   : out std_logic_vector(G_DATA_W-1 downto 0)
    );
  end component;

  component h_row_rom is
    generic (G_M : positive; G_IDX_W : positive);
    port (
      clk_i : in  std_logic;
      en_i  : in  std_logic;
      row_i : in  std_logic_vector(10 downto 0);
      idx0_o : out std_logic_vector(G_IDX_W-1 downto 0);
      idx1_o : out std_logic_vector(G_IDX_W-1 downto 0);
      idx2_o : out std_logic_vector(G_IDX_W-1 downto 0);
      idx3_o : out std_logic_vector(G_IDX_W-1 downto 0);
      idx4_o : out std_logic_vector(G_IDX_W-1 downto 0);
      idx5_o : out std_logic_vector(G_IDX_W-1 downto 0)
    );
  end component;

  -- Compare blocks for tournament min1/min2 (values only; index tracked separately)
  signal w01_v, l01_v, w23_v, l23_v, w45_v, l45_v : abs_s := (others => '0');
  signal w01_i, w23_i, w45_i : unsigned(2 downto 0) := (others => '0');
  signal w0123_v, l0123_v : abs_s := (others => '0');
  signal w0123_i, l0123_i : unsigned(2 downto 0) := (others => '0');
  signal wfinal_v, lfinal_v : abs_s := (others => '0');
  signal wfinal_i, lfinal_i : unsigned(2 downto 0) := (others => '0');
  signal cand_a, cand_b, cand_c : abs_s := (others => '0');
  signal min2_tmp : abs_s := (others => '0');

  -- New added signals
  signal idx_vn_d1  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d2  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d3  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d4  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d5  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d6  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d7  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d8  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d9  : idx6_arr := (others => (others => '0'));
  signal idx_vn_d10 : idx6_arr := (others => (others => '0'));
  signal idx_vn_d11 : idx6_arr := (others => (others => '0'));
signal idx_vn_d12 : idx6_arr := (others => (others => '0'));
  signal row_cnt_d2  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d3  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d4  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d5  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d6  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d7  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d8  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d9  : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d10 : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal row_cnt_d11 : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal edge_v_d1 : bit6_arr := (others => '0');
  signal edge_v_d2 : bit6_arr := (others => '0');
  signal edge_v_d3 : bit6_arr := (others => '0');
  signal edge_v_d4 : bit6_arr := (others => '0');
  signal edge_v_d5 : bit6_arr := (others => '0');
  signal edge_v_d6 : bit6_arr := (others => '0');
  signal edge_v_d7 : bit6_arr := (others => '0');
  signal edge_v_d8 : bit6_arr := (others => '0');
  signal edge_v_d9 : bit6_arr := (others => '0');
  signal edge_v_d10  : bit6_arr := (others => '0');
  signal edge_v_d11 : bit6_arr := (others => '0');
  signal edge_v_d12 : bit6_arr := (others => '0');
  signal sign_product_d1 : std_logic := '0';
  signal sign_product_d2 : std_logic := '0';
  signal sign_product_d3 : std_logic := '0';
  signal v2c_sign_d1 : bit6_arr := (others => '0');
  signal v2c_sign_d2 : bit6_arr := (others => '0');
  signal v2c_sign_d3 : bit6_arr := (others => '0');
  signal min1_idx_d1 : unsigned(2 downto 0) := (others => '0');
  signal min1_idx_d2 : unsigned(2 downto 0) := (others => '0');
  signal min1_idx_d3 : unsigned(2 downto 0) := (others => '0');
  signal op_cnt       : unsigned(7 downto 0);
  signal pipe_en      : std_logic_vector(15 downto 0);
  signal row_cnt_d1   : unsigned(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal llr_rd : llr6_arr := (others => (others => '0'));
  signal v2c      : wide6_arr := (others => (others => '0'));
  signal v2c_d1, v2c_d2, v2c_d3, v2c_d4, v2c_d5, v2c_d6, v2c_d7 : wide6_arr := (others => (others => '0'));
  signal v2c_abs  : abs6_arr := (others => (others => '0'));
  signal v2c_sign : bit6_arr := (others => '0');
  signal min1_val, min2_val : abs_s := (others => '0');
  signal min1_idx : unsigned(2 downto 0) := (others => '0');
  signal sign_product : std_logic := '0';
  signal min1_off, min2_off : abs_s := (others => '0');
  constant C_OFF_U : abs_s := to_unsigned(G_OFFSET_Q, abs_s'length);
  signal min1_sub, min2_sub : abs_s := (others => '0');
  signal mag_sel : abs6_arr := (others => (others => '0'));
  signal msg_new : wide6_arr := (others => (others => '0'));
  signal msg_new_q : llr6_arr := (others => (others => '0'));
  signal llr_new : wide6_arr := (others => (others => '0'));
  signal llr_new_q : llr6_arr := (others => (others => '0'));
signal llr_new_q_d1 : llr6_arr := (others => (others => '0'));
signal llr_new_q_d2 : llr6_arr := (others => (others => '0'));

  signal cn_en   : std_logic := '0';
  signal cn_we   : std_logic := '0';
  signal cn_addr : std_logic_vector(C_ADDR_W_M-1 downto 0) := (others => '0');
  signal cn_di   : std_logic_vector(C_CN_W-1 downto 0) := (others => '0');
  signal row_parity_in_dbg : std_logic := '0';
  signal row_parity_dbg : std_logic := '0';
  signal st_out_en : std_logic:='0';
  signal st_out_en_d1 : std_logic:='0';

begin

  main_pr : process(clk_i)
  variable v_min1_val, v_min2_val : abs_s := (others => '0');
  variable v_min1_idx : unsigned(2 downto 0) := (others => '0');
  variable v_row_parity_dbg : std_logic;
  variable v_parity_in : std_logic;
  variable v_sign : std_logic;
  
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then

        st <= ST_IDLE;

        in_cnt      <= (others => '0');
        pad_cnt     <= (others => '0');
        iter_cnt    <= (others => '0');
        iter_target <= (others => '0');
        row_cnt     <= (others => '0');
        out_cnt     <= (others => '0');

        op_cnt   <= (others => '0');
        pipe_en  <= (others => '0');

        row_cnt_d1  <= (others => '0');
        row_cnt_d2  <= (others => '0');
        row_cnt_d3  <= (others => '0');
        row_cnt_d4  <= (others => '0');
        row_cnt_d5  <= (others => '0');
        row_cnt_d6  <= (others => '0');
        row_cnt_d7  <= (others => '0');
        row_cnt_d8  <= (others => '0');
        row_cnt_d9  <= (others => '0');
        row_cnt_d10 <= (others => '0');

        edge_v      <= (others => '0');
        edge_v_d1   <= (others => '0');
        edge_v_d2   <= (others => '0');
        edge_v_d3   <= (others => '0');
        edge_v_d4   <= (others => '0');
        edge_v_d5   <= (others => '0');
        edge_v_d6   <= (others => '0');
        edge_v_d7   <= (others => '0');

        v2c         <= (others => (others => '0'));
        v2c_d1      <= (others => (others => '0'));
        v2c_d2      <= (others => (others => '0'));
        v2c_d3      <= (others => (others => '0'));
        v2c_d4      <= (others => (others => '0'));
        v2c_d5      <= (others => (others => '0'));
        v2c_d6      <= (others => (others => '0'));
        v2c_d7      <= (others => (others => '0'));
        v2c_abs     <= (others => (others => '0'));
        v2c_sign    <= (others => '0');

        v2c_sign_d1 <= (others => '0');
        v2c_sign_d2 <= (others => '0');
        v2c_sign_d3 <= (others => '0');

        sign_product      <= '0';
        sign_product_d1   <= '0';
        sign_product_d2   <= '0';
        sign_product_d3   <= '0';

        min1_val <= (others => '0');
        min2_val <= (others => '0');
        min1_idx <= (others => '0');
        min1_idx_d1 <= (others => '0');
        min1_idx_d2 <= (others => '0');
        min1_idx_d3 <= (others => '0');

        min1_sub <= (others => '0');
        min2_sub <= (others => '0');
        min1_off <= (others => '0');
        min2_off <= (others => '0');

        mag_sel   <= (others => (others => '0'));
        msg_new   <= (others => (others => '0'));
        msg_new_q <= (others => (others => '0'));

        cn_we   <= '0';
        cn_addr <= (others => '0');
        cn_di   <= (others => '0');

        ram0_wea <= '0';
        ram0_web <= '0';
        ram1_wea <= '0';
        ram1_web <= '0';
        ram2_wea <= '0';
        ram2_web <= '0';

        idx_vn_d1  <= (others => (others => '0'));
        idx_vn_d2  <= (others => (others => '0'));
        idx_vn_d3  <= (others => (others => '0'));
        idx_vn_d4  <= (others => (others => '0'));
        idx_vn_d5  <= (others => (others => '0'));
        idx_vn_d6  <= (others => (others => '0'));
        idx_vn_d7  <= (others => (others => '0'));
        idx_vn_d8  <= (others => (others => '0'));
        idx_vn_d9  <= (others => (others => '0'));
        idx_vn_d10 <= (others => (others => '0'));
        idx_vn_d11 <= (others => (others => '0'));

      else

        case st is
          when ST_IDLE =>

            if data_start_i = '1' then
              in_cnt <= (others => '0');
              pad_cnt <= (others => '0');
              iter_target <= unsigned(iter_cfg_i);
              iter_cnt <= (others => '0');
              row_cnt <= (others => '0');
              op_cnt <= (others => '0');
              pipe_en <= (others => '0');
              row_cnt_d1 <= (others=>'0');
              for i in 0 to 5 loop
                v2c(i) <= (others=>'0');
              end loop;
              v2c_d1 <= (others => (others => '0'));
              v2c_d2 <= (others => (others => '0'));
              v2c_d3 <= (others => (others => '0'));
              v2c_d4 <= (others => (others => '0'));
              v2c_d5 <= (others => (others => '0'));
              v2c_d6 <= (others => (others => '0'));
              v2c_d7 <= (others => (others => '0'));
              min1_val <= (others => '1');  -- max possible
              min2_val <= (others => '1');
              min1_idx <= (others => '0');
              edge_v      <= (others => '0');
              edge_v_d1   <= (others => '0');
              edge_v_d2   <= (others => '0');
              edge_v_d3   <= (others => '0');
              edge_v_d4   <= (others => '0');
              edge_v_d5   <= (others => '0');
              edge_v_d6   <= (others => '0');
              edge_v_d7   <= (others => '0');
              sign_product_d1 <= '0';
              sign_product_d2 <= '0';
              sign_product_d3 <= '0';
              v2c_sign_d1 <= (others => '0');
              v2c_sign_d2 <= (others => '0');
              v2c_sign_d3 <= (others => '0');
              min1_idx_d1 <= (others => '0');
              min1_idx_d2 <= (others => '0');
              min1_idx_d3 <= (others => '0');
              edge_v_d11 <= (others => '0');
              edge_v_d12 <= (others => '0');
              llr_new_q_d1 <= (others => (others => '0'));
              llr_new_q_d2 <= (others => (others => '0'));
              idx_vn_d12 <= (others => (others => '0'));
              st <= ST_LOAD;
            end if;
            
          when ST_LOAD =>
            -- Load 2048 LLRs; write to all three RAMs using port A (single write per cycle)
            if data_valid_i = '1' then
              ram0_addra <= std_logic_vector(in_cnt);
              ram1_addra <= std_logic_vector(in_cnt);
              ram2_addra <= std_logic_vector(in_cnt);
              ram0_dia <= data_i;
              ram1_dia <= data_i;
              ram2_dia <= data_i;
              ram0_wea <= '1';
              ram1_wea <= '1';
              ram2_wea <= '1';
            
              if in_cnt = to_unsigned(G_IN_N-1, in_cnt'length) then
                pad_cnt <= to_unsigned(G_IN_N, pad_cnt'length);
                st <= ST_PAD0;
              else
                in_cnt <= in_cnt + 1;
              end if;
            end if;
              
          when ST_PAD0 =>
            -- Pad remaining VNs with 0 (512 writes)
            ram0_addra <= std_logic_vector(pad_cnt);
            ram1_addra <= std_logic_vector(pad_cnt);
            ram2_addra <= std_logic_vector(pad_cnt);
            ram0_dia <= (others => '0');
            ram1_dia <= (others => '0');
            ram2_dia <= (others => '0');
            ram0_wea <= '1';
            ram1_wea <= '1';
            ram2_wea <= '1';
            if pad_cnt = to_unsigned(G_FULL_N-1, pad_cnt'length) then
              row_cnt <= (others => '0');

              st <= ST_OPERATING;
            else
              pad_cnt <= pad_cnt + 1;
            end if;

          when ST_OPERATING =>
            -- DECODING Implemented in the if below out of the case
            -- Leave the state
            if pipe_en(15)='1' and row_cnt=to_unsigned(1536,C_ADDR_W_M) then
              out_cnt <= (others=>'0');
              st <= ST_OUT;
            end if;

          when ST_OUT =>
              -- Read the decoded message from RAM
              if out_cnt=to_unsigned(1024,16) then
                st_out_en <= '0';
              else
                out_cnt <= out_cnt+1;
                st_out_en <= '1';
              end if;
              ram0_addra <= std_logic_vector( out_cnt(11 downto 0));

          when others =>
        end case;
        st_out_en_d1 <= st_out_en;

        -- Pipeline
        if st=ST_OPERATING then

            -- Ranm en init
            ram0_wea <= '0';
            ram1_wea <= '0';
            ram2_wea <= '0';

            -- Pipeline enable counter
            if op_cnt=to_unsigned(15,8) then
              op_cnt <= (others=>'0');
            else
              op_cnt <= op_cnt + 1;
            end if;

            -- Pipeline enables
            pipe_en(15 downto 1) <= pipe_en(14 downto 0);
            if row_cnt=to_unsigned(1536,C_ADDR_W_M) then --Freeze the pipeline at the last row
            elsif op_cnt=to_unsigned(0,8) then
              pipe_en(0) <= '1';
            else
              pipe_en(0) <= '0';
            end if;

            -- Pipe 0
            if pipe_en(0)='1' then
              row_cnt <= row_cnt+1;
            end if;
            row_cnt_d1 <= row_cnt;

            -- Pipe 1
            -- Rom output is ready
            if pipe_en(1)='1' then
              -- Calculate LLR ram addr
              ram0_addra <= std_logic_vector( unsigned(idx_raw_slv(0)(C_ADDR_W_VN-1 downto 0)) - 1 );
              ram0_addrb <= std_logic_vector( unsigned(idx_raw_slv(1)(C_ADDR_W_VN-1 downto 0)) - 1 );
              ram1_addra <= std_logic_vector( unsigned(idx_raw_slv(2)(C_ADDR_W_VN-1 downto 0)) - 1 );
              ram1_addrb <= std_logic_vector( unsigned(idx_raw_slv(3)(C_ADDR_W_VN-1 downto 0)) - 1 );
              ram2_addra <= std_logic_vector( unsigned(idx_raw_slv(4)(C_ADDR_W_VN-1 downto 0)) - 1 );
              ram2_addrb <= std_logic_vector( unsigned(idx_raw_slv(5)(C_ADDR_W_VN-1 downto 0)) - 1 );

              --CN addr
              cn_addr <= std_logic_vector(row_cnt_d1);
              cn_we <= '0';

              -- Calculate edge masks
              for i in 0 to 5 loop
                if idx_raw_slv(i)=x"000" then
                  edge_v(i) <= '0';
                else
                  edge_v(i) <= '1';
                end if;
              end loop;

              -- idx VN
                for i in 0 to 5 loop
                  if idx_raw_slv(i) = x"000" then
                    idx_vn(i) <= (others => '0');
                  else
                    idx_vn(i) <= unsigned(idx_raw_slv(i)(C_ADDR_W_VN-1 downto 0)) - 1;
                  end if;
                end loop;

            end if; --end pipe

            -- pipe2
            if pipe_en(2)='1' then

            end if;
            edge_v_d1 <= edge_v;
            row_cnt_d2 <= row_cnt_d1;
            idx_vn_d1 <= idx_vn;

            --Pipe 3 LLR read addr ready
            --Calculate v2c
            if pipe_en(3)='1' then
              for i in 0 to 5 loop
                v2c(i) <= resize(llr_rd(i), v2c(i)'length) - resize(cn_old(i), v2c(i)'length);
              end loop;

              -- DEBUG parity before CN update
              v_parity_in := '0';
              for i in 0 to 5 loop
                if edge_v_d1(i) = '1' then
                  v_parity_in := v_parity_in xor (   (llr_rd(i)(G_LLR_W-1)));
                end if;
              end loop;
              row_parity_in_dbg <= v_parity_in;
              -- END DEBUG parity before CN update

            end if;
            edge_v_d2 <= edge_v_d1;
            row_cnt_d3 <= row_cnt_d2;
            idx_vn_d2 <= idx_vn_d1;
            v2c_d1 <= v2c;

            --Pipe 4
            --Calculate ABS and sign
            if pipe_en(4)='1' then

              -- abs first
              for i in 0 to 5 loop
                --avoid overvlow
                if v2c(i) = to_signed(-256, 9) then
                  v2c_abs(i) <= to_unsigned(255, 9);
                elsif v2c(i) < 0 then
                  v2c_abs(i) <= unsigned(-v2c(i));
                else
                  v2c_abs(i) <= unsigned(v2c(i));
                end if;
              end loop;

              --sign
              for i in 0 to 5 loop
                v2c_sign(i) <= v2c(i)(8);
              end loop;

            end if;-- end pipe
            edge_v_d3 <= edge_v_d2;
            row_cnt_d3 <= row_cnt_d2;
            idx_vn_d3 <= idx_vn_d2;
            v2c_d2 <= v2c_d1;

            -- Pipe5
            -- Find min1 min2 and index
            if pipe_en(5)='1' then

              -- mins and index
              v_min1_val := (others => '1');  -- max possible
              v_min2_val := (others => '1');
              v_min1_idx := (others => '0');

              v_sign := '0';

              for i in 0 to 5 loop

                if v2c_abs(i) < v_min1_val then
                  v_min2_val := v_min1_val;
                  v_min1_val := v2c_abs(i);
                  v_min1_idx := to_unsigned(i,3);
                elsif v2c_abs(i) < v_min2_val then
                  v_min2_val := v2c_abs(i);
                end if;

                min2_val <= v_min2_val;
                min1_val <= v_min1_val;
                min1_idx <= v_min1_idx;

                -- signs xor
                v_sign := v_sign xor v2c_sign(i);
              
              end loop;
              sign_product <= v_sign;

            end if;
            edge_v_d4 <= edge_v_d3;
            row_cnt_d4 <= row_cnt_d3;
            idx_vn_d4 <= idx_vn_d3;
            min1_idx_d1 <= min1_idx;
            v2c_d3 <= v2c_d2;

            -- Pipe6
            if pipe_en(6) = '1' then

              -- min1_sub = max(min1_val - offset, 0)
              if min1_val <= C_OFF_U then
                min1_sub <= (others => '0');
              else
                min1_sub <= min1_val - C_OFF_U;
              end if;

              -- min2_sub = max(min2_val - offset, 0)
              if min2_val <= C_OFF_U then
                min2_sub <= (others => '0');
              else
                min2_sub <= min2_val - C_OFF_U;
              end if;

            end if;
            edge_v_d5 <= edge_v_d4;
            row_cnt_d5 <= row_cnt_d4;
            idx_vn_d5 <= idx_vn_d4;
            sign_product_d1 <= sign_product;
            v2c_sign_d1 <= v2c_sign;
            min1_idx_d2 <= min1_idx_d1;
            v2c_d4 <= v2c_d3;

            -- Pipe7
            if pipe_en(7) = '1' then

              -- min1_off = min(min1_sub, 31)
              if min1_sub > to_unsigned(31, min1_sub'length) then
                min1_off <= to_unsigned(31, min1_off'length);
              else
                min1_off <= min1_sub;
              end if;

              -- min2_off = min(min2_sub, 31)
              if min2_sub > to_unsigned(31, min2_sub'length) then
                min2_off <= to_unsigned(31, min2_off'length);
              else
                min2_off <= min2_sub;
              end if;

            end if;
            edge_v_d6 <= edge_v_d5;
            row_cnt_d6 <= row_cnt_d5;
            idx_vn_d6 <= idx_vn_d5;
            sign_product_d2 <= sign_product_d1;
            v2c_sign_d2 <= v2c_sign_d1; 
            min1_idx_d3 <= min1_idx_d2;
            v2c_d5 <= v2c_d4;


            -- Pipe8 : magnitude selection
            if pipe_en(8) = '1' then

              for i in 0 to 5 loop
                if edge_v_d5(i) = '1' then
                  if min1_idx_d3 = to_unsigned(i,3) then
                    mag_sel(i) <= min2_off;
                  else
                    mag_sel(i) <= min1_off;
                  end if;
                else
                  mag_sel(i) <= (others => '0');
                end if;
              end loop;

            end if; --end pipe 8
            row_cnt_d7 <= row_cnt_d6;
            edge_v_d7 <= edge_v_d6;
            idx_vn_d7 <= idx_vn_d6;
            sign_product_d3 <= sign_product_d2;
            v2c_sign_d3 <= v2c_sign_d2; 
            v2c_d6 <= v2c_d5;

            -- pipe 9
            --New sign and apply to magnitude
            if pipe_en(9) = '1' then
    
              for i in 0 to 5 loop
                if edge_v_d6(i) = '1' then
                  if (sign_product_d3 xor v2c_sign_d3(i)) = '1' then
                    msg_new(i) <= -signed(resize(mag_sel(i), llr_wide_s'length));
                  else
                    msg_new(i) <=  signed(resize(mag_sel(i), llr_wide_s'length));
                  end if;
                else
                  msg_new(i) <= (others => '0');
                end if;
              end loop;
    
            end if; --end pipe 9
            row_cnt_d9 <= row_cnt_d8;
            edge_v_d8 <= edge_v_d7;
            idx_vn_d8 <= idx_vn_d7;
            v2c_d7 <= v2c_d6;

            -- pipe 10
            if pipe_en(10) = '1' then

              -- clamp to 6-bit
              for i in 0 to 5 loop
                if msg_new(i) > to_signed(31, msg_new(i)'length) then
                  msg_new_q(i) <= to_signed(31, G_LLR_W);
                elsif msg_new(i) < to_signed(-31, msg_new(i)'length) then
                  msg_new_q(i) <= to_signed(-31, G_LLR_W);
                else
                  msg_new_q(i) <= resize(msg_new(i), G_LLR_W);
                end if;
              end loop;

              -- Compute new LLR
              for i in 0 to 5 loop
                llr_new(i) <= v2c_d7(i) + resize(msg_new(i), llr_wide_s'length);
              end loop;

            end if; --end pipe10
              row_cnt_d10 <= row_cnt_d9;
            edge_v_d9 <= edge_v_d8;
            idx_vn_d9 <= idx_vn_d8;

            if pipe_en(11) = '1' then

                -- pack
                cn_di <= std_logic_vector(msg_new_q(0)) &
                        std_logic_vector(msg_new_q(1)) &
                        std_logic_vector(msg_new_q(2)) &
                        std_logic_vector(msg_new_q(3)) &
                        std_logic_vector(msg_new_q(4)) &
                        std_logic_vector(msg_new_q(5));
                cn_addr <= std_logic_vector(row_cnt_d9);  -- or properly delayed
                cn_we   <= '1';

                -- Clamp llr
                for i in 0 to 5 loop
                  if llr_new(i) > to_signed(31, llr_new(i)'length) then
                    llr_new_q(i) <= to_signed(31, G_LLR_W);
                  elsif llr_new(i) < to_signed(-31, llr_new(i)'length) then
                    llr_new_q(i) <= to_signed(-31, G_LLR_W);
                  else
                    llr_new_q(i) <= resize(llr_new(i), G_LLR_W);
                  end if;
                end loop;

              else
                cn_we   <= '0';
              end if; --end pipe11
              row_cnt_d11 <= row_cnt_d10;
              edge_v_d10 <= edge_v_d9;
              idx_vn_d10 <= idx_vn_d9;
            
            if pipe_en(12) = '1' then

              -- Write edges 0 and 1

              ram0_addra <= std_logic_vector(idx_vn_d10(0));
              ram0_dia   <= std_logic_vector(llr_new_q(0));
              ram0_wea   <= edge_v_d10(0);

              ram0_addrb <= std_logic_vector(idx_vn_d10(1));
              ram0_dib   <= std_logic_vector(llr_new_q(1));
              ram0_web   <= edge_v_d10(1);

              ram1_addra <= std_logic_vector(idx_vn_d10(0));
              ram1_dia   <= std_logic_vector(llr_new_q(0));
              ram1_wea   <= edge_v_d10(2);

              ram1_addrb <= std_logic_vector(idx_vn_d10(1));
              ram1_dib   <= std_logic_vector(llr_new_q(1));
              ram1_web   <= edge_v_d10(3);

              ram2_addra <= std_logic_vector(idx_vn_d10(0));
              ram2_dia   <= std_logic_vector(llr_new_q(0));
              ram2_wea   <= edge_v_d10(4);

              ram2_addrb <= std_logic_vector(idx_vn_d10(1));
              ram2_dib   <= std_logic_vector(llr_new_q(1));
              ram2_web   <= edge_v_d10(5);

              -- DEBUG CHECK
              v_row_parity_dbg := '0';
              for i in 0 to 5 loop
                if edge_v_d10(i) = '1' then
                  v_row_parity_dbg := v_row_parity_dbg xor llr_new_q(i)(G_LLR_W-1);
                end if;
              end loop;
              row_parity_dbg <= v_row_parity_dbg;
              -- END debug check

            else

              ram0_wea   <= '0';
              ram0_web   <= '0';
              ram1_wea   <= '0';
              ram1_web   <= '0';
              ram2_wea   <= '0';
              ram2_web   <= '0';

            end if; --end pipe12
            edge_v_d11 <= edge_v_d10;
            idx_vn_d11 <= idx_vn_d10;
            llr_new_q_d1 <= llr_new_q;


            if pipe_en(13) = '1' then

              -- Write edges 2 and 3

              ram0_addra <= std_logic_vector(idx_vn_d11(2));
              ram0_dia   <= std_logic_vector(llr_new_q_d1(2));
              ram0_wea   <= edge_v_d11(0);

              ram0_addrb <= std_logic_vector(idx_vn_d11(3));
              ram0_dib   <= std_logic_vector(llr_new_q_d1(3));
              ram0_web   <= edge_v_d11(1);

              ram1_addra <= std_logic_vector(idx_vn_d11(2));
              ram1_dia   <= std_logic_vector(llr_new_q_d1(2));
              ram1_wea   <= edge_v_d11(2);

              ram1_addrb <= std_logic_vector(idx_vn_d11(3));
              ram1_dib   <= std_logic_vector(llr_new_q_d1(3));
              ram1_web   <= edge_v_d11(3);

              ram2_addra <= std_logic_vector(idx_vn_d11(2));
              ram2_dia   <= std_logic_vector(llr_new_q_d1(2));
              ram2_wea   <= edge_v_d11(4);

              ram2_addrb <= std_logic_vector(idx_vn_d11(3));
              ram2_dib   <= std_logic_vector(llr_new_q_d1(3));
              ram2_web   <= edge_v_d11(5);

            else

              ram0_wea   <= '0';
              ram0_web   <= '0';
              ram1_wea   <= '0';
              ram1_web   <= '0';
              ram2_wea   <= '0';
              ram2_web   <= '0';

            end if; --end pipe13
            edge_v_d12 <= edge_v_d11;
            idx_vn_d12 <= idx_vn_d11;
            llr_new_q_d2 <= llr_new_q_d1;

            -- Pipe 14
            if pipe_en(14) = '1' then

              -- Write edges 4 and 5

              ram0_addra <= std_logic_vector(idx_vn_d12(4));
              ram0_dia   <= std_logic_vector(llr_new_q_d2(4));
              ram0_wea   <= edge_v_d12(0);

              ram0_addrb <= std_logic_vector(idx_vn_d12(5));
              ram0_dib   <= std_logic_vector(llr_new_q_d2(5));
              ram0_web   <= edge_v_d12(1);

              ram1_addra <= std_logic_vector(idx_vn_d12(4));
              ram1_dia   <= std_logic_vector(llr_new_q_d2(4));
              ram1_wea   <= edge_v_d12(2);

              ram1_addrb <= std_logic_vector(idx_vn_d12(5));
              ram1_dib   <= std_logic_vector(llr_new_q_d2(5));
              ram1_web   <= edge_v_d12(3);

              ram2_addra <= std_logic_vector(idx_vn_d12(4));
              ram2_dia   <= std_logic_vector(llr_new_q_d2(4));
              ram2_wea   <= edge_v_d12(4);

              ram2_addrb <= std_logic_vector(idx_vn_d12(5));
              ram2_dib   <= std_logic_vector(llr_new_q_d2(5));
              ram2_web   <= edge_v_d12(5);

            else

              ram0_wea   <= '0';
              ram0_web   <= '0';
              ram1_wea   <= '0';
              ram1_web   <= '0';
              ram2_wea   <= '0';
              ram2_web   <= '0';

            end if; --end pipe13
        end if;   -- st = ST_OPERATING
      end if;     -- rst_i
    end if;       -- rising_edge(clk_i)
  end process;

  --Always enable cn ram
  cn_en <= '1';

  -- VN RAM instances (replicated)
  u_ram0 : tdp_ram_rf_rf
    generic map (G_ADDR_W => C_ADDR_W_VN, G_DATA_W => G_LLR_W)
    port map (
      clk_i => clk_i,
      ena_i => ram0_ena, wea_i => ram0_wea,
      addra_i => ram0_addra,
      dia_i => ram0_dia,
      doa_o => ram0_doa,
      enb_i => ram0_enb, web_i => ram0_web,
      addrb_i => ram0_addrb,
      dib_i => ram0_dib,
      dob_o => ram0_dob
    );

  u_ram1 : tdp_ram_rf_rf
    generic map (G_ADDR_W => C_ADDR_W_VN, G_DATA_W => G_LLR_W)
    port map (
      clk_i => clk_i,
      ena_i => ram1_ena, wea_i => ram1_wea,
      addra_i => ram1_addra,
      dia_i => ram1_dia,
      doa_o => ram1_doa,
      enb_i => ram1_enb, web_i => ram1_web,
      addrb_i => ram1_addrb,
      dib_i => ram1_dib,
      dob_o => ram1_dob
    );

  u_ram2 : tdp_ram_rf_rf
    generic map (G_ADDR_W => C_ADDR_W_VN, G_DATA_W => G_LLR_W)
    port map (
      clk_i => clk_i,
      ena_i => ram2_ena, wea_i => ram2_wea,
      addra_i => ram2_addra,
      dia_i => ram2_dia,
      doa_o => ram2_doa,
      enb_i => ram2_enb, web_i => ram2_web,
      addrb_i => ram2_addrb,
      dib_i => ram2_dib,
      dob_o => ram2_dob
    );

  -- CN message RAM (packed 6x6-bit signed)
  u_cn : sp_ram_rf
    generic map (G_ADDR_W => C_ADDR_W_M, G_DATA_W => C_CN_W)
    port map (
      clk_i => clk_i,
      en_i  => cn_en,
      we_i  => cn_we,
      addr_i => cn_addr,
      di_i   => cn_di,
      do_o   => cn_do
    );

  -- H row ROM
  u_rom : h_row_rom
    generic map (G_M => G_M, G_IDX_W => G_IDX_W)
    port map (
      clk_i => clk_i,
      en_i  => pipe_en(0),
      row_i => std_logic_vector(row_cnt),
      idx0_o => idx_raw_slv(0),
      idx1_o => idx_raw_slv(1),
      idx2_o => idx_raw_slv(2),
      idx3_o => idx_raw_slv(3),
      idx4_o => idx_raw_slv(4),
      idx5_o => idx_raw_slv(5)
    );

-- VN read outputs mapping
llr_rd(0) <= signed(ram0_doa);
llr_rd(1) <= signed(ram0_dob);
llr_rd(2) <= signed(ram1_doa);
llr_rd(3) <= signed(ram1_dob);
llr_rd(4) <= signed(ram2_doa);
llr_rd(5) <= signed(ram2_dob);

-- Unpack CN old word (signed 6-bit slices)
cn_old(0) <= signed(cn_do(6*G_LLR_W-1 downto 5*G_LLR_W));
cn_old(1) <= signed(cn_do(5*G_LLR_W-1 downto 4*G_LLR_W));
cn_old(2) <= signed(cn_do(4*G_LLR_W-1 downto 3*G_LLR_W));
cn_old(3) <= signed(cn_do(3*G_LLR_W-1 downto 2*G_LLR_W));
cn_old(4) <= signed(cn_do(2*G_LLR_W-1 downto 1*G_LLR_W));
cn_old(5) <= signed(cn_do(1*G_LLR_W-1 downto 0*G_LLR_W));

-- Output
data_o        <= (llr_rd(0)(5)) when st_out_en_d1='1' else '0'; 
data_valid_o  <= st_out_en_d1;
data_start_o  <= '1' when (out_cnt=to_unsigned(2,14) and st_out_en_d1='1') else '0';


end architecture;
