----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Wang Weichen
-- 
-- Create Date: 11:03:14 07/11/2026 
-- Design Name: 
-- Module Name: ldpc_layered_decode - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:
-- DVB-S2/S2X general layered-decoder top-level for ldpc_layered_decode_8ch.
--
-- Runtime frame support follows ldpc_layered_parameter and the existing LLR
-- adjust module: normal 64800, medium 32400 and short 16200 bit modes.  Z stays
-- fixed at 360; RAM/counter bounds use the maximum among all supported modes.
-- weight='0' remains the final valid slot of each layer.
--
-- Naming used in this file:
--   soft_total_ram   = APP RAM, stores current variable-node total soft value
--   check_msg_ram    = R-message RAM, stores old CNU-to-VNU message per real edge
--   old_check_msg    = old message read from check_msg_ram(msg_addr)
--   new_check_msg    = new CNU message for the same msg_addr
--   var_to_check_msg = soft_total - old_check_msg, then saturated to 6 bit
--
-- The frame FSM controls only input/load/decode/output phases.  Layer and
-- iteration progress is event-driven by parameter-valid, CNU-valid and RAM
-- writeback signals, so state transitions do not insert datapath bubbles.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity new_dvb_rx_ldpc_layered_decode is
    Port (
        i_clk        : in  STD_LOGIC;
        i_rst        : in  STD_LOGIC;
        i_llr_start  : in  STD_LOGIC;
        iv_len       : in  STD_LOGIC_VECTOR(1 downto 0);
        iv_rate      : in  STD_LOGIC_VECTOR(5 downto 0);
        iv_iter      : in  STD_LOGIC_VECTOR(7 downto 0);
        iv_llr       : in  STD_LOGIC_VECTOR(47 downto 0);
        i_llr_en     : in  STD_LOGIC;
        i_workflag   : in  STD_LOGIC;

        -- Frame-input handshake/status.  An upstream module may transfer one
        -- 8-LLR word only when i_llr_en='1' and o_llr_ready='1'.
        o_llr_ready  : out STD_LOGIC;
        o_busy       : out STD_LOGIC;
        o_frame_done : out STD_LOGIC;

        o_data       : out STD_LOGIC_VECTOR(7 downto 0);
        o_data_en    : out STD_LOGIC
    );
end new_dvb_rx_ldpc_layered_decode;

