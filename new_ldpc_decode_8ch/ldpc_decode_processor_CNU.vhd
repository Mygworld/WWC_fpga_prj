----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:45:11 07/08/2015 
-- Design Name: 
-- Module Name:    ldpc_decode_processor_CNU - Behavioral 
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

entity ldpc_decode_processor_CNU is
    Port ( i_clk : in  STD_LOGIC;
           i_rst : in  STD_LOGIC;
           iv_data : in  STD_LOGIC_VECTOR (5 downto 0);
           i_weight : in  STD_LOGIC;
           i_weight_delay : in  STD_LOGIC;
           i_sgn_delay : in  STD_LOGIC;
           ov_data : out  STD_LOGIC_VECTOR (5 downto 0));
end ldpc_decode_processor_CNU;

architecture Behavioral of ldpc_decode_processor_CNU is

	signal data_abs : std_logic_vector(4 downto 0);
	signal data_abs_en : std_logic;
	signal data_abs_en_d1, data_abs_en_d2 : std_logic;
	signal sgn : std_logic;
	
	signal data_cnt : std_logic_vector(4 downto 0);
	signal data_min_pos : std_logic_vector(4 downto 0);
	signal data_min : std_logic_vector(4 downto 0);
	signal data_sub_min : std_logic_vector(4 downto 0);
	signal sgn_all : std_logic;
	signal data_all : std_logic_vector(15 downto 0);
	
	signal cnu_sgn : std_logic;
	signal cnu_sgn_d1 : std_logic;
	signal cnu_weight_d1, cnu_weight_d2 : std_logic;
	signal cnu_en : std_logic;
	signal cnu_cnt : std_logic_vector(4 downto 0);
	signal cnu_data_min : std_logic_vector(4 downto 0);
	signal cnu_data_multi : std_logic_vector(9 downto 0);
	signal cnu_data_out : std_logic_vector(5 downto 0);

	signal flag : std_logic;
begin

	abs_process : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				data_abs <= (others => '0');
				data_abs_en <= '0';
				data_abs_en_d1 <= '0';
				data_abs_en_d2 <= '0';
				sgn <= '0';
			else
				data_abs_en <= i_weight;
				data_abs_en_d1 <= data_abs_en;
				data_abs_en_d2 <= data_abs_en_d1;
				if(iv_data(5) = '0')then
					data_abs <= iv_data(4 downto 0);
				else
					data_abs <= (not iv_data(4 downto 0)) + '1';
				end if;
				sgn <= iv_data(5);
			end if;
		end if;
	end process;
	
	sgn_min_process : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				data_cnt <= (others => '0');
				data_min_pos <= (others => '0');
				data_min <= (others => '0');
				data_sub_min <= (others => '0');
				sgn_all <= '0';
				data_all <= (others => '0');
			else
				if(data_abs_en = '1' and data_abs_en_d1 = '0')then
				
					data_cnt <= "00010";
					data_min_pos <= "00001";
					data_min <= data_abs;
					data_sub_min <= (others => '1');
					sgn_all <= sgn;	
					
				else
				
					data_cnt <= data_cnt + '1';
					sgn_all <= sgn_all xor sgn;
					if(data_abs < data_min)then
						data_min <= data_abs;
						data_sub_min <= data_min;
						data_min_pos <= data_cnt;
					elsif(data_abs < data_sub_min)then
						data_min <= data_min;
						data_sub_min <= data_abs;
						data_min_pos <= data_min_pos;	
					else
						data_min <= data_min;
						data_sub_min <= data_sub_min;
						data_min_pos <= data_min_pos;
					end if;
					
				end if;	
				
				if(data_abs_en_d1 = '0' and data_abs_en_d2 = '1')then
					data_all <= sgn_all&data_min&data_sub_min&data_min_pos;
				else
					data_all <= data_all;
				end if;
				
			end if;
		end if;
	end process;
	
	check_node_update_process : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				cnu_sgn <= '0';
				cnu_sgn_d1 <= '0';
				cnu_weight_d1 <= '0';
				cnu_weight_d2 <= '0';
				cnu_cnt <= "00001";
				cnu_data_min <= (others => '0');
				cnu_data_multi <= (others => '0');
				cnu_data_out <= (others => '0');
				ov_data <= (others => '0');
				cnu_en <= '0';
				flag <= '0';
			else
				
				cnu_weight_d1 <= i_weight_delay;
				cnu_weight_d2 <= cnu_weight_d1;
				
				cnu_en <= cnu_weight_d1 or cnu_weight_d2;
				
				cnu_sgn <= data_all(15) xor i_sgn_delay;
				cnu_sgn_d1 <= cnu_sgn;
				
				if(i_weight_delay = '1')then
					cnu_cnt <= cnu_cnt + '1';
				else
					cnu_cnt <= "00001";
				end if;
				
				if(cnu_cnt = data_all(4 downto 0))then
					cnu_data_min <= data_all(9 downto 5);
				else
					cnu_data_min <= data_all(14 downto 10);
				end if;
				
				if(cnu_cnt > "00101")then
					flag <= '1';
				else
					flag <= flag;
				end if;


				if(flag =  '1')then 				
					cnu_data_multi <= (cnu_data_min&"00000") - ("000"&cnu_data_min&"00"); -- 32-8=24/32=0.75
				else
					cnu_data_multi <= (cnu_data_min&"00000") - ("00000"&cnu_data_min); -- 32-1=31/32=0.96875
				end if;
				
				if(cnu_en = '1')then
					if(cnu_sgn_d1 = '0')then
						cnu_data_out <= cnu_sgn_d1&cnu_data_multi(9 downto 5);
					else
						cnu_data_out <= cnu_sgn_d1&(not cnu_data_multi(9 downto 5)) + '1';
					end if;
				else
					cnu_data_out <= (others => '0');
				end if;
				
				ov_data <= cnu_data_out;
				
			end if;
		end if;
	end process;

end Behavioral;