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
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

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

    --------------------------------------------------------------------
    -- DVB-S2/S2X Parameters
    --------------------------------------------------------------------
    signal Blk_K    : std_logic_vector(7 downto 0);       
    signal Blk_N    : std_logic_vector(7 downto 0);  
    signal LEN_N    : std_logic_vector(12 downto 0); -- max = 8099(13bits)
    signal INFO_LEN : std_logic_vector(12 downto 0); -- max = 64800*9/10 /8 = 7290(13bits)

    -- Q Multiplier Pre-calculation (Pure Combinational)
    signal q_val : std_logic_vector(8 downto 0);

    --------------------------------------------------------------------
    -- 2D Ping-Pong Register Bank Definition (8 Banks * 140 depth * 6-bit,q_max:140)
    --------------------------------------------------------------------
    -- 定义一个 140 深度的子数组
    type sub_arr_t is array(0 to 139) of std_logic_vector(5 downto 0);
    -- 定义包含 8 个子数组的 Bank 阵列
    type bank_arr_t is array(0 to 7) of sub_arr_t;
    
    signal ping_bank : bank_arr_t;
    signal pong_bank : bank_arr_t;

    -- 维持当前写入位置的状态信号
    signal wr_arr_idx  : integer range 0 to 7 := 0;
    signal wr_loc_addr : integer range 0 to 255 := 0;

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

    signal ram_wea      : std_logic_vector(0 downto 0);
    signal ram_addra    : std_logic_vector(12 downto 0);
    signal ram_dina     : std_logic_vector(47 downto 0);
    signal frame_ready  : std_logic;

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
                q_val <=  (others => '0');
            else
                -- Calculate K multiplied by 45
                -- Example: 90*45 - 1 = 4049
                INFO_LEN <= (Blk_K & "00000") + ("00" & Blk_K & "000") + ("000" & Blk_K & "00") + ("00000" & Blk_K) - 1; 
                
                q_val <= ("0" & Blk_N) - ("0" & Blk_K);
            end if;
        end if;
    end process;

    -- ==================================================================
    -- reg control:Rx checkbits and parity
    -- ==================================================================
    reg_ctrl_pro : process(i_clk)
        -- 局部变量用于并行计算，不跨拍
        variable v_q_val       : integer range 0 to 511;
        variable v_temp_addr   : integer range 0 to 511;
        variable v_target_bank : integer range 0 to 15;
        variable v_target_loc  : integer range 0 to 255;
        variable v_next_addr   : integer range 0 to 511;
    begin
        if (i_clk'event and i_clk = '1') then
            if (i_rst = '1') then
                ping_bank <= (others => (others => (others => '0')));
                pong_bank <= (others => (others => (others => '0')));
                wr_arr_idx   <= 0;
                wr_loc_addr  <= 0;
                llr_in_cnt   <= (others => '0');
                parity_q_cnt <= (others => '0');
                parity_j_cnt <= (others => '0');
                pp_arr_wr    <= '0';
                tx_running   <= '0';
                tx_arr_sel   <= '0';
                tx_j_cnt     <= (others => '0');
            else
                -- Clear tx_running after Tx proc completes chunk moving,for 360 parallelism
                -- 【优化点 1】: 将 tx_running 的置1和清0整合进一个独立的、互斥的 if-elsif 结构中。
                -- 先判断置1（优先级高，防止被同时到达的清0条件覆盖），再判断清0。
                if (i_llr_en = '1') and (llr_in_cnt > INFO_LEN) and (parity_q_cnt = q_val - 1) then
                    tx_running <= '1';
                elsif (tx_running = '1' and tx_m_cnt = q_val - 1) then
                    tx_running <= '0';
                end if;

                if (i_llr_en = '1') then
                    -- checkbits
                    if (llr_in_cnt > INFO_LEN) then
                        -- 为了方便数学运算，将 std_logic_vector 转换为 integer
                        v_q_val := conv_integer(q_val);
                        
                        -- =========================================================
                        -- 第一部分：并行数据分发（8条路同时算，没有任何依赖）
                        -- =========================================================
                        for i in 0 to 7 loop
                            -- 每一个数据独立计算它距离起点的绝对偏移
                            v_temp_addr := wr_loc_addr + i;

                            if v_temp_addr < v_q_val then
                                -- 情况 A：没有越界，落在当前 Bank
                                v_target_bank := wr_arr_idx;
                                v_target_loc  := v_temp_addr;
                                
                            elsif v_temp_addr < (v_q_val * 2) then
                                -- 情况 B：越过了 1 次边界，落在下一个 Bank
                                -- 直接在分支内处理环形折叠，保证绝对互斥
                                if (wr_arr_idx + 1 >= 8) then
                                    v_target_bank := wr_arr_idx + 1 - 8;
                                else
                                    v_target_bank := wr_arr_idx + 1;
                                end if;
                                v_target_loc  := v_temp_addr - v_q_val;
                                
                            else
                                -- 情况 C：越过了 2 次边界（仅在 q=5,6,7 时可能发生）
                                if (wr_arr_idx + 2 >= 8) then
                                    v_target_bank := wr_arr_idx + 2 - 8;
                                else
                                    v_target_bank := wr_arr_idx + 2;
                                end if;
                                v_target_loc  := v_temp_addr - (v_q_val * 2);
                            end if;

                            -- 并发写入 D 触发器物理阵列
                            if pp_arr_wr = '0' then
                                ping_bank(v_target_bank)(v_target_loc) <= iv_llr(i*6+5 downto i*6);
                            else
                                pong_bank(v_target_bank)(v_target_loc) <= iv_llr(i*6+5 downto i*6);
                            end if;
                        end loop;

                        -- parity_q_cnt:* 8(= parity_j_cnt) for ping reg/pong reg base_wr_addr
                        -- when count up to q-1, trigger RAM write start(tx_running), ping-pong reg switch & increment parity_j_cnt
                        -- tx_j_cnt delays parity_j_cnt after one reg group wr, for ram addr accumulation(<-> reg row change)
                        -- =========================================================
                        -- 第二部分：状态机与下拍指针更新（全局提前判断 +8）
                        -- =========================================================
                        v_next_addr := wr_loc_addr + 8;

                        if (parity_q_cnt = q_val - 1) then
                            -- Chunk 刚好填满结束，各种计数器复位
                            parity_q_cnt <= (others => '0');
                            tx_arr_sel   <= pp_arr_wr;
                            tx_j_cnt     <= parity_j_cnt;
                            pp_arr_wr    <= not pp_arr_wr;
                            
                            -- 阵列写满，指针硬复位，准备下一轮
                            wr_arr_idx   <= 0;
                            wr_loc_addr  <= 0;

                            if parity_j_cnt = 44 then
                                parity_j_cnt <= (others => '0');
                            else
                                parity_j_cnt <= parity_j_cnt + 1;
                            end if;
                        else
                            parity_q_cnt <= parity_q_cnt + 1;

                            -- 未满，根据提前算出的 v_next_addr 更新下一拍的起点
                            if v_next_addr < v_q_val then
                                wr_arr_idx  <= wr_arr_idx;
                                wr_loc_addr <= v_next_addr;
                                
                            elsif v_next_addr < (v_q_val * 2) then
                                if wr_arr_idx + 1 >= 8 then
                                    wr_arr_idx <= wr_arr_idx + 1 - 8;
                                else
                                    wr_arr_idx <= wr_arr_idx + 1;
                                end if;
                                wr_loc_addr <= v_next_addr - v_q_val;
                                
                            else
                                if wr_arr_idx + 2 >= 8 then
                                    wr_arr_idx <= wr_arr_idx + 2 - 8;
                                else
                                    wr_arr_idx <= wr_arr_idx + 2;
                                end if;
                                wr_loc_addr <= v_next_addr - (v_q_val * 2);
                            end if;
                        end if;
                    end if;

                    -- llr input global cnt (0 to LEN_N) for infobits write to ram &
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
            else
                -- 【优化点 2】: 取消所有开头的默认赋值，利用唯一的 if-elsif-else 互斥树控制 ram_wea, ram_addra 等。

--                -- Infobits directly write to ram(addr sequential increment)
--                if (i_llr_en = '1') and (llr_in_cnt <= INFO_LEN) then
--                    ram_wea   <= "1";
--                    ram_addra <= llr_in_cnt;
--                    ram_dina  <= iv_llr;
--                end if;
                if (tx_running = '1') and (tx_m_cnt = q_val - 1) and (tx_j_cnt = 44) then
                    frame_ready <= '1';
                else
                    frame_ready <= '0';
                end if;

                -- Reg data transpose read & write to RAM(Parity Scatter)
                if (tx_running = '1') then
                    ram_wea <= "1";
                    
                    -- Calc scatter addr: (INFO_LEN+1)=parity base addr
                    -- tx_m_offset replaces tx_m_cnt*45 multiply,tx_m_cnt++ → RAM addr+45(360/8), reg col-wise wr
                    -- tx_j_cnt++ → RAM addr+1, inc after full col reg wr for next group,
                    ram_addra <= (INFO_LEN + 1) + tx_m_offset + ("0000000" & tx_j_cnt);

                    -- Interleaved rd 8 LLR from reg
                    -- tx_m_cnt: reg col; q_x: reg row, 8 rows per RAM data, ping-pong toggle per 8 rows
                    -- tx_arr_sel controls ping-pong switch
                    -- ================================================
                    -- 读逻辑降维打击：全部统一使用 tx_m_cnt 寻址
                    -- 消灭了所有的 q_x 加法树和巨型 MUX！
                    -- ================================================
                    if (tx_arr_sel = '0') then
                        ram_dina <= ping_bank(7)(conv_integer(tx_m_cnt)) & 
                                    ping_bank(6)(conv_integer(tx_m_cnt)) & 
                                    ping_bank(5)(conv_integer(tx_m_cnt)) & 
                                    ping_bank(4)(conv_integer(tx_m_cnt)) & 
                                    ping_bank(3)(conv_integer(tx_m_cnt)) & 
                                    ping_bank(2)(conv_integer(tx_m_cnt)) & 
                                    ping_bank(1)(conv_integer(tx_m_cnt)) & 
                                    ping_bank(0)(conv_integer(tx_m_cnt));
                    else
                        ram_dina <= pong_bank(7)(conv_integer(tx_m_cnt)) & 
                                    pong_bank(6)(conv_integer(tx_m_cnt)) & 
                                    pong_bank(5)(conv_integer(tx_m_cnt)) & 
                                    pong_bank(4)(conv_integer(tx_m_cnt)) & 
                                    pong_bank(3)(conv_integer(tx_m_cnt)) & 
                                    pong_bank(2)(conv_integer(tx_m_cnt)) & 
                                    pong_bank(1)(conv_integer(tx_m_cnt)) & 
                                    pong_bank(0)(conv_integer(tx_m_cnt));
                    end if;

                    -- FSM transition & accumulator inc
                    if (tx_m_cnt = q_val - 1) then
                        tx_m_cnt <= (others => '0');
                        tx_m_offset <= (others => '0'); -- Reset accum at chunk end
                    else
                        tx_m_cnt <= tx_m_cnt + 1;
                        tx_m_offset <= tx_m_offset + 45; -- Add 45 per cycle
                    end if;
                    
                -- 分支 2: 处理信息位直通（前台进程）
                elsif (i_llr_en = '1') and (llr_in_cnt <= INFO_LEN) then
                    ram_wea     <= "1";
                    ram_addra   <= llr_in_cnt;
                    ram_dina    <= iv_llr;
                    -- tx_m_cnt / tx_m_offset 保持历史值

                -- 分支 3: 空闲状态
                else
                    ram_wea     <= "0";
                    -- 保持 ram_addra / ram_dina / tx_m_cnt 等信号的原状态不变以节约翻转功耗
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

                if (frame_ready = '1') then
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
                    ov_llr <= ram_doutb;
                else
                    ov_llr <= (others => '0');
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
				ov_blk_k <= (others => '0');				
				ov_blk_n <= (others => '1');				
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