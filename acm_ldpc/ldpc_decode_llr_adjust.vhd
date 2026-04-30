----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:10:43 06/20/2015 
-- Design Name: 
-- Module Name:    LLR_Adjust - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ldpc_decode_llr_adjust is
    Port ( i_clk : in  STD_LOGIC;
           i_rst : in  STD_LOGIC;
           iv_len : in  STD_LOGIC_VECTOR (1 downto 0);
           iv_rate : in  STD_LOGIC_VECTOR (5 downto 0);
           iv_llr : in  STD_LOGIC_VECTOR (5 downto 0);
           i_llr_en : in  STD_LOGIC;
		   i_llr_start : in  STD_LOGIC;
           ov_blk_k : out  STD_LOGIC_VECTOR (7 downto 0);
           ov_blk_n : out  STD_LOGIC_VECTOR (7 downto 0);
           ov_llr : out  STD_LOGIC_VECTOR (5 downto 0);
           o_llr_en : out  STD_LOGIC);
end ldpc_decode_llr_adjust;

architecture Behavioral of ldpc_decode_llr_adjust is

	COMPONENT ldpc_decode_llr_adjust_ram
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		 rsta : IN STD_LOGIC;
		 rsta_busy : OUT STD_LOGIC;
		 dina : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
		 douta : OUT STD_LOGIC_VECTOR(5 DOWNTO 0)
	  );
	END COMPONENT;


	signal llr_d1, llr_d2 : std_logic_vector(5 downto 0);
	
	signal wea1, wea2 : std_logic_vector(0 downto 0);
	signal addra1, addra2 : std_logic_vector(15 downto 0);
	signal dina1, dina2 : std_logic_vector(5 downto 0);
	signal douta1, douta2 : std_logic_vector(5 downto 0);
	signal state : std_logic;
	signal state_d1, state_d2 : std_logic;
	signal rd_en, rd_en_d1, rd_en_d2 : std_logic;
	
	signal Blk_K : std_logic_vector(7 downto 0);  	
	signal Blk_N : std_logic_vector(7 downto 0);  
	signal LEN_N : std_logic_vector(15 downto 0);	
	signal LEN_N_d1 : std_logic_vector(15 downto 0);	
	
	signal cnt_360 : std_logic_vector(8 downto 0);	
	signal cnt_180 : std_logic_vector(7 downto 0); 
	signal cnt_64800 : std_logic_vector(15 downto 0); 

	signal addra_p1 : std_logic_vector(15 downto 0);	
	signal addra_p2 : std_logic_vector(15 downto 0);	
	signal addra : std_logic_vector(15 downto 0);	
	
	signal rsta_busy1,rsta_busy2 :std_logic;
	
