----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:09:26 07/07/2015 
-- Design Name: 
-- Module Name:    ldpc_decode_processor - Behavioral 
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

entity ldpc_decode_processor is
    Port ( i_clk : in  STD_LOGIC;
           i_rst : in  STD_LOGIC;
           iv_data : in  STD_LOGIC_VECTOR (2159 downto 0);
           i_data_en : in  STD_LOGIC;
           i_weight : in  STD_LOGIC;
           ov_data : out  STD_LOGIC_VECTOR (2159 downto 0);
		   o_data_en : out  STD_LOGIC);
end ldpc_decode_processor;

architecture Behavioral of ldpc_decode_processor is

	COMPONENT ldpc_decode_processor_fifo
	  PORT (
		 clk : IN STD_LOGIC;
		 srst : IN STD_LOGIC;
		 din : IN STD_LOGIC_VECTOR(361 DOWNTO 0);
		 wr_en : IN STD_LOGIC;
		 rd_en : IN STD_LOGIC;
		 dout : OUT STD_LOGIC_VECTOR(361 DOWNTO 0);
		 full : OUT STD_LOGIC;
		 empty : OUT STD_LOGIC
	  );
	END COMPONENT;
	
	COMPONENT ldpc_decode_processor_CNU
	PORT(
		i_clk : IN std_logic;
           i_rst : in  STD_LOGIC;
           iv_data : in  STD_LOGIC_VECTOR (5 downto 0);
           i_weight : in  STD_LOGIC;
           i_weight_delay : in  STD_LOGIC;
           i_sgn_delay : in  STD_LOGIC;
		   ov_data : OUT std_logic_vector(5 downto 0)
		);
	END COMPONENT;
	
	signal i_data_en_d1 : std_logic;
	
	signal fifo_din : std_logic_vector(361 downto 0);
	signal fifo_dout : std_logic_vector(361 downto 0);
	signal fifo_dout_d1 : std_logic_vector(361 downto 0);
	signal fifo_wr_en : std_logic;
	signal fifo_rd_en : std_logic;
	signal fifo_full : std_logic;
	signal fifo_empty : std_logic;
	signal data_en_d1, data_en_d2, data_en_d3 : std_logic;
	
begin

	processor_fifo : ldpc_decode_processor_fifo
	  PORT MAP (
		 clk => i_clk,
		 srst => i_rst,
		 din => fifo_din,
		 wr_en => fifo_wr_en,
		 rd_en => fifo_rd_en,
		 dout => fifo_dout,
		 full => fifo_full,
		 empty => fifo_empty
	  );
	  
	fifo_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				fifo_din <= (others => '0');
				fifo_dout_d1 <= (others => '0');
				fifo_wr_en <= '0';
				fifo_rd_en <= '0';
				i_data_en_d1 <= '0';
				data_en_d1 <= '0';
				data_en_d2 <= '0';
				data_en_d3 <= '0';
				o_data_en <= '0';
			else
				i_data_en_d1 <= i_data_en;
				fifo_wr_en <= i_data_en or i_data_en_d1;
				
				fifo_din(361) <= i_data_en;
				fifo_din(360) <= i_weight;
				for i in 359 downto 0 loop
					fifo_din(i) <= iv_data(6*i+5);
				end loop;	
				
				if(i_data_en = '1' and i_weight = '0')then
					fifo_rd_en <= '1';
				elsif(fifo_empty = '1')then
					fifo_rd_en <= '0';
				else
					fifo_rd_en <= fifo_rd_en;
				end if;
				
				fifo_dout_d1 <= fifo_dout; 
				
--				data_en_d1 <= fifo_dout_d1(361);
--				data_en_d2 <= data_en_d1;	
--				data_en_d3 <= data_en_d2;	
--				o_data_en <= data_en_d3;
				o_data_en <= fifo_dout(361);--here o_data_en is just a start flag for parameter module output ,not indicates whether the ov_data is enable,in fact, data_en_d3 indicates whether the ov_data is enable
				
			end if;
		end if;
	end process;
	
	gen_CNU : for i in 0 to 359 generate
    begin
    Inst_ldpc_decode_processor_CNU : entity work.ldpc_decode_processor_CNU
        port map (
            i_clk          => i_clk,
            i_rst          => i_rst,
            iv_data        => iv_data(6*i+5 downto 6*i),      -- 输入数据切片
            i_weight       => i_weight,
            i_weight_delay => fifo_dout_d1(360),             -- 固定第360位
            i_sgn_delay    => fifo_dout_d1(i),               -- 递增索引0-359
            ov_data        => ov_data(6*i+5 downto 6*i)      -- 输出数据切片
        );
end generate gen_CNU;

end Behavioral;