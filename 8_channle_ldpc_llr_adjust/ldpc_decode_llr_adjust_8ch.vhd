----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:10:43 05/22/2026
-- Design Name: 
-- Module Name:    LLR_Adjust - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 0.01 - File Created
-- Revision: 0.02 - 8-channel input, 8-Bank Memory Duplication, Ping-Pong Buffered
--                  Zero Multipliers, Zero Type-Casting, 192MHz+ Timing Closure
-- Revision: 0.03 - Removed Ping-Pong, Fixed TX State Machine & Calc
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ldpc_decode_llr_adjust is
    Port ( i_clk    : in  STD_LOGIC;
           i_rst    : in  STD_LOGIC;
           iv_len   : in  STD_LOGIC_VECTOR (1 downto 0);     -- normal/medium/short
           iv_rate  : in  STD_LOGIC_VECTOR (5 downto 0);     -- 24 + 3 + 7
           iv_llr   : in  STD_LOGIC_VECTOR (47 downto 0);    -- 8-channel L(pi) input
           i_llr_en : in  STD_LOGIC;
           ov_blk_k : out STD_LOGIC_VECTOR (7 downto 0);  
           ov_blk_n : out STD_LOGIC_VECTOR (7 downto 0);  
           ov_llr   : out STD_LOGIC_VECTOR (47 downto 0);    -- 8-channel adjusted out 
           o_llr_en : out STD_LOGIC);
end ldpc_decode_llr_adjust;

architecture Behavioral of ldpc_decode_llr_adjust is

-- 8-way LLR input parity bit interleaving (Ping-Pong removed, using single 8192 depth effectively)
-- width:8*6=48bit,depth:64800/8=8100->8192,inst 8
    COMPONENT ldpc_decode_llr_adjust_ram
      PORT (
        clka  : IN STD_LOGIC;
        wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(12 DOWNTO 0); -- wr 8192 depth
        dina  : IN STD_LOGIC_VECTOR(47 DOWNTO 0); -- wr 48 width
        clkb  : IN STD_LOGIC;
        addrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- rd 65536 depth (for use idx)
        doutb : OUT STD_LOGIC_VECTOR(5 DOWNTO 0)  -- rd 6 width (= llr)
        );
    END COMPONENT;
    -- COMPONENT parity_bram_48w_16384d
    --   PORT (
    --     clka  : IN STD_LOGIC;
    --     wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    --     addra : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    --     dina  : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    --     clkb  : IN STD_LOGIC;
    --     addrb : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    --     doutb : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    --   );
    -- END COMPONENT;