architecture Behavioral of new_dvb_rx_ldpc_layered_decode is

    constant C_Z                : integer := 360;
    constant C_LANE_GROUPS      : integer := 45;   -- 360 / 8
    constant C_MAX_VN_BLOCKS    : integer := 180;  -- normal frame: 64800 / 360
    constant C_MAX_INFO_BLOCKS  : integer := 162;  -- normal frame 9/10
    constant C_MAX_REAL_EDGES   : integer := 792;  -- maximum among all ROM schedules
    constant C_MAX_LAYER_SLOTS  : integer := 30;   -- maximum row slot count
    constant C_MAX_INPUT_WORDS  : integer := 8100; -- 64800 / 8
    constant C_MAX_POS          : integer := 180;  -- pos=181 is the dummy and is never read

    COMPONENT ldpc_decode_llr_adjust_8ch
    PORT(
        i_clk    : IN  STD_LOGIC;
        i_rst    : IN  STD_LOGIC;
        iv_len   : IN  STD_LOGIC_VECTOR(1 downto 0);
        iv_rate  : IN  STD_LOGIC_VECTOR(5 downto 0);
        iv_llr   : IN  STD_LOGIC_VECTOR(47 downto 0);
        i_llr_en : IN  STD_LOGIC;
        ov_blk_k : OUT STD_LOGIC_VECTOR(7 downto 0);
        ov_blk_n : OUT STD_LOGIC_VECTOR(7 downto 0);
        ov_llr   : OUT STD_LOGIC_VECTOR(47 downto 0);
        o_llr_en : OUT STD_LOGIC
    );
    END COMPONENT;

    COMPONENT ldpc_layered_parameter
    PORT(
        i_clk        : IN  STD_LOGIC;
        i_rst        : IN  STD_LOGIC;
        iv_len       : IN  STD_LOGIC_VECTOR(1 downto 0);
        iv_rate      : IN  STD_LOGIC_VECTOR(5 downto 0);
        i_start      : IN  STD_LOGIC;
        i_next_layer : IN  STD_LOGIC;
        i_advance    : IN  STD_LOGIC;
        o_supported  : OUT STD_LOGIC;
        o_done       : OUT STD_LOGIC;
        o_word_valid : OUT STD_LOGIC;
        o_row_end    : OUT STD_LOGIC;
        o_edge_valid : OUT STD_LOGIC;
        ov_pos       : OUT STD_LOGIC_VECTOR(7 downto 0);
        ov_msg_addr  : OUT STD_LOGIC_VECTOR(9 downto 0);
        ov_fwd_shift : OUT STD_LOGIC_VECTOR(8 downto 0);
        ov_rev_shift : OUT STD_LOGIC_VECTOR(8 downto 0)
    );
    END COMPONENT;

    COMPONENT soft_total_ram
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 rstb : IN STD_LOGIC;
		 dina : IN STD_LOGIC_VECTOR(989 DOWNTO 0);
		 clkb : IN STD_LOGIC;
		 rsta_busy : OUT STD_LOGIC;
         rstb_busy : OUT STD_LOGIC;
		 addrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 doutb : OUT STD_LOGIC_VECTOR(989 DOWNTO 0)
	  );
	END COMPONENT;

    COMPONENT check_msg_ram
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		 dina : IN STD_LOGIC_VECTOR(1079 DOWNTO 0);
		 rstb : IN STD_LOGIC;
		 clkb : IN STD_LOGIC;
		 rsta_busy : OUT STD_LOGIC;
		 rstb_busy : OUT STD_LOGIC;
		 addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		 doutb : OUT STD_LOGIC_VECTOR(1079 DOWNTO 0)
	  );
	END COMPONENT;

    COMPONENT ldpc_layered_barrel_shifter_360
    PORT(
        i_clk    : IN  STD_LOGIC;
        i_rst    : IN  STD_LOGIC;
        i_valid  : IN  STD_LOGIC;
        iv_shift : IN  STD_LOGIC_VECTOR(8 downto 0);
        iv_data  : IN  STD_LOGIC_VECTOR(2159 downto 0);
        o_valid  : OUT STD_LOGIC;
        ov_data  : OUT STD_LOGIC_VECTOR(2159 downto 0)
    );
    END COMPONENT;

    -- Layered CNU uses explicit slot/edge/row-boundary signals and returns real
    -- edges in their input order.
    COMPONENT ldpc_layered_cnu_360
    PORT(
        i_clk          : IN  STD_LOGIC;
        i_rst          : IN  STD_LOGIC;
        i_slot_valid   : IN  STD_LOGIC; -- high for real edge and dummy bubble
        i_edge_valid   : IN  STD_LOGIC; -- high only for pos /= 181
        i_dummy        : IN  STD_LOGIC;
        i_row_end      : IN  STD_LOGIC;
        iv_v2c_chk     : IN  STD_LOGIC_VECTOR(2159 downto 0);
        o_r_valid      : OUT STD_LOGIC;
        o_r_edge_valid : OUT STD_LOGIC;
        ov_r_new_chk   : OUT STD_LOGIC_VECTOR(2159 downto 0)
    );
    END COMPONENT;

    type state_t is (
        ST_IDLE,
        ST_CAPTURE_LLR,
        ST_WAIT_ADJUST,
        ST_LOAD_SOFT,
        ST_DECODE,
        ST_HARD_OUT
    );

    -- One layer contains at most 30 slots in the complete ROM table.  Strict
    -- layer-by-layer scheduling drains all real contexts before the next layer,
    -- so a 32-entry context FIFO is sufficient.
    type ctx_pos_t   is array(0 to 31) of STD_LOGIC_VECTOR(7 downto 0);
    type ctx_msg_t   is array(0 to 31) of STD_LOGIC_VECTOR(9 downto 0);
    type ctx_shift_t is array(0 to 31) of STD_LOGIC_VECTOR(8 downto 0);
    type ctx_data_t  is array(0 to 31) of STD_LOGIC_VECTOR(2159 downto 0);
    type ctx_bit_t   is array(0 to 31) of STD_LOGIC;

    signal state          : state_t := ST_IDLE;

    signal s_llr_ready      : STD_LOGIC := '0';
    signal frame_start_fire : STD_LOGIC := '0';
    signal llr_accept_fire  : STD_LOGIC := '0';
    signal last_llr_fire    : STD_LOGIC := '0';
    signal llr_d1         : STD_LOGIC_VECTOR(47 downto 0);
    signal llr_en_d1      : STD_LOGIC;
    signal len_d1         : STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
    signal rate_d1        : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');
    signal frame_len_s    : STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
    signal frame_rate_s   : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');
    signal iter_d1        : STD_LOGIC_VECTOR(7 downto 0);
    signal iter_cnt       : STD_LOGIC_VECTOR(7 downto 0);
    
    signal adj_blk_k      : STD_LOGIC_VECTOR(7 downto 0);
    signal adj_blk_n      : STD_LOGIC_VECTOR(7 downto 0);
    signal adj_llr        : STD_LOGIC_VECTOR(47 downto 0);
    signal adj_llr_en     : STD_LOGIC;
    signal blk_k_d1       : STD_LOGIC_VECTOR(7 downto 0);
    signal blk_n_d1       : STD_LOGIC_VECTOR(7 downto 0);
    signal input_words_latched : integer range 1 to C_MAX_INPUT_WORDS := 2025;
    signal input_word_cnt : integer range 0 to C_MAX_INPUT_WORDS-1 := 0;
    signal check_clear_cnt : integer range 0 to C_MAX_REAL_EDGES := 0;
    signal check_clear_done : STD_LOGIC := '0';


    signal pending_edge_count       : integer range 0 to C_MAX_LAYER_SLOTS := 0;
    signal pending_edge_count_next  : integer range 0 to C_MAX_LAYER_SLOTS := 0;
    signal layer_schedule_done_seen : STD_LOGIC := '0';
    signal layer_schedule_done_next : STD_LOGIC := '0';
    signal iteration_schedule_done_seen : STD_LOGIC := '0';
    signal iteration_schedule_done_next : STD_LOGIC := '0';
    signal layer_drain_done     : STD_LOGIC := '0';
    signal iteration_drain_done : STD_LOGIC := '0';

    -- Single-write-port RAM control requests.  Arithmetic/load processes
    -- prepare address/data and the muxes below drive each physical IP port.
    signal soft_update_we    : STD_LOGIC := '0';
    signal soft_update_addr  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal soft_update_data  : STD_LOGIC_VECTOR(3959 downto 0) := (others => '0');
    signal soft_load_we      : STD_LOGIC := '0';
    signal soft_load_addr    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal soft_load_data    : STD_LOGIC_VECTOR(3959 downto 0) := (others => '0');
    signal soft_ram_we       : STD_LOGIC := '0';
    signal soft_ram_wr_addr  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal soft_ram_wr_data  : STD_LOGIC_VECTOR(3959 downto 0) := (others => '0');
    signal soft_ram_rd_addr  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal check_clear_we    : STD_LOGIC := '0';
    signal check_clear_addr_req : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal check_update_we   : STD_LOGIC := '0';
    signal check_update_addr : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal check_update_data : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');
    signal check_ram_we      : STD_LOGIC := '0';
    signal check_ram_wr_addr : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal check_ram_wr_data : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');

    -- Registered parameter-to-RAM read request and two-stage metadata pipeline.
    signal soft_read_addr     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal soft_read_data     : STD_LOGIC_VECTOR(3959 downto 0) := (others => '0');
    signal check_read_addr    : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal check_read_data    : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');

    signal param_slot_d1, param_slot_d2   : STD_LOGIC := '0';
    signal param_edge_d1, param_edge_d2   : STD_LOGIC := '0';
    signal param_dummy_d1, param_dummy_d2 : STD_LOGIC := '0';
    signal param_end_d1, param_end_d2     : STD_LOGIC := '0';
    signal param_pos_d1, param_pos_d2     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal param_msg_d1, param_msg_d2     : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal param_fwd_d1, param_fwd_d2     : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    signal param_rev_d1, param_rev_d2     : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');

    signal load_pos       : integer range 0 to C_MAX_VN_BLOCKS-1 := 0;
    signal load_group     : integer range 0 to C_LANE_GROUPS-1 := 0;
    signal load_word      : STD_LOGIC_VECTOR(3959 downto 0) := (others => '0');
    signal soft_load_done : STD_LOGIC := '0';

    signal p_start        : STD_LOGIC := '0';
    signal p_next_layer   : STD_LOGIC := '0';
    signal p_supported    : STD_LOGIC;
    signal p_done         : STD_LOGIC;
    signal p_word_valid   : STD_LOGIC;
    signal p_row_end      : STD_LOGIC;
    signal p_edge_valid   : STD_LOGIC;
    signal p_pos          : STD_LOGIC_VECTOR(7 downto 0);
    signal p_msg_addr     : STD_LOGIC_VECTOR(9 downto 0);
    signal p_fwd_shift    : STD_LOGIC_VECTOR(8 downto 0);
    signal p_rev_shift    : STD_LOGIC_VECTOR(8 downto 0);

    -- Variable-to-check message (V2C), formerly called Q in LDPC equations.
    signal v2c_calc_data     : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');
    signal v2c_calc_valid    : STD_LOGIC := '0';
    signal v2c_calc_shift    : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    signal v2c_calc_edge     : STD_LOGIC := '0';
    signal v2c_calc_dummy    : STD_LOGIC := '0';
    signal v2c_calc_row_end  : STD_LOGIC := '0';
    signal v2c_before_shift : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');
    signal v2c_shift_valid  : STD_LOGIC := '0';
    signal v2c_shift_code   : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    signal fwd_valid      : STD_LOGIC;
    signal fwd_data       : STD_LOGIC_VECTOR(2159 downto 0);

    signal row_end_d1, row_end_d2, row_end_d3, row_end_d4, row_end_d5 : STD_LOGIC := '0';
    signal edge_d1, edge_d2, edge_d3, edge_d4, edge_d5                : STD_LOGIC := '0';
    signal dummy_d1, dummy_d2, dummy_d3, dummy_d4, dummy_d5          : STD_LOGIC := '0';

    signal cnu_slot_valid : STD_LOGIC := '0';
    signal cnu_edge_valid : STD_LOGIC := '0';
    signal cnu_dummy      : STD_LOGIC := '0';
    signal cnu_row_end    : STD_LOGIC := '0';
    signal cnu_in_data    : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');
    signal cnu_r_valid    : STD_LOGIC;
    signal cnu_r_edge     : STD_LOGIC;
    signal cnu_r_chk      : STD_LOGIC_VECTOR(2159 downto 0);

    signal rev_valid      : STD_LOGIC;
    signal rev_data       : STD_LOGIC_VECTOR(2159 downto 0);
    signal rev_input_valid : STD_LOGIC := '0';
    signal rev_input_data  : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');
    signal rev_shift_current : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');

    signal ctx_pos        : ctx_pos_t   := (others => (others => '0'));
    signal ctx_msg        : ctx_msg_t   := (others => (others => '0'));
    signal ctx_rev_shift  : ctx_shift_t := (others => (others => '0'));
    signal ctx_old_msg    : ctx_data_t  := (others => (others => '0'));
    signal ctx_edge       : ctx_bit_t   := (others => '0');
    signal ctx_wr_ptr     : integer range 0 to 31 := 0;
    signal ctx_rd_ptr     : integer range 0 to 31 := 0;

    signal upd_ctx_pos_d1, upd_ctx_pos_d2, upd_ctx_pos_d3,
           upd_ctx_pos_d4, upd_ctx_pos_d5 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal upd_ctx_msg_d1, upd_ctx_msg_d2, upd_ctx_msg_d3,
           upd_ctx_msg_d4, upd_ctx_msg_d5 : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal upd_ctx_old_d1, upd_ctx_old_d2, upd_ctx_old_d3,
           upd_ctx_old_d4, upd_ctx_old_d5 : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');
    signal upd_ctx_edge_d1, upd_ctx_edge_d2, upd_ctx_edge_d3,
           upd_ctx_edge_d4, upd_ctx_edge_d5 : STD_LOGIC := '0';

    -- The APP update rereads soft_total through RAM port B.  The context below
    -- is delayed one cycle after that synchronous read request.
    signal update_read_fire    : STD_LOGIC := '0';
    signal update_read_pending : STD_LOGIC := '0';
    signal update_pos_pending  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal update_msg_pending  : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal update_old_pending  : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');
    signal update_new_pending  : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');

    signal hard_pos       : integer range 1 to C_MAX_INFO_BLOCKS := 1;
    signal hard_group     : integer range 0 to C_LANE_GROUPS-1 := 0;
    signal hard_start     : STD_LOGIC := '0';
    signal hard_last_fire : STD_LOGIC := '0';
    signal hard_active    : STD_LOGIC := '0';
    signal hard_read_wait : STD_LOGIC := '0';
    signal hard_word_valid: STD_LOGIC := '0';
    signal hard_word      : STD_LOGIC_VECTOR(3959 downto 0) := (others => '0');

    signal checkrsta_busya1,checkrstb_busyb1,checkrsta_busya2,checkrstb_busyb2 :std_logic;
    signal softrsta_busya1,softrstb_busyb1,softrsta_busya2,softrstb_busyb2 :std_logic;
    signal softrsta_busya3,softrstb_busyb3,softrsta_busya4,softrstb_busyb4 :std_logic;

