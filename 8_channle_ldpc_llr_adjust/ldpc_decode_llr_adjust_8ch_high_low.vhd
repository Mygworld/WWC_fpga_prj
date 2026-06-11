----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    2026-05-23 Wangweichen
-- Design Name: 
-- Module Name:    LLR_Adjust - Behavioral (Register Array Transpose)
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:    DVB-S2/S2X LLR Interleaver utilizing 1D Ping-Pong Register Array
--                 to perform 48-bit to 48-bit Matrix Transposition.
--                 iv_rate:Map DVB iv_modcod to LDPC coderate inside new_dvb_rx_demodcod_message module
--
-- Revision 0.02 - Split single-cycle timing (ping/pong_reg rd to ram_dina) into 2-stage pipeline 
-- Revision 0.03 - Split 1120-depth large array into two 560-depth arrays,cut giant MUX long route 
-- All above edits reduce reg-to-RAM path delay
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity ldpc_decode_llr_adjust is
    Port ( i_clk    : in  STD_LOGIC;
           i_rst    : in  STD_LOGIC;
           iv_len   : in  STD_LOGIC_VECTOR (1 downto 0);     -- normal/medium/short
           iv_rate  : in  STD_LOGIC_VECTOR (5 downto 0);     -- 24 + 3 + 7(zai na ge mokuai zhuanhuan)
           iv_llr   : in  STD_LOGIC_VECTOR (47 downto 0);    -- 8-ch L(pi) input
           i_llr_en : in  STD_LOGIC;
           ov_blk_k : out STD_LOGIC_VECTOR (7 downto 0);  
           ov_blk_n : out STD_LOGIC_VECTOR (7 downto 0);  
           ov_llr   : out STD_LOGIC_VECTOR (47 downto 0);    -- 8-ch adjusted out 
           o_llr_en : out STD_LOGIC);
end ldpc_decode_llr_adjust;

architecture Behavioral of ldpc_decode_llr_adjust is
    --------------------------------------------------------------------
    -- Unified Single RAM Component (Depth 8192, Addr 13-bit)
    --------------------------------------------------------------------
    -- info bits wr directly,check bits register-adjusted then wr to matching addr
    COMPONENT ldpc_decode_llr_adjust_ram
      PORT (
        clka      : IN STD_LOGIC;
        wea       : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra     : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
        dina      : IN STD_LOGIC_VECTOR(47 DOWNTO 0); -- 8-ch input
        rstb      : IN STD_LOGIC;
        clkb      : IN STD_LOGIC;
        rsta_busy : OUT STD_LOGIC;
        rstb_busy : OUT STD_LOGIC;
        addrb     : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
        doutb     : OUT STD_LOGIC_VECTOR(47 DOWNTO 0) -- 8-ch adjusted output
      );
    END COMPONENT;

    -- I/O buffer reg
    signal llr_d1   : std_logic_vector(47 downto 0);
    signal llr_en_d1 : std_logic;
    --------------------------------------------------------------------
    -- DVB-S2/S2X Parameters
    --------------------------------------------------------------------
    signal Blk_K    : std_logic_vector(7 downto 0);       
    signal Blk_N    : std_logic_vector(7 downto 0);  
    signal LEN_N    : std_logic_vector(12 downto 0); -- max = 8099(13bits)
    signal INFO_LEN : std_logic_vector(12 downto 0); -- max = 64800*9/10 /8 = 7290(13bits)

    -- Q Multiplier Pre-calculation (Pure Combinational)
    signal q_val : std_logic_vector(8 downto 0);
    signal q_ext : std_logic_vector(10 downto 0);
    signal q_x1, q_x2, q_x3, q_x4, q_x5, q_x6, q_x7 : std_logic_vector(10 downto 0); -- max = 140*8=1120(11bits)

    --------------------------------------------------------------------
    -- 1D Ping-Pong Register Array Definition
    --------------------------------------------------------------------
    -- 140 (max q) * 8 = 1120. We use 1120 reg for 8-byte alignment.
    -- Spatial slice arr: split depth 1120/2, cut giant MUX long route
    type reg_arr_half_t is array(0 to 559) of std_logic_vector(5 downto 0);
    
    signal ping_reg_low  : reg_arr_half_t := (others => (others => '0'));
    signal ping_reg_high : reg_arr_half_t := (others => (others => '0'));
    signal pong_reg_low  : reg_arr_half_t := (others => (others => '0'));
    signal pong_reg_high : reg_arr_half_t := (others => (others => '0'));

    --------------------------------------------------------------------
    -- Control Signals
    --------------------------------------------------------------------
    -- Reg Control Signals(Process 1)
    signal llr_in_cnt   : std_logic_vector(12 downto 0);
    signal parity_q_cnt : std_logic_vector(8 downto 0);
    signal parity_j_cnt : std_logic_vector(5 downto 0);
    signal pp_arr_wr    : std_logic; 

    -- RAM Write Control Signals(Process 2)
    signal tx_running   : std_logic;
    signal tx_arr_sel   : std_logic;
    signal tx_m_cnt     : std_logic_vector(8 downto 0);
    signal tx_m_offset  : std_logic_vector(12 downto 0); -- Accumulator for M * 45
    signal tx_j_cnt     : std_logic_vector(5 downto 0);

    signal addra        : std_logic_vector(12 downto 0);
    signal ram_wea      : std_logic_vector(0 downto 0);
    signal ram_addra    : std_logic_vector(12 downto 0);
    signal ram_dina     : std_logic_vector(47 downto 0);
    signal frame_ready  : std_logic;

    -- Pipelineing control delay
    signal tx_run_d1      : std_logic;
    signal tx_sel_d1      : std_logic;
    signal frame_ready_d1 : std_logic;
    -- 8 addr reg of Pipelineing for ram_dina
    type raddr_arr_t is array(0 to 7) of integer range 0 to 1119;
    signal raddr_d1 : raddr_arr_t := (others => 0);

    -- RAM Read Control Signals(Process 3)
    signal rd_cnt       : std_logic_vector(12 downto 0);
    signal rd_en        : std_logic;
    signal ram_addrb    : std_logic_vector(12 downto 0);
    signal ram_doutb    : std_logic_vector(47 DOWNTO 0);
    signal rsta_busy,rstb_busy : std_logic;
    signal rd_en_d1,rd_en_d2   : std_logic;
    