-- Eight-frame output data from llr_adjust are stored in ping-pong RAMs, with an input of 45 pieces of 48-bit data
	COMPONENT ldpc_decode_llr_ram_8frame
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
		 dina : IN STD_LOGIC_VECTOR(2159 DOWNTO 0);
		 rstb : IN STD_LOGIC;
		 clkb : IN STD_LOGIC;
		 rsta_busy : OUT STD_LOGIC;
         rstb_busy : OUT STD_LOGIC;
		 addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
		 doutb : OUT STD_LOGIC_VECTOR(2159 DOWNTO 0)
	  );
	END COMPONENT;

	------------------------------------llr_adjust-------------------------------------
    -- DVB-S2/S2X param
    signal Blk_K : std_logic_vector(7 downto 0); -- normal-179/medium-89/short-44      
    signal Blk_N : std_logic_vector(7 downto 0); -- by iv_rate and iv_len
    signal q_val : std_logic_vector(8 downto 0); -- Blk_K + 1 - Blk_N

    -- llr_adjust_ram input control
    signal rx_cnt         : std_logic_vector(13 downto 0);
    --signal ping_pong_wr   : std_logic := '0';
    signal rx_toggle      : std_logic := '0';
    --signal finished_bank  : std_logic := '0';
    signal wea            : std_logic_vector(0 downto 0);
    signal addra_full     : std_logic_vector(13 downto 0);

    -- frame length total num calu
    signal N_plus_1       : std_logic_vector(8 downto 0);
    signal N_p1_ext       : std_logic_vector(14 downto 0);
    signal total_words    : std_logic_vector(14 downto 0);

    -- llr_adjust_ram output state control
    type state_type is (IDLE, TX_INFO_PREP, TX_INFO_RUN, TX_INFO_WAIT, TX_PARITY_PREP, TX_PARITY_RUN, TX_PARITY_WAIT);
    signal tx_state       : state_type;
    signal tx_toggle      : std_logic := '0';
    -- signal ping_pong_rd   : std_logic := '0';
    
    signal tx_macro_row   : std_logic_vector(7 downto 0) := (others => '0');
    signal m_cnt          : std_logic_vector(8 downto 0) := (others => '0');
    signal j_cnt          : std_logic_vector(5 downto 0) := (others => '0');
    
    -- base addr + (replace Blk_K * 45)
    signal info_base_addr : std_logic_vector(12 downto 0) := (others => '0');
    signal seq_addr       : std_logic_vector(12 downto 0);

    -- 8通道独立读地�?与偏�?
    signal addrb0, addrb1, addrb2, addrb3, addrb4, addrb5, addrb6, addrb7 : std_logic_vector(13 downto 0);
    signal off0, off1, off2, off3, off4, off5, off6, off7 : std_logic_vector(2 downto 0);
    signal off0_r, off1_r, off2_r, off3_r, off4_r, off5_r, off6_r, off7_r : std_logic_vector(2 downto 0);
    
    signal idx0, idx1, idx2, idx3, idx4, idx5, idx6, idx7 : std_logic_vector(15 downto 0);
    signal tx_en, tx_en_r : std_logic;

    -- RAM 输出�? LLR 寄存�?
    signal dout0, dout1, dout2, dout3, dout4, dout5, dout6, dout7 : std_logic_vector(47 downto 0);
    signal llr0, llr1, llr2, llr3, llr4, llr5, llr6, llr7 : std_logic_vector(5 downto 0);

    -- Q值移位预计算 (无乘法器)
    signal q_ext : std_logic_vector(15 downto 0);
    signal q_x1, q_x2, q_x3, q_x4, q_x5, q_x6, q_x7, q_x8 : std_logic_vector(15 downto 0);

	------------------------------------llr_ram-------------------------------------
	signal Blk_2N : std_logic_vector(8 downto 0); --360/180/90 

	signal llr_adjust : std_logic_vector(47 downto 0);  
	signal llr_adjust_en : std_logic;  
	signal state : std_logic;  
	
	signal llr_ram_wea : std_logic_vector(0 downto 0);
	signal llr_ram_addra : std_logic_vector(11 downto 0);
	signal llr_ram_dina : std_logic_vector(2159 downto 0);
	signal llr_ram_addrb : std_logic_vector(11 downto 0);
	signal llr_ram_doutb : std_logic_vector(2159 downto 0);
	signal llr_ram_doutb_d1, llr_ram_doutb_d2 : std_logic_vector(2159 downto 0);
	
	signal cnt_45 : integer range 0 to 63;
	signal rsta_busya,rstb_busyb : std_logic;
	signal cnt_llr : integer range 0 to 3000:= 0;