begin

    -- Decode the live configuration while idle, then hold the accepted frame
    -- configuration stable throughout loading, iterations and hard output.
    frame_len_s  <= iv_len  when state = ST_IDLE else len_d1;
    frame_rate_s <= iv_rate when state = ST_IDLE else rate_d1;

    -- One physical write port per RAM.  Frame loading/clearing and decode
    -- updates are mutually exclusive by state, so a simple priority mux is
    -- sufficient and keeps each IP port single-driven.
    soft_ram_we <= '0' when i_rst = '1'
               else soft_load_we or soft_update_we;
    soft_ram_wr_addr <= soft_load_addr when soft_load_we = '1' else soft_update_addr;
    soft_ram_wr_data <= soft_load_data when soft_load_we = '1' else soft_update_data;

    check_ram_we <= '0' when i_rst = '1'
                else check_clear_we or check_update_we;
    check_ram_wr_addr <= check_clear_addr_req when check_clear_we = '1' else check_update_addr;
    check_ram_wr_data <= (others => '0') when check_clear_we = '1' else check_update_data;

    -- Port B is used by the steady-state parameter reader, by the APP update
    -- reread pipeline, and finally by hard-decision output.  These phases do
    -- not overlap in the strict layer schedule.
    soft_ram_rd_addr <= conv_std_logic_vector(hard_pos, soft_ram_rd_addr'length)
        when (hard_active = '1') or (state = ST_HARD_OUT)
        else upd_ctx_pos_d5
        when update_read_fire = '1'
        else soft_read_addr;

    update_read_fire <= '0' when i_rst = '1'
                     else rev_valid and upd_ctx_edge_d5;

    -- i_workflag selected a legacy flooding VNU path.  In the layered APP
    -- formulation the channel LLR is already contained in soft_total_ram, so
    -- that selector is intentionally not part of the arithmetic datapath.

    Inst_ldpc_decode_llr_adjust_8ch : ldpc_decode_llr_adjust_8ch
    PORT MAP(
        i_clk    => i_clk,
        i_rst    => i_rst,
        iv_len   => frame_len_s,
        iv_rate  => frame_rate_s,
        iv_llr   => llr_d1,
        i_llr_en => llr_en_d1,
        ov_blk_k => adj_blk_k,
        ov_blk_n => adj_blk_n,
        ov_llr   => adj_llr,
        o_llr_en => adj_llr_en
    );

    Inst_ldpc_layered_parameter : ldpc_layered_parameter
    PORT MAP(
        i_clk        => i_clk,
        i_rst        => i_rst,
        iv_len       => frame_len_s,
        iv_rate      => frame_rate_s,
        i_start      => p_start,
        i_next_layer => p_next_layer,
        i_advance    => '1',
        o_supported  => p_supported,
        o_done       => p_done,
        o_word_valid => p_word_valid,
        o_row_end    => p_row_end,
        o_edge_valid => p_edge_valid,
        ov_pos       => p_pos,
        ov_msg_addr  => p_msg_addr,
        ov_fwd_shift => p_fwd_shift,
        ov_rev_shift => p_rev_shift
    );

    Inst_soft_total_ram_p1 : soft_total_ram
	PORT MAP (
	    clka => i_clk,
	    wea => (0 => soft_ram_we),
	    addra => soft_ram_wr_addr,
	    rstb => i_rst,
	    dina => soft_ram_wr_data(989 downto 0),
	    rsta_busy => softrsta_busya1,
	    rstb_busy => softrstb_busyb1,
	    clkb => i_clk,
	    addrb => soft_ram_rd_addr,
	    doutb => soft_read_data(989 downto 0)
	);
	  
	Inst_soft_total_ram_p2 : soft_total_ram
	PORT MAP (
	    clka => i_clk,
	    wea => (0 => soft_ram_we),
	    addra => soft_ram_wr_addr,
	    rstb => i_rst,
	    dina => soft_ram_wr_data(1979 downto 990),
	    clkb => i_clk,
	    rsta_busy => softrsta_busya2,
        rstb_busy => softrstb_busyb2,
	    addrb => soft_ram_rd_addr,
	    doutb => soft_read_data(1979 downto 990)
	);
	  
	Inst_soft_total_ram_p3 : soft_total_ram
	PORT MAP (
	    clka => i_clk,
	    wea => (0 => soft_ram_we),
	    addra => soft_ram_wr_addr,
	    rstb => i_rst,
	    dina => soft_ram_wr_data(2969 downto 1980),
	    clkb => i_clk,
	    rsta_busy => softrsta_busya3,
        rstb_busy => softrstb_busyb3,
	    addrb => soft_ram_rd_addr,
	    doutb => soft_read_data(2969 downto 1980)
	);
	  
	Inst_soft_total_ram_p4 : soft_total_ram
	PORT MAP (
	    clka => i_clk,
	    wea => (0 => soft_ram_we),
	    addra => soft_ram_wr_addr,
	    rstb => i_rst,
	    dina => soft_ram_wr_data(3959 downto 2970),
	    clkb => i_clk,
	    rsta_busy => softrsta_busya4,
        rstb_busy => softrstb_busyb4,
	    addrb => soft_ram_rd_addr,
	    doutb => soft_read_data(3959 downto 2970)
	);

    Inst_check_msg_ram_p1 : check_msg_ram
	PORT MAP (
	    clka => i_clk,
	    wea => (0 => check_ram_we),
	    addra => check_ram_wr_addr,
	    rstb => i_rst,
	    dina => check_ram_wr_data(1079 DOWNTO 0),
	    rsta_busy => checkrsta_busya1,
	    rstb_busy => checkrstb_busyb1,
	    clkb => i_clk,
	    addrb => check_read_addr,
	    doutb => check_read_data(1079 DOWNTO 0)
	);

    Inst_check_msg_ram_p2 : check_msg_ram
	PORT MAP (
	    clka => i_clk,
	    wea => (0 => check_ram_we),
	    addra => check_ram_wr_addr,
	    rstb => i_rst,
	    dina => check_ram_wr_data(2159 DOWNTO 1080),
	    clkb => i_clk,
	    rsta_busy => checkrsta_busya2,
	    rstb_busy => checkrstb_busyb2,
	    addrb => check_read_addr,
	    doutb => check_read_data(2159 DOWNTO 1080)
	);

    Inst_fwd_shift : ldpc_layered_barrel_shifter_360
    PORT MAP(
        i_clk    => i_clk,
        i_rst    => i_rst,
        i_valid  => v2c_shift_valid,
        iv_shift => v2c_shift_code,
        iv_data  => v2c_before_shift,
        o_valid  => fwd_valid,
        ov_data  => fwd_data
    );

    Inst_cnu : ldpc_layered_cnu_360
    PORT MAP(
        i_clk          => i_clk,
        i_rst          => i_rst,
        i_slot_valid   => cnu_slot_valid,
        i_edge_valid   => cnu_edge_valid,
        i_dummy        => cnu_dummy,
        i_row_end      => cnu_row_end,
        iv_v2c_chk     => cnu_in_data,
        o_r_valid      => cnu_r_valid,
        o_r_edge_valid => cnu_r_edge,
        ov_r_new_chk   => cnu_r_chk
    );

    Inst_rev_shift : ldpc_layered_barrel_shifter_360
    PORT MAP(
        i_clk    => i_clk,
        i_rst    => i_rst,
        i_valid  => rev_input_valid,
        iv_shift => rev_shift_current,
        iv_data  => rev_input_data,
        o_valid  => rev_valid,
        ov_data  => rev_data
    );

    -- Frame length and input-word configuration are captured synchronously with
    -- the frame start in llr_capture_pro below.

    --------------------------------------------------------------------------
    -- Frame-level control.  Only frame phases use state; layer/iteration
    -- progress is driven by valid/end/writeback events below.
    -- Handshake and event-fire equations remain combinational deliberately;
    -- registering them would move the corresponding accept/start edge by one
    -- clock.  Counters, metadata and datapath values are clocked below.
    --------------------------------------------------------------------------
    s_llr_ready <= '1'
        when (i_rst = '0') and
             (((state = ST_IDLE) and (p_supported = '1')) or
              (state = ST_CAPTURE_LLR))
        else '0';
    o_llr_ready <= s_llr_ready;
    o_busy <= '0' when (i_rst = '1') or (state = ST_IDLE) else '1';

    frame_start_fire <= i_llr_start and s_llr_ready;

    -- llr_accept_fire is the input-transfer qualifier, not another frame-length
    -- counter.  It has three purposes:
    --   1) accept iv_llr only together with i_llr_en and s_llr_ready;
    --   2) allow the first LLR word on the same clock as i_llr_start;
    --   3) block stray i_llr_en pulses before a frame or after the Nth word.
    -- It may be removed only when the upstream guarantees all of the following:
    --   * exactly one configured frame (2025/4050/8100 words) is presented;
    --   * i_llr_en is never asserted outside that frame;
    --   * configuration/start are valid before the first data word; and
    --   * the first data word timing is fixed and handled explicitly.
    -- Under that interface contract, llr_en_d1 may use i_llr_en directly and
    -- the counter/last-word conditions may test i_llr_en directly as well.
    llr_accept_fire <= '1'
        when (i_llr_en = '1') and (s_llr_ready = '1') and
             ((state = ST_CAPTURE_LLR) or (frame_start_fire = '1'))
        else '0';
    last_llr_fire <= '1'
        when (state = ST_CAPTURE_LLR) and
             (llr_accept_fire = '1') and
             (input_word_cnt = input_words_latched - 1)
        else '0';

    p_start <= '1'
        when ((state = ST_WAIT_ADJUST) or (state = ST_LOAD_SOFT)) and
             (soft_load_done = '1') and
             (check_clear_done = '1') and
             (p_supported = '1') and
             (conv_integer(iter_d1) > 0)
        else '1'
        when (iteration_drain_done = '1') and
             ((conv_integer(iter_cnt) + 1) < conv_integer(iter_d1))
        else '0';
    p_next_layer <= layer_drain_done and not iteration_drain_done;

    hard_start <= '1'
        when ((((state = ST_WAIT_ADJUST) or (state = ST_LOAD_SOFT)) and
               (soft_load_done = '1') and
               (check_clear_done = '1') and
               ((p_supported = '0') or (conv_integer(iter_d1) = 0))) or
              (iteration_drain_done = '1' and
               not ((conv_integer(iter_cnt) + 1) < conv_integer(iter_d1))))
        else '0';

    -- Use the pre-edge hard-output condition in the FSM.  Waiting for the
    -- registered completion pulse would keep busy asserted for one extra clock.
    hard_last_fire <= '1'
        when (hard_active = '1') and
             (hard_word_valid = '1') and
             (hard_group = C_LANE_GROUPS - 1) and
             (hard_pos = conv_integer(blk_k_d1))
        else '0';

    state_ctrl_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                state <= ST_IDLE;
            else
                case state is
                    when ST_IDLE =>
                        if frame_start_fire = '1' then
                            state <= ST_CAPTURE_LLR;
                        end if;

                    when ST_CAPTURE_LLR =>
                        if last_llr_fire = '1' then
                            state <= ST_WAIT_ADJUST;
                        end if;

                    when ST_WAIT_ADJUST =>
                        if (soft_load_done = '1') and (check_clear_done = '1') then
                            if (p_supported = '1') and (conv_integer(iter_d1) > 0) then
                                state <= ST_DECODE;
                            else
                                state <= ST_HARD_OUT;
                            end if;
                        elsif adj_llr_en = '1' then
                            state <= ST_LOAD_SOFT;
                        end if;

                    when ST_LOAD_SOFT =>
                        if (soft_load_done = '1') and (check_clear_done = '1') then
                            if (p_supported = '1') and (conv_integer(iter_d1) > 0) then
                                state <= ST_DECODE;
                            else
                                state <= ST_HARD_OUT;
                            end if;
                        end if;

                    when ST_DECODE =>
                        if (iteration_drain_done = '1') and
                           (not ((conv_integer(iter_cnt) + 1) <
                                 conv_integer(iter_d1))) then
                            state <= ST_HARD_OUT;
                        end if;

                    when ST_HARD_OUT =>
                        if hard_last_fire = '1' then
                            state <= ST_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process state_ctrl_pro;

    -- LLR data/configuration are captured only on accepted transfers.  This
    -- prevents i_llr_en activity outside the ready window from entering the
    -- adjust pipeline and keeps iv_iter fixed for the whole frame.
    llr_capture_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                llr_d1              <= (others => '0');
                llr_en_d1           <= '0';
                len_d1              <= (others => '0');
                rate_d1             <= (others => '0');
                iter_d1             <= (others => '0');
                input_words_latched <= 2025;
                blk_n_d1            <= conv_std_logic_vector(45, 8);
                input_word_cnt      <= 0;
            else
                llr_en_d1 <= llr_accept_fire;
                if llr_accept_fire = '1' then
                    llr_d1 <= iv_llr;
                end if;

                if frame_start_fire = '1' then
                    len_d1  <= iv_len;
                    rate_d1 <= iv_rate;
                    iter_d1 <= iv_iter;
                    if iv_len = "00" then
                        input_words_latched <= 8100;
                        blk_n_d1            <= conv_std_logic_vector(180, 8);
                    elsif iv_len = "01" then
                        input_words_latched <= 4050;
                        blk_n_d1            <= conv_std_logic_vector(90, 8);
                    else
                        input_words_latched <= 2025;
                        blk_n_d1            <= conv_std_logic_vector(45, 8);
                    end if;
                    if i_llr_en = '1' then
                        input_word_cnt <= 1;
                    else
                        input_word_cnt <= 0;
                    end if;
                elsif (state = ST_CAPTURE_LLR) and (llr_accept_fire = '1') then
                    if input_word_cnt = input_words_latched - 1 then
                        input_word_cnt <= 0;
                    else
                        input_word_cnt <= input_word_cnt + 1;
                    end if;
                elsif state = ST_IDLE then
                    input_word_cnt <= 0;
                end if;
            end if;
        end if;
    end process llr_capture_pro;

    -- Clear old R messages while the new frame LLRs are being captured.  The
    -- shortest supported frame supplies more cycles than C_MAX_REAL_EDGES.
    check_clear_ctrl_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                check_clear_cnt     <= 0;
                check_clear_we      <= '0';
                check_clear_addr_req <= (others => '0');
                check_clear_done    <= '0';
            elsif state = ST_IDLE then
                check_clear_cnt     <= 0;
                check_clear_we      <= '0';
                check_clear_addr_req <= (others => '0');
                check_clear_done    <= '0';
            elsif (state = ST_CAPTURE_LLR) or
                  (state = ST_WAIT_ADJUST) or
                  (state = ST_LOAD_SOFT) then
                if check_clear_cnt < C_MAX_REAL_EDGES then
                    check_clear_we       <= '1';
                    check_clear_addr_req <= conv_std_logic_vector(
                        check_clear_cnt, check_clear_addr_req'length);
                    check_clear_cnt      <= check_clear_cnt + 1;
                    if check_clear_cnt = C_MAX_REAL_EDGES - 1 then
                        -- The final address is held for the next RAM write
                        -- edge; decode may start on that same edge.
                        check_clear_done <= '1';
                    else
                        check_clear_done <= '0';
                    end if;
                else
                    check_clear_we       <= '0';
                    check_clear_addr_req <= (others => '0');
                    check_clear_done     <= '1';
                end if;
            else
                check_clear_we       <= '0';
                check_clear_addr_req <= (others => '0');
            end if;
        end if;
    end process check_clear_ctrl_pro;

    iteration_count_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                iter_cnt <= (others => '0');
            elsif state = ST_IDLE then
                iter_cnt <= (others => '0');
            elsif iteration_drain_done = '1' then
                iter_cnt <= iter_cnt + conv_std_logic_vector(1, iter_cnt'length);
            end if;
        end if;
    end process iteration_count_pro;

    -- Parameter schedule control.  i_start releases layer 0; every later layer
    -- is released separately after layer_drain_done.  The parameter ROM remains
    -- continuous only inside one layer, so no complete-layer parameter FIFO is
    -- required.
    parameter_ctrl_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                soft_read_addr  <= (others => '0');
                check_read_addr <= (others => '0');
                param_slot_d1  <= '0';
                param_slot_d2  <= '0';
                param_edge_d1  <= '0';
                param_edge_d2  <= '0';
                param_dummy_d1 <= '0';
                param_dummy_d2 <= '0';
                param_end_d1   <= '0';
                param_end_d2   <= '0';
                param_pos_d1   <= (others => '0');
                param_pos_d2   <= (others => '0');
                param_msg_d1   <= (others => '0');
                param_msg_d2   <= (others => '0');
                param_fwd_d1   <= (others => '0');
                param_fwd_d2   <= (others => '0');
                param_rev_d1   <= (others => '0');
                param_rev_d2   <= (others => '0');
            else
                -- Stage 2 metadata aligns with synchronous RAM read data.
                param_slot_d2  <= param_slot_d1;
                param_edge_d2  <= param_edge_d1;
                param_dummy_d2 <= param_dummy_d1;
                param_end_d2   <= param_end_d1;
                param_pos_d2   <= param_pos_d1;
                param_msg_d2   <= param_msg_d1;
                param_fwd_d2   <= param_fwd_d1;
                param_rev_d2   <= param_rev_d1;

                param_pos_d1   <= p_pos;
                param_msg_d1   <= p_msg_addr;
                param_fwd_d1   <= p_fwd_shift;
                param_rev_d1   <= p_rev_shift;

                -- o_dummy is not required at the parameter-module boundary:
                -- a valid non-edge word is exactly the pos=181 CNU bubble.
                if p_word_valid = '1' then
                    param_slot_d1 <= '1';
                    param_end_d1  <= p_row_end;
                    if p_edge_valid = '1' then
                        param_edge_d1  <= '1';
                        param_dummy_d1 <= '0';
                        soft_read_addr  <= p_pos;
                        check_read_addr <= p_msg_addr;
                    else
                        param_edge_d1  <= '0';
                        param_dummy_d1 <= '1';
                    end if;
                else
                    param_slot_d1  <= '0';
                    param_edge_d1  <= '0';
                    param_dummy_d1 <= '0';
                    param_end_d1   <= '0';
                end if;
            end if;
        end if;
    end process parameter_ctrl_pro;

    -- Per-layer drain tracking.  p_row_end marks that all parameter words of
    -- the current layer have arrived; layer_drain_done is asserted only after
    -- the pending real-edge count reaches zero.  p_done additionally marks the
    -- last layer of the iteration.
    pipeline_drain_next_pro : process(
        pending_edge_count, layer_schedule_done_seen,
        iteration_schedule_done_seen, p_word_valid, p_edge_valid,
        p_row_end, p_done, soft_update_we, state)
        variable enqueue_v        : STD_LOGIC;
        variable dequeue_v        : STD_LOGIC;
        variable pending_v        : integer range 0 to C_MAX_LAYER_SLOTS;
        variable layer_seen_v     : STD_LOGIC;
        variable iteration_seen_v : STD_LOGIC;
    begin
        enqueue_v        := p_word_valid and p_edge_valid;
        dequeue_v        := soft_update_we;
        pending_v        := pending_edge_count;
        layer_seen_v     := layer_schedule_done_seen;
        iteration_seen_v := iteration_schedule_done_seen;

        if enqueue_v = '1' and dequeue_v = '0' then
            if pending_v < C_MAX_LAYER_SLOTS then
                pending_v := pending_v + 1;
            end if;
        elsif enqueue_v = '0' and dequeue_v = '1' then
            if pending_v > 0 then
                pending_v := pending_v - 1;
            end if;
        end if;

        if (p_word_valid = '1') and (p_row_end = '1') then
            layer_seen_v := '1';
        end if;
        if p_done = '1' then
            iteration_seen_v := '1';
        end if;

        pending_edge_count_next      <= pending_v;
        layer_schedule_done_next     <= layer_seen_v;
        iteration_schedule_done_next <= iteration_seen_v;
        layer_drain_done             <= '0';
        iteration_drain_done         <= '0';

        -- The post-event pending count allows the next-layer/iteration request
        -- to be sampled on the same edge as the final RAM writeback.
        if (state = ST_DECODE) and
           (layer_seen_v = '1') and
           (pending_v = 0) then
            layer_drain_done <= '1';
            layer_schedule_done_next <= '0';
            if iteration_seen_v = '1' then
                iteration_drain_done <= '1';
                iteration_schedule_done_next <= '0';
            end if;
        end if;
    end process pipeline_drain_next_pro;

    pipeline_drain_reg_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                pending_edge_count <= 0;
                layer_schedule_done_seen <= '0';
                iteration_schedule_done_seen <= '0';
            elsif p_start = '1' then
                pending_edge_count <= 0;
                layer_schedule_done_seen <= '0';
                iteration_schedule_done_seen <= '0';
            else
                pending_edge_count <= pending_edge_count_next;
                layer_schedule_done_seen <= layer_schedule_done_next;
                iteration_schedule_done_seen <= iteration_schedule_done_next;
            end if;
        end if;
    end process pipeline_drain_reg_pro;

    -- Pack adjusted 8-lane LLRs into 360-lane APP words.  Decode writebacks are
    -- generated separately and share the physical RAM port through soft_ram_*.
    soft_total_load_pro : process(i_clk)
        variable load_word_v : STD_LOGIC_VECTOR(3959 downto 0);
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                load_pos       <= 0;
                load_group     <= 0;
                load_word      <= (others => '0');
                soft_load_we   <= '0';
                soft_load_addr <= (others => '0');
                soft_load_data <= (others => '0');
                soft_load_done <= '0';
                blk_k_d1       <= (others => '0');
            else
                if state = ST_IDLE then
                    load_pos       <= 0;
                    load_group     <= 0;
                    load_word      <= (others => '0');
                    soft_load_we   <= '0';
                    soft_load_done <= '0';
                elsif adj_llr_en = '1' then
                    -- Start with the groups accumulated on earlier clocks, then
                    -- insert the current eight sign-extended LLRs immediately.
                    -- A variable is required here so the final group is present
                    -- in soft_load_data on this same clock.
                    load_word_v := load_word;
                    for k in 0 to 7 loop
                        load_word_v(11*(load_group*8+k)+10 downto 11*(load_group*8+k)) :=
                            adj_llr(6*k+5) & adj_llr(6*k+5) & adj_llr(6*k+5) &
                            adj_llr(6*k+5) & adj_llr(6*k+5) &
                            adj_llr(6*k+5 downto 6*k);
                    end loop;

                    if load_group = C_LANE_GROUPS - 1 then
                        soft_load_we   <= '1';
                        soft_load_addr <= conv_std_logic_vector(
                            load_pos + 1, soft_load_addr'length);
                        soft_load_data <= load_word_v;
                        load_group     <= 0;
                        load_word      <= (others => '0');
                        if load_pos = conv_integer(blk_n_d1) - 1 then
                            load_pos       <= 0;
                            blk_k_d1       <= adj_blk_k;
                            soft_load_done <= '1';
                        else
                            load_pos       <= load_pos + 1;
                            soft_load_done <= '0';
                        end if;
                    else
                        load_group     <= load_group + 1;
                        load_word      <= load_word_v;
                        soft_load_we   <= '0';
                        soft_load_done <= '0';
                    end if;
                else
                    soft_load_we   <= '0';
                    soft_load_done <= '0';
                end if;
            end if;
        end if;
    end process soft_total_load_pro;

    -- check-message RAM control.  R_old is cleared for every new frame and is
    -- replaced by R_new after each real-edge CNU result.
    -- check_msg_ram is written through check_ram_* above.  During frame
    -- capture the mux writes zeros; during decode it writes R_new.

    -- Hard-decision output is separated from the global state machine.  The
    -- final data beat and o_frame_done are asserted in the same clock.
    decode_code_out_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                o_data          <= (others => '0');
                o_data_en       <= '0';
                o_frame_done    <= '0';
                hard_pos        <= 1;
                hard_group      <= 0;
                hard_active     <= '0';
                hard_read_wait  <= '0';
                hard_word_valid <= '0';
                hard_word       <= (others => '0');
            else
                o_data_en    <= '0';
                o_frame_done <= '0';

                if hard_start = '1' then
                    hard_pos        <= 1;
                    hard_group      <= 0;
                    hard_active     <= '1';
                    hard_read_wait  <= '0';
                    hard_word_valid <= '0';
                elsif hard_active = '1' then
                    if hard_word_valid = '0' then
                        if hard_read_wait = '0' then
                            -- soft_ram_rd_addr already selects hard_pos; wait
                            -- one full clock for the synchronous RAM output.
                            hard_read_wait <= '1';
                        else
                            hard_word       <= soft_read_data;
                            hard_word_valid <= '1';
                            hard_read_wait  <= '0';
                        end if;
                    else
                        for k in 0 to 7 loop
                            o_data(7-k) <= hard_word(11*(hard_group*8+k)+10);
                        end loop;
                        o_data_en <= '1';

                        if hard_group = C_LANE_GROUPS - 1 then
                            hard_group      <= 0;
                            hard_word_valid <= '0';
                            hard_read_wait  <= '0';
                            if hard_pos = conv_integer(blk_k_d1) then
                                hard_active  <= '0';
                                o_frame_done <= '1';
                            else
                                hard_pos <= hard_pos + 1;
                            end if;
                        else
                            hard_group <= hard_group + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process decode_code_out_pro;

    -- Read soft_total/check_msg and build CNU input.
    data_update_pro : process(i_clk)
        variable soft_v : STD_LOGIC_VECTOR(3959 downto 0);
        variable old_v  : STD_LOGIC_VECTOR(2159 downto 0);
        variable v2c_11 : STD_LOGIC_VECTOR(10 downto 0);
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                v2c_calc_data    <= (others => '0');
                v2c_calc_valid   <= '0';
                v2c_calc_shift   <= (others => '0');
                v2c_calc_edge    <= '0';
                v2c_calc_dummy   <= '0';
                v2c_calc_row_end <= '0';
                ctx_wr_ptr    <= 0;
            else
                v2c_calc_valid <= '0';
                v2c_calc_edge  <= '0';
                v2c_calc_dummy <= '0';
                v2c_calc_row_end <= '0';

                -- Every one of the 13 ROM slots is presented to the CNU.
                -- parameter weight is low on the final slot, but that slot is
                -- still a real edge unless its pos is the dummy value 181.
                if param_slot_d2 = '1' then
                    if param_dummy_d2 = '1' then
                        for i in 0 to C_Z-1 loop
                            v2c_calc_data(6*i+5 downto 6*i) <= "011111";
                        end loop;
                    else
                        soft_v := soft_read_data;
                        old_v  := check_read_data;
                        for i in 0 to C_Z-1 loop
                            -- 6 bit old_check_msg sign-extends to 11 bit by wiring.
                            v2c_11 := soft_v(11*i+10 downto 11*i) -
                                   (old_v(6*i+5) & old_v(6*i+5) & old_v(6*i+5) &
                                    old_v(6*i+5) & old_v(6*i+5) &
                                    old_v(6*i+5 downto 6*i));

                            -- Valid 6 bit range is +0..+31 or -31..-1.
                            -- -32 and all wider overflows are deliberately mapped
                            -- to -31; positive overflow is mapped to +30, matching
                            -- the existing decoder's fixed-point behavior.
                            if v2c_11(10 downto 5) = "000000" or
                               (v2c_11(10 downto 5) = "111111" and v2c_11(4 downto 0) /= "00000") then
                                v2c_calc_data(6*i+5 downto 6*i) <= v2c_11(5 downto 0);
                            elsif v2c_11(10) = '0' then
                                v2c_calc_data(6*i+5 downto 6*i) <= "011110"; -- +30
                            else
                                v2c_calc_data(6*i+5 downto 6*i) <= "100001"; -- -31
                            end if;
                        end loop;

                        -- Context is written only for real edges.
                        ctx_pos(ctx_wr_ptr)       <= param_pos_d2;
                        ctx_msg(ctx_wr_ptr)       <= param_msg_d2;
                        ctx_rev_shift(ctx_wr_ptr) <= param_rev_d2;
                        ctx_old_msg(ctx_wr_ptr)   <= old_v;
                        ctx_edge(ctx_wr_ptr)      <= '1';
                        if ctx_wr_ptr = 31 then
                            ctx_wr_ptr <= 0;
                        else
                            ctx_wr_ptr <= ctx_wr_ptr + 1;
                        end if;
                    end if;
                    v2c_calc_shift   <= param_fwd_d2;
                    v2c_calc_valid   <= '1';
                    v2c_calc_edge    <= param_edge_d2;
                    v2c_calc_dummy   <= param_dummy_d2;
                    v2c_calc_row_end <= param_end_d2;
                end if;
            end if;
        end if;
    end process data_update_pro;

    -- Drive layered CNU.  Row-end is delayed to match the forward shifter latency.
    cnu_ctrl_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                cnu_slot_valid <= '0';
                cnu_edge_valid <= '0';
                cnu_dummy      <= '0';
                cnu_row_end    <= '0';
                cnu_in_data    <= (others => '0');
            else
                cnu_slot_valid <= fwd_valid;
                cnu_edge_valid <= edge_d5;
                cnu_dummy      <= dummy_d5;
                cnu_row_end    <= row_end_d5;
                cnu_in_data    <= fwd_data;
            end if;
        end if;
    end process cnu_ctrl_pro;

    -- Pop context for each real CNU output and feed reverse shift.
    barrel_shifter_ctrl_pro : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                ctx_rd_ptr       <= 0;
                v2c_before_shift <= (others => '0');
                v2c_shift_valid  <= '0';
                v2c_shift_code   <= (others => '0');
                row_end_d1 <= '0';
                row_end_d2 <= '0';
                row_end_d3 <= '0';
                row_end_d4 <= '0';
                row_end_d5 <= '0';
                edge_d1 <= '0';
                edge_d2 <= '0';
                edge_d3 <= '0';
                edge_d4 <= '0';
                edge_d5 <= '0';
                dummy_d1 <= '0';
                dummy_d2 <= '0';
                dummy_d3 <= '0';
                dummy_d4 <= '0';
                dummy_d5 <= '0';
                rev_input_valid  <= '0';
                rev_input_data   <= (others => '0');
                rev_shift_current <= (others => '0');
                upd_ctx_pos_d1   <= (others => '0');
                upd_ctx_pos_d2   <= (others => '0');
                upd_ctx_pos_d3   <= (others => '0');
                upd_ctx_pos_d4   <= (others => '0');
                upd_ctx_pos_d5   <= (others => '0');
                upd_ctx_msg_d1   <= (others => '0');
                upd_ctx_msg_d2   <= (others => '0');
                upd_ctx_msg_d3   <= (others => '0');
                upd_ctx_msg_d4   <= (others => '0');
                upd_ctx_msg_d5   <= (others => '0');
                upd_ctx_old_d1   <= (others => '0');
                upd_ctx_old_d2   <= (others => '0');
                upd_ctx_old_d3   <= (others => '0');
                upd_ctx_old_d4   <= (others => '0');
                upd_ctx_old_d5   <= (others => '0');
                upd_ctx_edge_d1  <= '0';
                upd_ctx_edge_d2  <= '0';
                upd_ctx_edge_d3  <= '0';
                upd_ctx_edge_d4  <= '0';
                upd_ctx_edge_d5  <= '0';
            else
                -- Forward-shifter input control.
                v2c_before_shift <= v2c_calc_data;
                v2c_shift_valid  <= v2c_calc_valid;
                v2c_shift_code   <= v2c_calc_shift;
                row_end_d1 <= v2c_calc_valid and v2c_calc_row_end;
                row_end_d2 <= row_end_d1;
                row_end_d3 <= row_end_d2;
                row_end_d4 <= row_end_d3;
                row_end_d5 <= row_end_d4;
                edge_d1 <= v2c_calc_valid and v2c_calc_edge;
                edge_d2 <= edge_d1;
                edge_d3 <= edge_d2;
                edge_d4 <= edge_d3;
                edge_d5 <= edge_d4;
                dummy_d1 <= v2c_calc_valid and v2c_calc_dummy;
                dummy_d2 <= dummy_d1;
                dummy_d3 <= dummy_d2;
                dummy_d4 <= dummy_d3;
                dummy_d5 <= dummy_d4;

                -- Reverse-shifter input control.
                rev_input_valid <= '0';
                upd_ctx_pos_d1  <= (others => '0');
                upd_ctx_msg_d1  <= (others => '0');
                upd_ctx_old_d1  <= (others => '0');
                upd_ctx_edge_d1 <= '0';

                upd_ctx_pos_d2  <= upd_ctx_pos_d1;
                upd_ctx_msg_d2  <= upd_ctx_msg_d1;
                upd_ctx_old_d2  <= upd_ctx_old_d1;
                upd_ctx_edge_d2 <= upd_ctx_edge_d1;

                upd_ctx_pos_d3  <= upd_ctx_pos_d2;
                upd_ctx_msg_d3  <= upd_ctx_msg_d2;
                upd_ctx_old_d3  <= upd_ctx_old_d2;
                upd_ctx_edge_d3 <= upd_ctx_edge_d2;

                upd_ctx_pos_d4  <= upd_ctx_pos_d3;
                upd_ctx_msg_d4  <= upd_ctx_msg_d3;
                upd_ctx_old_d4  <= upd_ctx_old_d3;
                upd_ctx_edge_d4 <= upd_ctx_edge_d3;

                upd_ctx_pos_d5  <= upd_ctx_pos_d4;
                upd_ctx_msg_d5  <= upd_ctx_msg_d4;
                upd_ctx_old_d5  <= upd_ctx_old_d4;
                upd_ctx_edge_d5 <= upd_ctx_edge_d4;

                if cnu_r_valid = '1' and cnu_r_edge = '1' then
                    -- Register data, valid and shift together.  The reverse
                    -- shifter therefore receives a fully aligned input one clock later.
                    rev_input_valid  <= '1';
                    rev_input_data   <= cnu_r_chk;
                    rev_shift_current <= ctx_rev_shift(ctx_rd_ptr);
                    upd_ctx_pos_d1  <= ctx_pos(ctx_rd_ptr);
                    upd_ctx_msg_d1  <= ctx_msg(ctx_rd_ptr);
                    upd_ctx_old_d1  <= ctx_old_msg(ctx_rd_ptr);
                    upd_ctx_edge_d1 <= ctx_edge(ctx_rd_ptr);
                    if ctx_rd_ptr = 31 then
                        ctx_rd_ptr <= 0;
                    else
                        ctx_rd_ptr <= ctx_rd_ptr + 1;
                    end if;
                end if;
            end if;
        end if;
    end process barrel_shifter_ctrl_pro;

    -- Update soft_total_ram and check_msg_ram:
    --   soft_total(pos) += new_check_msg - old_check_msg
    --   check_msg(msg_addr) = new_check_msg
    soft_total_update_calc_pro : process(i_clk)
        variable soft_v : STD_LOGIC_VECTOR(3959 downto 0);
        variable upd11  : STD_LOGIC_VECTOR(10 downto 0);
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                soft_update_we    <= '0';
                soft_update_addr  <= (others => '0');
                soft_update_data  <= (others => '0');
                check_update_we   <= '0';
                check_update_addr <= (others => '0');
                check_update_data <= (others => '0');
                update_read_pending <= '0';
                update_pos_pending  <= (others => '0');
                update_msg_pending  <= (others => '0');
                update_old_pending  <= (others => '0');
                update_new_pending  <= (others => '0');
            else
                soft_update_we  <= '0';
                check_update_we <= '0';

                -- RAM port B sampled update_read_fire/address on the previous
                -- edge; soft_read_data is therefore valid for this pending
                -- context now.  Consecutive same-pos writes use forwarding.
                if update_read_pending = '1' then
                    if soft_update_we = '1' and
                       soft_update_addr = update_pos_pending then
                        soft_v := soft_update_data;
                    else
                        soft_v := soft_read_data;
                    end if;
                    for i in 0 to C_Z-1 loop
                        upd11 := soft_v(11*i+10 downto 11*i)
                               + (update_new_pending(6*i+5) & update_new_pending(6*i+5) &
                                  update_new_pending(6*i+5) & update_new_pending(6*i+5) &
                                  update_new_pending(6*i+5) &
                                  update_new_pending(6*i+5 downto 6*i))
                               - (update_old_pending(6*i+5) & update_old_pending(6*i+5) &
                                  update_old_pending(6*i+5) & update_old_pending(6*i+5) &
                                  update_old_pending(6*i+5) &
                                  update_old_pending(6*i+5 downto 6*i));
                        soft_v(11*i+10 downto 11*i) := upd11;
                    end loop;
                    soft_update_addr  <= update_pos_pending;
                    soft_update_data  <= soft_v;
                    soft_update_we    <= '1';
                    check_update_addr <= update_msg_pending;
                    check_update_data <= update_new_pending;
                    check_update_we   <= '1';
                end if;

                update_read_pending <= update_read_fire;
                if update_read_fire = '1' then
                    update_pos_pending <= upd_ctx_pos_d5;
                    update_msg_pending <= upd_ctx_msg_d5;
                    update_old_pending <= upd_ctx_old_d5;
                    update_new_pending <= rev_data;
                end if;
            end if;
        end if;
    end process soft_total_update_calc_pro;

end Behavioral;