begin
    llr_adjust_ram : ldpc_decode_llr_adjust_ram
	  PORT MAP (
		 clka      => i_clk,
		 wea       => ram_wea,
		 addra     => ram_addra,
		 dina      => ram_dina,
		 rstb      => i_rst,
		 clkb      => i_clk,      
		 rsta_busy => rsta_busy,      
         rstb_busy => rstb_busy,
		 addrb     => ram_addrb,
		 doutb     => ram_doutb
	  );

    -- ==================================================================
    -- Parameter Computations 
    -- ==================================================================
    q_multi_calu_pro:process(i_clk)
    begin
        if(i_clk'event and i_clk = '1')then
            if (i_rst = '1') then
                INFO_LEN  <= (others => '0');
                llr_d1    <= (others => '0');     -- I/O Input Pipelineing
                llr_en_d1 <= '0';
                q_val <=  (others => '0');
                q_ext <=  (others => '0');
                q_x1  <=  (others => '0'); 
                q_x2  <=  (others => '0'); 
                q_x3  <=  (others => '0');
                q_x4  <=  (others => '0'); 
                q_x5  <=  (others => '0'); 
                q_x6  <=  (others => '0'); 
                q_x7  <=  (others => '0');
            else
                -- Calculate K multiplied by 45
                -- Example: 90*45= 4050
                INFO_LEN  <= (Blk_K & "00000") + ("00" & Blk_K & "000") + ("000" & Blk_K & "00") + ("00000" & Blk_K); 
                llr_d1    <= iv_llr;
                llr_en_d1 <= i_llr_en;

                q_val <= ("0" & Blk_N) - ("0" & Blk_K);
                q_ext <= "00" & q_val;

                q_x1 <= q_ext;
                q_x2 <= q_ext(9 downto 0) & "0";
                q_x3 <= (q_ext(9 downto 0) & "0") + q_ext;
                q_x4 <= q_ext(8 downto 0) & "00";
                q_x5 <= (q_ext(8 downto 0) & "00")  + q_ext;
                q_x6 <= (q_ext(8 downto 0) & "00")  + (q_ext(9 downto 0) & "0");
                q_x7 <= (q_ext(7 downto 0) & "000") - q_ext;
            end if;
        end if;
    end process;

    -- ==================================================================
    -- reg control:Rx checkbits and parity
    -- ==================================================================
    reg_ctrl_pro : process(i_clk)
        variable base_wr : integer range 0 to 1119;
    begin
        if (i_clk'event and i_clk = '1') then
            if (i_rst = '1') then
                llr_in_cnt   <= (others => '0');
                parity_q_cnt <= (others => '0');
                parity_j_cnt <= (others => '0');
                pp_arr_wr    <= '0';
                tx_running   <= '0';
                tx_arr_sel   <= '0';
                tx_j_cnt     <= (others => '0');
            else
                -- Clear tx_running after Tx proc completes chunk moving,for 360 parallelism
                if (llr_en_d1 = '1') and (llr_in_cnt >= INFO_LEN) and (parity_q_cnt = q_val - 1) then
                    tx_running <= '1';
                elsif (tx_running = '1' and tx_m_cnt = q_val - 1) then
                    tx_running <= '0';
                end if;

                if (llr_en_d1 = '1') and (llr_in_cnt >= INFO_LEN) then
                    -- checkbits
                    base_wr := conv_integer(parity_q_cnt(7 downto 0) & "000");
                    if (pp_arr_wr = '0') then
                        if (base_wr < 560) then 
                            for i in 0 to 7 loop
                                ping_reg_low(base_wr+i) <= llr_d1(i*6+5 downto i*6);
                            end loop;
                        else
                            for i in 0 to 7 loop
                                ping_reg_high(base_wr-560+i) <= llr_d1(i*6+5 downto i*6);
                            end loop;
                        end if;
                    else
                        if (base_wr < 560) then 
                            for i in 0 to 7 loop
                                pong_reg_low(base_wr+i) <= llr_d1(i*6+5 downto i*6);
                            end loop;
                        else
                            for i in 0 to 7 loop
                                pong_reg_high(base_wr-560+i) <= llr_d1(i*6+5 downto i*6);
                            end loop;
                        end if;
                    end if;
                    -- if (base_wr < 560) then 
                    --     for i in 0 to 7 loop
                    --         if (pp_arr_wr = '0') then
                    --             ping_reg_low(base_wr+i) <= llr_d1(i*6+5 downto i*6);
                    --         else
                    --             pong_reg_low(base_wr+i) <= llr_d1(i*6+5 downto i*6);
                    --         end if;
                    --     end loop;
                    -- else
                    --     for i in 0 to 7 loop
                    --         if (pp_arr_wr = '0') then
                    --             ping_reg_high(base_wr-560+i) <= llr_d1(i*6+5 downto i*6);
                    --         else
                    --             pong_reg_high(base_wr-560+i) <= llr_d1(i*6+5 downto i*6);
                    --         end if;
                    --     end loop;
                    -- end if;

                    -- parity_q_cnt:* 8 for ping reg/pong reg base_wr_addr
                    -- when count up to q-1, trigger RAM write start(tx_running), ping-pong reg switch & increment parity_j_cnt
                    -- tx_j_cnt delays parity_j_cnt after one reg group wr, for ram addr accumulation(<-> reg row change)
                    if (parity_q_cnt = q_val - 1) then
                        parity_q_cnt <= (others => '0');
                        tx_arr_sel <= pp_arr_wr;
                        tx_j_cnt   <= parity_j_cnt;
                        
                        pp_arr_wr <= not pp_arr_wr;
                        
                        if parity_j_cnt = 44 then
                            parity_j_cnt <= (others => '0');
                        else
                            parity_j_cnt <= parity_j_cnt + 1;
                        end if;
                    else
                        parity_q_cnt <= parity_q_cnt + 1;
                    end if;
                end if;

                    -- llr input global cnt (0 to LEN_N) for infobits write to ram &
                if (llr_en_d1 = '1') then
                    if (llr_in_cnt = LEN_N) then
                        llr_in_cnt <= (others => '0');
                    else
                        llr_in_cnt <= llr_in_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- ==================================================================
    -- ram wr control: infobits directly write,checkbits read from changed reg addr and write to changed ram addr
    -- ==================================================================
    ram_write_pro : process(i_clk)
    begin
        if (i_clk'event and i_clk = '1') then
            if (i_rst = '1') then
                ram_wea  <= (others => '0');
                tx_m_cnt <= (others => '0');
                tx_m_offset <= (others => '0');
                frame_ready <= '0';	
                tx_run_d1   <= '0';
                tx_sel_d1   <= '0';
                frame_ready_d1 <= '0';
            else
                -- Pipelineing control delay
                tx_run_d1 <= tx_running;
                tx_sel_d1 <= tx_arr_sel;
                frame_ready_d1 <= frame_ready;

                -- ram write finish flag for ram rd
                if (tx_running = '1') and (tx_m_cnt = q_val - 1) and (tx_j_cnt = 44) then
                    frame_ready <= '1';
                else
                    frame_ready <= '0';
                end if;

                -- use Pipelineing rd ping_reg and wr ram
                -- Reg data transpose read
                if (tx_running = '1') then
                    -- Calc scatter addr: (INFO_LEN+1)=parity base addr
                    -- tx_m_offset replaces tx_m_cnt*45 multiply,tx_m_cnt++ → RAM addr+45(360/8), reg col-wise wr
                    -- tx_j_cnt++ → RAM addr+1, inc after full col reg wr for next group,
                    addra <= INFO_LEN + tx_m_offset + ("0000000" & tx_j_cnt);

                    -- Interleaved rd 8 LLR from reg
                    -- tx_m_cnt: reg col; q_x: reg row, 8 rows per RAM data, ping-pong toggle per 8 rows
                    -- tx_arr_sel controls ping-pong switch
                    raddr_d1(0) <= conv_integer(tx_m_cnt);
                    raddr_d1(1) <= conv_integer(("00" & tx_m_cnt) + q_x1);
                    raddr_d1(2) <= conv_integer(("00" & tx_m_cnt) + q_x2);
                    raddr_d1(3) <= conv_integer(("00" & tx_m_cnt) + q_x3);
                    raddr_d1(4) <= conv_integer(("00" & tx_m_cnt) + q_x4);
                    raddr_d1(5) <= conv_integer(("00" & tx_m_cnt) + q_x5);
                    raddr_d1(6) <= conv_integer(("00" & tx_m_cnt) + q_x6);
                    raddr_d1(7) <= conv_integer(("00" & tx_m_cnt) + q_x7);

                    -- FSM transition & accumulator inc
                    if (tx_m_cnt = q_val - 1) then
                        tx_m_cnt <= (others => '0');
                        tx_m_offset <= (others => '0'); -- Reset accum at chunk end
                    else
                        tx_m_cnt <= tx_m_cnt + 1;
                        tx_m_offset <= tx_m_offset + 45; -- Add 45 per cycle
                    end if;
                end if;

                -- write to RAM(Parity Scatter)
                if (tx_run_d1 = '1') then
                    ram_wea <= "1";
                    ram_addra <= addra;
                    -- 
                    for i in 0 to 7 loop
                        if tx_sel_d1 = '0' then -- Ping
                            if (raddr_d1(i) < 560) then
                                ram_dina(i*6+5 downto i*6) <= ping_reg_low(raddr_d1(i));
                            else
                                ram_dina(i*6+5 downto i*6) <= ping_reg_high(raddr_d1(i) - 560);
                            end if;
                        else                    -- Pong
                            if (raddr_d1(i) < 560) then
                                ram_dina(i*6+5 downto i*6) <= pong_reg_low(raddr_d1(i));
                            else
                                ram_dina(i*6+5 downto i*6) <= pong_reg_high(raddr_d1(i) - 560);
                            end if;
                        end if;
                    end loop;
                -- Infobits directly write to ram(addr sequential increment)
                elsif (llr_en_d1 = '1' and llr_in_cnt < INFO_LEN) then
                    ram_wea     <= "1";
                    ram_addra   <= llr_in_cnt;
                    ram_dina    <= llr_d1;
                else
                    ram_wea     <= "0";
                end if;
            end if;
        end if;
    end process;
    -- ==================================================================
    -- ram rd control: Seq rd RAM addr after frame_ready assert,output llr_adjusted
    -- ==================================================================
    ram_read_pro : process(i_clk)
    begin
        if (i_clk'event and i_clk = '1') then
            if (i_rst = '1') then
                rd_en     <= '0';
                rd_en_d1  <= '0';
                rd_en_d2  <= '0';
                rd_cnt    <= (others => '0');
                ram_addrb <= (others => '0');
                ov_llr    <= (others => '0');
                o_llr_en  <= '0';
            else
                -- delay for ram read and out
                rd_en_d1 <= rd_en;
                rd_en_d2 <= rd_en_d1;
                o_llr_en <= rd_en_d2;

                if (frame_ready_d1 = '1') then
                    rd_en <= '1';
                    rd_cnt <= (others => '0');
                    ram_addrb <= (others => '0');
                elsif (rd_en = '1') then
                    if (rd_cnt < LEN_N) then
                        rd_cnt <= rd_cnt + 1;
                        ram_addrb <= ram_addrb + 1;
                    else
                        rd_en <= '0';
                    end if;
                end if;

                if (rd_en_d2 = '1') then
                    ov_llr   <= ram_doutb;
                end if;
            end if;
        end if;
    end process;

    -- =========================================================
    -- DVB-S2 Parameter Process (Omitted for brevity, use existing)
    -- =========================================================
    ldpc_parameter : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				Blk_K <= (others => '0');				
				Blk_N <= (others => '0');			
				LEN_N <= (others => '0');	
				ov_blk_k  <= (others => '0');				
				ov_blk_n  <= (others => '1');			
			else
				-- if (i_llr_start = '1') then
				if(iv_len = "00")then
					Blk_N <= "10110100";--180
					LEN_N <= "1111110100011";--8099
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
					Blk_N <= "01011010";--90
					LEN_N <= "0111111010001";--4049
					case iv_rate is
						when "000000" => Blk_K <= conv_std_logic_vector(18,8);--1/5
						when "000001" => Blk_K <= conv_std_logic_vector(22,8);--11/45
						when "000010" => Blk_K <= conv_std_logic_vector(30,8);--1/3
						when others => Blk_K <= (others => '0');
					end case;
				else
					Blk_N <= "00101101";--45
					LEN_N <= "0011111101000";--2024
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
		-- end if;
    end process;

end Behavioral;