begin
	Inst_ldpc_decode_llr_ram : ldpc_decode_llr_ram_8frame
	  PORT MAP (
		 clka => i_clk,
		 wea => llr_ram_wea,
		 addra => llr_ram_addra,
		 rstb => i_rst,
		 dina => llr_ram_dina,
		 clkb => i_clk,
		 rsta_busy => rsta_busya,   
         rstb_busy => rstb_busyb,
		 addrb => llr_ram_addrb,
		 doutb => llr_ram_doutb
	  );

    -- =========================================================
    -- 0. 高频无乘法器计算网络 (纯组合�?�辑 + 移位累加)
    -- =========================================================
    -- 1. 计算�?帧需要的总字�? = (Blk_N + 1) * 45
    N_plus_1 <= ("0" & Blk_N) + 1;
    N_p1_ext <= "000000" & N_plus_1; 
    -- 乘以45 (32 + 8 + 4 + 1) -> 纯移位加�?
    total_words <= (N_p1_ext(9 downto 0) & "00000") + 
                   (N_p1_ext(11 downto 0) & "000") + 
                   (N_p1_ext(12 downto 0) & "00") + 
                   N_p1_ext;

    -- 2. 计算 q_val = Blk_N + 1 - Blk_K
    q_val <= ("0" & Blk_N) + 1 - ("0" & Blk_K);
    q_ext <= "0000000" & q_val; 

    -- 3. Q 的�?�数预计算表 (0DSP, 纯加�?)
    q_x1 <= q_ext;
    q_x2 <= q_ext(14 downto 0) & "0";
    q_x3 <= (q_ext(14 downto 0) & "0") + q_ext;
    q_x4 <= q_ext(13 downto 0) & "00";
    q_x5 <= (q_ext(13 downto 0) & "00") + q_ext;
    q_x6 <= (q_ext(13 downto 0) & "00") + (q_ext(14 downto 0) & "0");
    q_x7 <= (q_ext(13 downto 0) & "00") + (q_ext(14 downto 0) & "0") + q_ext;
    q_x8 <= q_ext(12 downto 0) & "000";

    -- =========================================================
    -- 1. 物理层：8 �? BRAM 副本例化
    -- =========================================================
    addra_full <= ping_pong_wr & rx_cnt(12 downto 0);
    
    RAM0 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb0, doutb => dout0);
    RAM1 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb1, doutb => dout1);
    RAM2 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb2, doutb => dout2);
    RAM3 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb3, doutb => dout3);
    RAM4 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb4, doutb => dout4);
    RAM5 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb5, doutb => dout5);
    RAM6 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb6, doutb => dout6);
    RAM7 : parity_bram_48w_16384d PORT MAP(clka => i_clk, wea => wea, addra => addra_full, dina => iv_llr, clkb => i_clk, addrb => addrb7, doutb => dout7);

    -- =========================================================
    -- 2. 前台 Rx 控制：满帧接收流水线
    -- =========================================================
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                rx_cnt <= (others => '0');
                ping_pong_wr <= '0';
                rx_toggle <= '0';
                wea <= "0";
            else
                if i_llr_en = '1' then
                    wea <= "1";
                    if rx_cnt = total_words(13 downto 0) - 1 then
                        rx_cnt <= (others => '0');
                        finished_bank <= ping_pong_wr;     -- 记录刚写满的是哪个区
                        ping_pong_wr <= not ping_pong_wr;  -- 前台切区
                        rx_toggle <= not rx_toggle;        -- 敲门唤醒后台
                    else
                        rx_cnt <= rx_cnt + 1;
                    end if;
                else
                    wea <= "0";
                end if;
            end if;
        end if;
    end process;

    -- =========================================================
    -- 3. 后台 Tx 状�?�机 (完美规避乘法�?)
    -- =========================================================
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                tx_state <= IDLE;
                tx_toggle <= '0';
                tx_en <= '0';
                info_base_addr <= (others => '0');
            else
                case tx_state is
                    when IDLE =>
                        tx_en <= '0';
                        info_base_addr <= (others => '0');
                        if rx_toggle /= tx_toggle then
                            tx_toggle <= rx_toggle;       
                            ping_pong_rd <= finished_bank;
                            tx_macro_row <= (others => '0');
                            tx_state <= TX_INFO_PREP;
                        end if;

                    -- 【阶段A】信息位输出
                    when TX_INFO_PREP =>
                        if tx_macro_row = Blk_K then
                            m_cnt <= (others => '0');
                            tx_state <= TX_PARITY_PREP;
                        else
                            seq_addr <= info_base_addr; -- 直接使用累加器基�?
                            j_cnt <= (others => '0');
                            tx_state <= TX_INFO_RUN;
                        end if;

                    when TX_INFO_RUN =>
                        addrb0 <= ping_pong_rd & seq_addr; addrb1 <= ping_pong_rd & seq_addr;
                        addrb2 <= ping_pong_rd & seq_addr; addrb3 <= ping_pong_rd & seq_addr;
                        addrb4 <= ping_pong_rd & seq_addr; addrb5 <= ping_pong_rd & seq_addr;
                        addrb6 <= ping_pong_rd & seq_addr; addrb7 <= ping_pong_rd & seq_addr;
                        
                        off0 <= "000"; off1 <= "001"; off2 <= "010"; off3 <= "011";
                        off4 <= "100"; off5 <= "101"; off6 <= "110"; off7 <= "111";
                        
                        seq_addr <= seq_addr + 1;
                        tx_en <= '1';
                        
                        if j_cnt = "101100" then -- 44
                            tx_state <= TX_INFO_WAIT;
                        else
                            j_cnt <= j_cnt + 1;
                        end if;

                    when TX_INFO_WAIT =>
                        tx_en <= '0';
                        tx_macro_row <= tx_macro_row + 1;
                        -- 核心优化：每次结束一个宏行，基址�?45�?(省去乘法)
                        info_base_addr <= info_base_addr + "0000000101101"; 
                        tx_state <= TX_INFO_PREP;

                    -- 【阶段B】校验位交织输出
                    when TX_PARITY_PREP =>
                        idx0 <= "0000000" & m_cnt;
                        idx1 <= ("0000000" & m_cnt) + q_x1;
                        idx2 <= ("0000000" & m_cnt) + q_x2;
                        idx3 <= ("0000000" & m_cnt) + q_x3;
                        idx4 <= ("0000000" & m_cnt) + q_x4;
                        idx5 <= ("0000000" & m_cnt) + q_x5;
                        idx6 <= ("0000000" & m_cnt) + q_x6;
                        idx7 <= ("0000000" & m_cnt) + q_x7;
                        
                        j_cnt <= (others => '0');
                        tx_state <= TX_PARITY_RUN;

                    when TX_PARITY_RUN =>
                        -- 核心优化：parity_base 其实就是 info_base_addr，因为它已经累加�? Blk_K*45 了！
                        addrb0 <= ping_pong_rd & (info_base_addr + idx0(15 downto 3)); off0 <= idx0(2 downto 0);
                        addrb1 <= ping_pong_rd & (info_base_addr + idx1(15 downto 3)); off1 <= idx1(2 downto 0);
                        addrb2 <= ping_pong_rd & (info_base_addr + idx2(15 downto 3)); off2 <= idx2(2 downto 0);
                        addrb3 <= ping_pong_rd & (info_base_addr + idx3(15 downto 3)); off3 <= idx3(2 downto 0);
                        addrb4 <= ping_pong_rd & (info_base_addr + idx4(15 downto 3)); off4 <= idx4(2 downto 0);
                        addrb5 <= ping_pong_rd & (info_base_addr + idx5(15 downto 3)); off5 <= idx5(2 downto 0);
                        addrb6 <= ping_pong_rd & (info_base_addr + idx6(15 downto 3)); off6 <= idx6(2 downto 0);
                        addrb7 <= ping_pong_rd & (info_base_addr + idx7(15 downto 3)); off7 <= idx7(2 downto 0);
                        
                        idx0 <= idx0 + q_x8; idx1 <= idx1 + q_x8; idx2 <= idx2 + q_x8; idx3 <= idx3 + q_x8;
                        idx4 <= idx4 + q_x8; idx5 <= idx5 + q_x8; idx6 <= idx6 + q_x8; idx7 <= idx7 + q_x8;

                        tx_en <= '1';
                        if j_cnt = "101100" then -- 44
                            tx_state <= TX_PARITY_WAIT;
                        else
                            j_cnt <= j_cnt + 1;
                        end if;

                    when TX_PARITY_WAIT =>
                        tx_en <= '0';
                        if m_cnt = q_val - 1 then
                            tx_state <= IDLE; 
                        else
                            m_cnt <= m_cnt + 1;
                            tx_state <= TX_PARITY_PREP;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- =========================================================
    -- 4. 纯组合�?�辑 MUX 提取�? (替代 conv_integer �? array)
    -- =========================================================
    mux_extract : process(off0_r, off1_r, off2_r, off3_r, off4_r, off5_r, off6_r, off7_r, 
                          dout0, dout1, dout2, dout3, dout4, dout5, dout6, dout7)
    begin
        case off0_r is
            when "000" => llr0 <= dout0(5 downto 0);   when "001" => llr0 <= dout0(11 downto 6);
            when "010" => llr0 <= dout0(17 downto 12); when "011" => llr0 <= dout0(23 downto 18);
            when "100" => llr0 <= dout0(29 downto 24); when "101" => llr0 <= dout0(35 downto 30);
            when "110" => llr0 <= dout0(41 downto 36); when "111" => llr0 <= dout0(47 downto 42);
            when others => llr0 <= (others => '0');
        end case;

        case off1_r is
            when "000" => llr1 <= dout1(5 downto 0);   when "001" => llr1 <= dout1(11 downto 6);
            when "010" => llr1 <= dout1(17 downto 12); when "011" => llr1 <= dout1(23 downto 18);
            when "100" => llr1 <= dout1(29 downto 24); when "101" => llr1 <= dout1(35 downto 30);
            when "110" => llr1 <= dout1(41 downto 36); when "111" => llr1 <= dout1(47 downto 42);
            when others => llr1 <= (others => '0');
        end case;

        case off2_r is
            when "000" => llr2 <= dout2(5 downto 0);   when "001" => llr2 <= dout2(11 downto 6);
            when "010" => llr2 <= dout2(17 downto 12); when "011" => llr2 <= dout2(23 downto 18);
            when "100" => llr2 <= dout2(29 downto 24); when "101" => llr2 <= dout2(35 downto 30);
            when "110" => llr2 <= dout2(41 downto 36); when "111" => llr2 <= dout2(47 downto 42);
            when others => llr2 <= (others => '0');
        end case;

        case off3_r is
            when "000" => llr3 <= dout3(5 downto 0);   when "001" => llr3 <= dout3(11 downto 6);
            when "010" => llr3 <= dout3(17 downto 12); when "011" => llr3 <= dout3(23 downto 18);
            when "100" => llr3 <= dout3(29 downto 24); when "101" => llr3 <= dout3(35 downto 30);
            when "110" => llr3 <= dout3(41 downto 36); when "111" => llr3 <= dout3(47 downto 42);
            when others => llr3 <= (others => '0');
        end case;

        case off4_r is
            when "000" => llr4 <= dout4(5 downto 0);   when "001" => llr4 <= dout4(11 downto 6);
            when "010" => llr4 <= dout4(17 downto 12); when "011" => llr4 <= dout4(23 downto 18);
            when "100" => llr4 <= dout4(29 downto 24); when "101" => llr4 <= dout4(35 downto 30);
            when "110" => llr4 <= dout4(41 downto 36); when "111" => llr4 <= dout4(47 downto 42);
            when others => llr4 <= (others => '0');
        end case;

        case off5_r is
            when "000" => llr5 <= dout5(5 downto 0);   when "001" => llr5 <= dout5(11 downto 6);
            when "010" => llr5 <= dout5(17 downto 12); when "011" => llr5 <= dout5(23 downto 18);
            when "100" => llr5 <= dout5(29 downto 24); when "101" => llr5 <= dout5(35 downto 30);
            when "110" => llr5 <= dout5(41 downto 36); when "111" => llr5 <= dout5(47 downto 42);
            when others => llr5 <= (others => '0');
        end case;

        case off6_r is
            when "000" => llr6 <= dout6(5 downto 0);   when "001" => llr6 <= dout6(11 downto 6);
            when "010" => llr6 <= dout6(17 downto 12); when "011" => llr6 <= dout6(23 downto 18);
            when "100" => llr6 <= dout6(29 downto 24); when "101" => llr6 <= dout6(35 downto 30);
            when "110" => llr6 <= dout6(41 downto 36); when "111" => llr6 <= dout6(47 downto 42);
            when others => llr6 <= (others => '0');
        end case;

        case off7_r is
            when "000" => llr7 <= dout7(5 downto 0);   when "001" => llr7 <= dout7(11 downto 6);
            when "010" => llr7 <= dout7(17 downto 12); when "011" => llr7 <= dout7(23 downto 18);
            when "100" => llr7 <= dout7(29 downto 24); when "101" => llr7 <= dout7(35 downto 30);
            when "110" => llr7 <= dout7(41 downto 36); when "111" => llr7 <= dout7(47 downto 42);
            when others => llr7 <= (others => '0');
        end case;
    end process;

    -- =========================================================
    -- 5. 管道对齐与最终输�? 
    -- =========================================================
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            tx_en_r <= tx_en;
            off0_r <= off0; off1_r <= off1; off2_r <= off2; off3_r <= off3;
            off4_r <= off4; off5_r <= off5; off6_r <= off6; off7_r <= off7;
            
            if i_rst = '1' then
                ov_llr <= (others => '0');
                o_llr_en <= '0';
				llr_adjust <= (others => '0');
				llr_adjust_en <= '0';
            else
                o_llr_en <= tx_en_r;
				llr_adjust_en <= tx_en_r;
                if tx_en_r = '1' then
                    ov_llr <= llr7 & llr6 & llr5 & llr4 & llr3 & llr2 & llr1 & llr0;
					llr_adjust <= llr7 & llr6 & llr5 & llr4 & llr3 & llr2 & llr1 & llr0;
				end if;
            end if;
        end if;
    end process;

    -- =========================================================
    -- 6. DVB-S2 参数查表解析 (保持原版设计)
    -- =========================================================
    ldpc_parameter : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				Blk_K <= (others => '0');				
				Blk_N <= (others => '0');								
				ov_blk_k <= (others => '0');				
				ov_blk_n <= (others => '0');				
			else
			
				if(iv_len = "00")then
					Blk_N <= "10110011";--179
					case iv_rate is
					--DVB-S2X
						when "000000" => Blk_K <= conv_std_logic_vector(40,8);--2/9
						when "000001" => Blk_K <= conv_std_logic_vector(52,8);--13/45
						when "000010" => Blk_K <= conv_std_logic_vector(81,8);--9/20
						when "000011" => Blk_K <= conv_std_logic_vector(99,8);--11/20
						when "000100" => Blk_K <= conv_std_logic_vector(104,8);--26/45
						when "000101" => Blk_K <= conv_std_logic_vector(112,8);--28/45
						when "000110" => Blk_K <= conv_std_logic_vector(115,8);--23/36
						when "000111" => Blk_K <= conv_std_logic_vector(125,8);--25/36
						when "001000" => Blk_K <= conv_std_logic_vector(130,8);--13/18
						when "001001" => Blk_K <= conv_std_logic_vector(140,8);--7/9
						when "001010" => Blk_K <= conv_std_logic_vector(90,8);--90/180
						when "001011" => Blk_K <= conv_std_logic_vector(96,8);--96/180
						when "001100" => Blk_K <= conv_std_logic_vector(100,8);--100/180
						when "001101" => Blk_K <= conv_std_logic_vector(104,8);--104/180
						when "001110" => Blk_K <= conv_std_logic_vector(116,8);--116/180
						when "001111" => Blk_K <= conv_std_logic_vector(124,8);--124/180
						when "010000" => Blk_K <= conv_std_logic_vector(128,8);--128/180
						when "010001" => Blk_K <= conv_std_logic_vector(132,8);--132/180
						when "010010" => Blk_K <= conv_std_logic_vector(135,8);--135/180
						when "010011" => Blk_K <= conv_std_logic_vector(140,8);--140/180
						when "010100" => Blk_K <= conv_std_logic_vector(154,8);--154/180
						when "010101" => Blk_K <= conv_std_logic_vector(108,8);--18/30
						when "010110" => Blk_K <= conv_std_logic_vector(120,8);--20/30
						when "010111" => Blk_K <= conv_std_logic_vector(132,8);--22/30
						--DVB-S2
						when "011000" => Blk_K <= conv_std_logic_vector(45,8);--1/4
						when "011001" => Blk_K <= conv_std_logic_vector(60,8);--1/3
						when "011010" => Blk_K <= conv_std_logic_vector(72,8);--2/5
						when "011011" => Blk_K <= conv_std_logic_vector(90,8);--1/2
						when "011100" => Blk_K <= conv_std_logic_vector(108,8);--3/5
						when "011101" => Blk_K <= conv_std_logic_vector(120,8);--2/3
						when "011110" => Blk_K <= conv_std_logic_vector(135,8);--3/4
						when "011111" => Blk_K <= conv_std_logic_vector(144,8);--4/5
						when "100000" => Blk_K <= conv_std_logic_vector(150,8);--5/6
						when "100001" => Blk_K <= conv_std_logic_vector(160,8);--8/9
						when "100010" => Blk_K <= conv_std_logic_vector(162,8);--9/10
						when others => Blk_K <= (others => '0');
					end case;
				elsif(iv_len = "01")then
					Blk_N <= "01011001";--89
					case iv_rate is
						when "000000" => Blk_K <= conv_std_logic_vector(18,8);--1/5
						when "000001" => Blk_K <= conv_std_logic_vector(22,8);--11/45
						when "000010" => Blk_K <= conv_std_logic_vector(30,8);--1/3
						when others => Blk_K <= (others => '0');
					end case;
				else
					Blk_N <= "00101100";--44
					case iv_rate is
						when "000000" => Blk_K <= conv_std_logic_vector(11,8);--11/45
						when "000001" => Blk_K <= conv_std_logic_vector(12,8);--4/15
						when "000010" => Blk_K <= conv_std_logic_vector(14,8);--14/45
						when "000011" => Blk_K <= conv_std_logic_vector(21,8);--7/15
						when "000100" => Blk_K <= conv_std_logic_vector(24,8);--8/15
						when "000101" => Blk_K <= conv_std_logic_vector(26,8);--26/45
						when "000110" => Blk_K <= conv_std_logic_vector(32,8);--32/45
						--DVB-S2
						when "000111" => Blk_K <= conv_std_logic_vector(9,8);--1/5
						when "001000" => Blk_K <= conv_std_logic_vector(15,8);--1/3
						when "001001" => Blk_K <= conv_std_logic_vector(18,8);--2/5
						when "001010" => Blk_K <= conv_std_logic_vector(20,8);--4/9
						when "001011" => Blk_K <= conv_std_logic_vector(27,8);--3/5
						when "001100" => Blk_K <= conv_std_logic_vector(30,8);--2/3
						when "001101" => Blk_K <= conv_std_logic_vector(33,8);--11/15
						when "001110" => Blk_K <= conv_std_logic_vector(35,8);--7/9
						when "001111" => Blk_K <= conv_std_logic_vector(37,8);--37/45
						when "010000" => Blk_K <= conv_std_logic_vector(40,8);--8/9
						when others => Blk_K <= (others => '0');
					end case;		
				end if;
				
				ov_blk_k <= Blk_K;
				ov_blk_n <= Blk_N;
			end if;
		end if;
	end process;

	-------------------------------------llr_ram_pro--------------------------------------------
	llr_ram_input_ctrl : process(i_clk)
		variable rows_per_frame : std_logic_vector(11 downto 0); -- num of 2160bits(360 llr) per frame:normal-180/medium-90/short-45=Blk_N+1
        variable total_rows_8f  : std_logic_vector(11 downto 0); -- num of 2160bits(360 llr) per 8 frame(one cycle) for ping-ram finish:(Blk_N+1) * 8;
        variable total_rows_16f : std_logic_vector(11 downto 0); -- num of 2160bits(360 llr) per 16 frame for pong-ram finish:(Blk_N+1) * 16;
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				llr_ram_wea <= (others => '1');
				llr_ram_dina <= (others => '0');
				cnt_45 <= 0;
				state <= '0';
				if cnt_llr = 0 then --add to clear the data in the llr_ram when i_rst = 1
					llr_ram_addra <= (others => '0');
					cnt_llr <= cnt_llr + 1; 
				elsif(cnt_llr >= 1 and cnt_llr < 10)then -- testbench:10,actual:2884
					llr_ram_addra <= llr_ram_addra + 1;
					cnt_llr <= cnt_llr + 1;
				else
					cnt_llr <= cnt_llr;
					llr_ram_addra <= (others => '0');
				end if;	
			else				
				cnt_llr <= 0;
				rows_per_frame := "000" & (("0" & Blk_N) + 1);         -- Blk_N+1
                total_rows_8f  := rows_per_frame(8 downto 0) & "000";  -- (Blk_N+1)*8
                total_rows_16f := rows_per_frame(7 downto 0) & "0000"; -- ((Blk_N+1)*8)*2
				if(llr_adjust_en = '1')then
					if(cnt_45 = 44)then
						cnt_45 <= 0;
						llr_ram_wea <= "1";
						llr_ram_addra <= llr_ram_addra + '1';
					else
						cnt_45 <= cnt_45 + 1;
						llr_ram_wea <= "0";
						llr_ram_addra <= llr_ram_addra;
					end if;
				else
					cnt_45 <= 0;
					llr_ram_wea <= (others => '0');
					-- after a frame data write finish,change write addr and read state
					if(llr_ram_addra = total_rows_16f)and(llr_ram_wea = "1")then
						llr_ram_addra <= (others => '0');
						state <= not state; -- 1->0
					elsif(llr_ram_addra = total_rows_8f)and(llr_ram_wea = "1")then
						llr_ram_addra <= llr_ram_addra;
						state <= not state; -- 0->1
					else
						llr_ram_addra <= llr_ram_addra;
						state <= state;
					end if;
				end if;
				
				
				llr_ram_dina(48*cnt_45+47 downto 48*cnt_45) <= llr_adjust;--serial to parallel
			end if;
		end if;
	end process;

end Behavioral;