begin

	llr_adjust_ram1 : ldpc_decode_llr_adjust_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => wea1,
		 addra => addra1,
		 rsta_busy => rsta_busy1,
		 rsta => i_rst,
		 dina => dina1,
		 douta => douta1
	  );
	llr_adjust_ram2 : ldpc_decode_llr_adjust_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => wea2,
		 addra => addra2,
		 rsta_busy => rsta_busy2,
		 rsta => i_rst,
		 dina => dina2,
		 douta => douta2
	  );
	  
	ram_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				wea1 <= (others => '1');
				wea2 <= (others => '0');
				addra1 <= (others => '0');
				addra2 <= (others => '0');
				dina1 <= (others => '0');
				dina2 <= (others => '0');	
				llr_d1 <= (others => '0');	
				llr_d2 <= (others => '0');	
				state <= '0';	
				state_d1 <= '0';	
				state_d2 <= '0';	
				rd_en <= '0';	
				rd_en_d1 <= '0';	
				rd_en_d2 <= '0';	
				cnt_64800 <= "1111110100101001";
				LEN_N_d1 <= (others => '0');
				ov_llr <= (others => '0');	
				o_llr_en <= '0';
			else
				llr_d1 <= iv_llr;
				llr_d2 <= llr_d1;
				
				if(cnt_360 = "101100111")and(cnt_180 = Blk_N)then--359
					state <= not state;
				else
					state <= state;
				end if;
				
				state_d1 <= state;
				state_d2 <= state_d1;
				
		      if(state_d1 = '0')then
					dina1 <= llr_d2;
					addra1 <= addra;
					dina2 <= (others => '0');
					addra2 <= cnt_64800;
				else
					dina1 <= (others => '0');
					addra1 <= cnt_64800;
					dina2 <= llr_d2;
					addra2 <= addra;				
				end if;
				
				if(state_d2 = '0')then
					ov_llr <= douta2;
				else
					ov_llr <= douta1;					
				end if;
				
				if(state_d1 /= state_d2)then
					wea1 <= not wea1;
					wea2 <= not wea2;
				else
					wea1 <= wea1;
					wea2 <= wea2;
				end if;
				
				if(state /= state_d1)then
					cnt_64800 <= "0000000000000001";--1
					rd_en <= '1';
					LEN_N_d1 <= LEN_N;
				else
					if(cnt_64800 < LEN_N_d1)then
						cnt_64800 <= cnt_64800 + 1;
						rd_en <= '1';
					else
						cnt_64800 <= "1111110100101001";
						rd_en <= '0';
					end if;
				end if;		
				
				rd_en_d1 <= rd_en;
				rd_en_d2 <= rd_en_d1;
				o_llr_en <= rd_en_d2;

			end if;
		end if;
	end process;  
  
	address_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				cnt_360 <= (others => '1');
				cnt_180 <= (others => '0');
				addra_p1 <= (others => '0');
				addra_p2 <= (others => '0');
				addra <= (others => '0');
			else
				if(i_llr_en = '1')then
					
					if(cnt_180 < Blk_K)then--information bits 
					
						if(cnt_360 < "101100111")then
							cnt_360 <= cnt_360 + '1';
						else
							cnt_360 <= "000000000";
						end if;
					
						if(cnt_360 = "101100111")then
							cnt_180 <= cnt_180 + '1';
						else
							cnt_180 <= cnt_180;
						end if; 	
						
						addra_p1 <= addra_p1 + '1';
						addra_p2 <= (others => '0');
						
					elsif(cnt_180 < Blk_N)then--check bits								
						cnt_180 <= cnt_180 + '1';				
						cnt_360 <= cnt_360;
						addra_p1 <= addra_p1;
						addra_p2 <= addra_p2 + "0000000101101000";--360	
					else--check bits		
						cnt_360 <= cnt_360 + '1';
						cnt_180 <= Blk_K;
						addra_p1 <= addra_p1;							
						addra_p2 <= ("0000000"&cnt_360) + '1';					
					end if;	
					
				else
					cnt_360 <= (others => '1');
					cnt_180 <= (others => '0');
					addra_p1 <= (others => '0');
					addra_p2 <= (others => '0');
				end if;
				
				addra <= addra_p1 + addra_p2;
				
			end if;
		end if;
	end process;


	ldpc_parameter : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				Blk_K <= (others => '0');				
				Blk_N <= "11111110";				
				LEN_N <= (others => '0');				
				ov_blk_k <= (others => '0');				
				ov_blk_n <= (others => '1');				
			else
				-- if (i_llr_start = '1') then
				if(iv_len = "00")then
					Blk_N <= "10110011";--179
					LEN_N <= "1111110100100000";--64800
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
					LEN_N <= "0111111010010000";--32400
					case iv_rate is
						when "000000" => Blk_K <= conv_std_logic_vector(18,8);--1/5
						when "000001" => Blk_K <= conv_std_logic_vector(22,8);--11/45
						when "000010" => Blk_K <= conv_std_logic_vector(30,8);--1/3
						when others => Blk_K <= (others => '0');
					end case;
				else
					Blk_N <= "00101100";--44
					LEN_N <= "0011111101001000";--16200
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
				ov_blk_n <= Blk_N + 1;
			end if;
		end if;
		-- end if;
end process;
end Behavioral;