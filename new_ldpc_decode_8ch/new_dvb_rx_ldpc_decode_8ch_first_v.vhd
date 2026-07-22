----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:53:37 06/24/2015 
-- Design Name: 
-- Module Name:    ldpc_decode - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Revision 0.02 - 8-path port(in and out)
-- Additional Comments: 
-- iv_len: 00-Normal, 01-Medium, 10-Short
-- iv_rate: Map DVB iv_modcod to LDPC coderate inside new_dvb_rx_demodcod_message module
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use ieee.std_logic_textio.all; 
library std;
use std.textio.all;  

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity new_dvb_rx_ldpc_decode_8path is
    Port (
           i_clk : in  STD_LOGIC;
           i_rst : in  STD_LOGIC;
           iv_len : in  STD_LOGIC_VECTOR (1 downto 0);
           iv_rate : in  STD_LOGIC_VECTOR (5 downto 0);
           iv_iter : in  STD_LOGIC_VECTOR (7 downto 0);
           iv_llr : in  STD_LOGIC_VECTOR (47 downto 0); -- 8-ch LLR input
           i_llr_en : in  STD_LOGIC;
--		   i_llr_start : in  STD_LOGIC;
           i_workflag: in  STD_LOGIC;
           o_data : out  STD_LOGIC_VECTOR (7 downto 0); -- 8-ch code output
           o_data_en : out  STD_LOGIC);
end new_dvb_rx_ldpc_decode_8path;

architecture Behavioral of new_dvb_rx_ldpc_decode_8path is

	-- change:from 1-path to 8-path
	COMPONENT ldpc_decode_llr_adjust_8ch
	PORT(
		i_clk : IN std_logic;
		i_rst : IN std_logic;
		iv_len : IN std_logic_vector(1 downto 0);
		iv_rate : IN std_logic_vector(5 downto 0);
		iv_llr : IN std_logic_vector(47 downto 0);
		i_llr_en : IN std_logic;
	--	i_llr_start : in  STD_LOGIC;          
		ov_blk_k : OUT std_logic_vector(7 downto 0);
		ov_blk_n : OUT std_logic_vector(7 downto 0);
		ov_llr : OUT std_logic_vector(47 downto 0);
		o_llr_en : OUT std_logic
		);
	END COMPONENT;
COMPONENT ila_iters
    
    PORT (
        clk : IN STD_LOGIC;
    
    
    
        probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        probe1 : IN STD_LOGIC
    );
    END COMPONENT  ;
	COMPONENT ldpc_decode_llr_ram
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 dina : IN STD_LOGIC_VECTOR(1079 DOWNTO 0);
		 rstb : IN STD_LOGIC;
		 clkb : IN STD_LOGIC;
		 rsta_busy : OUT STD_LOGIC;
         rstb_busy : OUT STD_LOGIC;
		 addrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 doutb : OUT STD_LOGIC_VECTOR(1079 DOWNTO 0)
	  );
	END COMPONENT;
	
	COMPONENT ldpc_decode_parameter
	PORT(
		i_clk : IN std_logic;
		i_rst : IN std_logic;
		iv_len : IN std_logic_vector(1 downto 0);
		iv_rate : IN std_logic_vector(5 downto 0);
		i_ctrl_en : IN std_logic; 
		o_pos_en : OUT std_logic;		
		o_weight : OUT std_logic;
		ov_pos : OUT std_logic_vector(7 downto 0);
        ov_fwdshift : out  STD_LOGIC_VECTOR (8 downto 0);
		ov_revshift : out  STD_LOGIC_VECTOR (8 downto 0);
		o_ctrl_en : OUT std_logic
		);
	END COMPONENT;

	-- for cnu_ctrl_out,cnu_revfwdshift,sum_ram_pos,sum_ram_pos_en delay
	COMPONENT ldpc_decode_CNU_param_fifo
	  PORT (
		 clk : IN STD_LOGIC;
		 srst : IN STD_LOGIC;
		 din : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
		 wr_en : IN STD_LOGIC;
		 rd_en : IN STD_LOGIC;
		 dout : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);
		 full : OUT STD_LOGIC;
		 empty : OUT STD_LOGIC
	  );
	END COMPONENT;

	COMPONENT ldpc_decode_barrel_shifter_360 is
    Port (
        i_clk    : in  STD_LOGIC;
        i_rst    : in  STD_LOGIC;
        i_valid  : in  STD_LOGIC;
        iv_shift : in  STD_LOGIC_VECTOR(8 downto 0);
        iv_data  : in  STD_LOGIC_VECTOR(2159 downto 0);
        o_valid  : out STD_LOGIC;
        ov_data  : out STD_LOGIC_VECTOR(2159 downto 0)
    );
	END COMPONENT;
	
	COMPONENT ldpc_decode_temp_ram
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
	
	COMPONENT ldpc_decode_processor
	PORT(
		i_clk : IN std_logic;
		i_rst : IN std_logic;
		iv_data : IN std_logic_vector(2159 downto 0);
		i_data_en : IN std_logic;
		i_weight : IN std_logic;          
		ov_data : OUT std_logic_vector(2159 downto 0);
		o_data_en : OUT std_logic
		);
	END COMPONENT;
	
	COMPONENT ldpc_decode_sum_ram
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
	
	COMPONENT ldpc_decode_code_ram
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 rsta : IN STD_LOGIC;
		 addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 rsta_busy : OUT STD_LOGIC;
		 dina : IN STD_LOGIC_VECTOR(359 DOWNTO 0);
		 douta : OUT STD_LOGIC_VECTOR(359 DOWNTO 0)
	  );
	END COMPONENT;
	
--	signal max_iterate : std_logic_vector(5 downto 0) := "101000";--40
--	signal max_iterate : std_logic_vector(5 downto 0) := "011111";--32
--	signal max_iterate : std_logic_vector(5 downto 0) := "010100";--20
--	signal max_iterate : std_logic_vector(5 downto 0) := "001000";--8

    -- change:Delay state to isolate new frame rate/len/iter/BLK_K/BLK_N interference for ACM
	-- delete internal ping-pong  
    signal iv_iter_d1 : STD_LOGIC_VECTOR (7 downto 0);
	signal max_iterate : std_logic_vector(7 downto 0);
	signal iterate_loop : std_logic_vector(7 downto 0);
--  	signal clk,i_clk : std_logic;
--  	signal locked : std_logic;
	signal Blk_K, Blk_K_d1, Blk_K_d2, Blk_K_d3, Blk_K_d4 : std_logic_vector(7 downto 0);  	
	signal Blk_N, Blk_N_d1 : std_logic_vector(7 downto 0);  
	signal iv_len_d1, iv_len_d2 : STD_LOGIC_VECTOR (1 downto 0);
    signal iv_rate_d1, iv_rate_d2 : STD_LOGIC_VECTOR (5 downto 0);
	signal llr_adjust : std_logic_vector(47 downto 0);  
	signal llr_adjust_en, llr_adjust_en_d1 : std_logic;  
	
	signal llr_ram_wea : std_logic_vector(0 downto 0);
	signal llr_ram_addra : std_logic_vector(7 downto 0);
	signal llr_ram_dina : std_logic_vector(2159 downto 0);
	signal llr_ram_addrb : std_logic_vector(7 downto 0);
	signal llr_ram_doutb : std_logic_vector(2159 downto 0);
	signal llr_ram_doutb_d1, llr_ram_doutb_d2 : std_logic_vector(2159 downto 0);
	
	signal cnt_360 : integer range 0 to 63;
	
	signal pos_en : std_logic;
	signal pos_en_d1, pos_en_d2, pos_en_d3, pos_en_d4, pos_en_d5, pos_en_d6 : std_logic;
	signal weight : std_logic;
	signal weight_d1, weight_d2, weight_d3, weight_d4, weight_d5, weight_d6, weight_d7, weight_d8 : std_logic;
	signal pos : std_logic_vector(7 downto 0);
	signal pos_d1, pos_d2, pos_d3, pos_d4, pos_d5, pos_d6, pos_d7, pos_d8 : std_logic_vector(7 downto 0);
	signal fwdshift : std_logic_vector(8 downto 0);
	signal fwdshift_d1, fwdshift_d2, fwdshift_d3, fwdshift_d4, fwdshift_d5 : std_logic_vector(8 downto 0);
	signal revshift : std_logic_vector(8 downto 0);
	signal ctrl_in : std_logic;
	signal ctrl_out : std_logic;
	signal ctrl_out_d1, ctrl_out_d2, ctrl_out_d3, ctrl_out_d4, ctrl_out_d5, ctrl_out_d6, ctrl_out_d7, ctrl_out_d8, ctrl_out_d9 : std_logic;

	-- CNU_param_fifo port map: 19-bit din(1-bit ctrl_out & 9-bit revshift & 8-bit pos & 1-bit pos_en)
	signal fifo_din : std_logic_vector(18 downto 0);
	signal fifo_dout : std_logic_vector(18 downto 0);
	--signal fifo_dout_d1 : std_logic_vector(361 downto 0);
	signal fifo_wr_en : std_logic;
	signal fifo_rd_en : std_logic;
	signal fifo_full : std_logic;
	signal fifo_empty : std_logic;
	signal fifo_ctrl_out_d1,fifo_ctrl_out_d2,fifo_ctrl_out_d3,fifo_ctrl_out_d4,fifo_ctrl_out_d5,fifo_ctrl_out_d6,fifo_ctrl_out_d7 : std_logic;
	signal fifo_revshift_d1,fifo_revshift_d2,fifo_revshift_d3 : std_logic_vector(8 downto 0);
	signal fifo_pos_d1,fifo_pos_d2,fifo_pos_d3,fifo_pos_d4,fifo_pos_d5,fifo_pos_d6 : std_logic_vector(7 downto 0);
	signal fifo_pos_en_d1,fifo_pos_en_d2,fifo_pos_en_d3,fifo_pos_en_d4,fifo_pos_en_d5,fifo_pos_en_d6 : std_logic;

	signal fwdshifter_out_en : std_logic;
	signal fwdshifter_in  : std_logic_vector(2159 downto 0);
	signal fwdshifter_out : std_logic_vector(2159 downto 0);
	signal revshifter_out_en : std_logic;
	signal revshifter_in  : std_logic_vector(2159 downto 0);
	signal revshifter_out : std_logic_vector(2159 downto 0);
	signal fwdshifter_temp1, fwdshifter_temp2 : std_logic_vector(2159 downto 0);
	signal fwdshift87_d1, fwdshift87_d2, fwdshift87_d3, fwdshift87_d4, fwdshift87_d5 : std_logic_vector(1 downto 0);
	signal fwdshift64_d1, fwdshift64_d2, fwdshift64_d3, fwdshift64_d4, fwdshift64_d5, fwdshift64_d6 : std_logic_vector(2 downto 0);
	signal fwdshift30_d1, fwdshift30_d2, fwdshift30_d3, fwdshift30_d4, fwdshift30_d5, fwdshift30_d6, fwdshift30_d7 : std_logic_vector(3 downto 0);

	signal temp_ram_wea : std_logic_vector(0 downto 0);
	signal temp_ram_addra : std_logic_vector(9 downto 0);
	signal temp_ram_dina : std_logic_vector(2159 downto 0);
	signal temp_ram_addrb : std_logic_vector(9 downto 0);
	signal temp_ram_doutb : std_logic_vector(2159 downto 0);
	signal temp_ram_doutb_d1, temp_ram_doutb_d2, temp_ram_doutb_d3, temp_ram_doutb_d4, temp_ram_doutb_d5 : std_logic_vector(2159 downto 0);
	signal temp_ram_state : std_logic;
	signal temp_ram_state_d1, temp_ram_state_d2, temp_ram_state_d3, temp_ram_state_d4, temp_ram_state_d5, temp_ram_state_d6, temp_ram_state_d7 : std_logic;
	
	-- change:use counter to drive temp_ram read enable, fix ACM bug
	signal temp_ram_rd_cnt : std_logic_vector(9 downto 0);
	
	signal decode_processor_in : std_logic_vector(2159 downto 0);
	signal decode_processor_in_en : std_logic;
	signal decode_processor_weight : std_logic;	
	signal decode_processor_out : std_logic_vector(2159 downto 0);
	signal decode_processor_out_d1, decode_processor_out_d2, decode_processor_out_d3, decode_processor_out_d4, decode_processor_out_d5 : std_logic_vector(2159 downto 0);
	signal decode_processor_out_en : std_logic;

	-- sum_ram ping-pong:for vnu_data(update need sum_ram_doutb_1) directly write to cnu (sum_ram update need sum_ram_doutb_2)
	-- sum_ram_state = 0:wr sum_ram_1 rd sum_ram_2, = 1:wr sum_ram_2 rd sum_ram_1
	signal sum_ram_state 						 : std_logic;
	signal sum_ram_wea_1,sum_ram_wea_2      	 : std_logic_vector(0 downto 0);
	signal sum_ram_addra_1,sum_ram_addra_2   	 : std_logic_vector(7 downto 0);
	signal sum_ram_dina_1,sum_ram_dina_2    	 : std_logic_vector(3959 downto 0);
	signal sum_ram_addrb_1,sum_ram_addrb_2  	 : std_logic_vector(7 downto 0);
	signal sum_ram_doutb_1,sum_ram_doutb_2   	 : std_logic_vector(3959 downto 0);
	signal sum_ram_doutb_1_d1,sum_ram_doutb_2_d1 : std_logic_vector(3959 downto 0);
	
	signal vnu_data : std_logic_vector(3959 downto 0);
	signal code_ram_wea : std_logic_vector(0 downto 0);
	signal code_ram_addra : std_logic_vector(7 downto 0);
	signal code_ram_dina : std_logic_vector(359 downto 0);
	signal code_ram_douta, code_ram_douta_d1 : std_logic_vector(359 downto 0);
	signal decode_finish_en : std_logic;
	signal decode_finish_en_d1, decode_finish_en_d2, decode_finish_en_d3, decode_finish_en_d4 : std_logic;
	signal cnt_out : std_logic_vector(7 downto 0);
	signal cnt_out_d1, cnt_out_d2, cnt_out_d3, cnt_out_d4 : std_logic_vector(7 downto 0);
	signal code_out_en : std_logic;
	signal code_out_en_d1, code_out_en_d2, code_out_en_d3 : std_logic;
	signal cnt_out_360, cnt_out_360_d1, cnt_out_360_d2 : integer range 0 to 63;

	-- add:Reg 8-ch decoder out and out en,need swap MSB/LSB
    signal tmp_data     : std_logic_vector(7 downto 0);
    signal tmp_data_en  : std_logic;
	
	-- ram-clear count
	signal cnt : integer range 0 to 850:= 0;
	signal cnt_llr : integer range 0 to 365:= 0;
    
    signal rstb1,rstb2,rsta_busya1,rstb_busyb1,rsta_busya2,rstb_busyb2 : std_logic;
    signal tmprsta_busya1,tmprstb_busyb1,tmprsta_busya2,tmprstb_busyb2 :std_logic;
    signal sumrsta_busya1,sumrstb_busyb1,sumrsta_busya2,sumrstb_busyb2 :std_logic;
    signal sumrsta_busya3,sumrstb_busyb3,sumrsta_busya4,sumrstb_busyb4 :std_logic;
	signal sumrsta_busya5,sumrstb_busyb5,sumrsta_busya6,sumrstb_busyb6 :std_logic;
    signal sumrsta_busya7,sumrstb_busyb7,sumrsta_busya8,sumrstb_busyb8 :std_logic;
    signal codersta_busya :std_logic;
    signal workflag :std_logic;

	---------------------------------change-------------------------------------------
	-- SUM_RAM R-A-W the second Bypass reg to save 1-clk delay of sum_ram_dina_1/sum_ram_wea_1/sum_ram_dina_1
    signal bypass_we_2    : std_logic := '0';
    signal bypass_addra_2 : std_logic_vector(7 downto 0) ; 
    signal bypass_dina_2  : std_logic_vector(3959 downto 0) ;

begin

--Inst_clk_div : clk_div
--  port map
--    (-- Clock in ports
--     CLK_IN1_P => i_clk_p,
--     CLK_IN1_N => i_clk_n,
--     CLK_OUT1 => clk,
--     CLK_OUT2 => i_clk,
--     LOCKED => locked);


	Inst_ldpc_decode_llr_adjust_8ch: ldpc_decode_llr_adjust_8ch PORT MAP(
		i_clk => i_clk,
		i_rst => i_rst,
		iv_len => iv_len,
		iv_rate => iv_rate,
		iv_llr => iv_llr,
		i_llr_en => i_llr_en,
--		i_llr_start => i_llr_start,
		ov_blk_k => Blk_K,
		ov_blk_n => Blk_N,
		ov_llr => llr_adjust,
		o_llr_en => llr_adjust_en
	);

	Inst_ldpc_decode_llr_ram_p1 : ldpc_decode_llr_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => llr_ram_wea,
		 addra => llr_ram_addra,
		 rstb => i_rst,
		 dina => llr_ram_dina(1079 DOWNTO 0),
		 clkb => i_clk,
		 rsta_busy => rsta_busya1,   
         rstb_busy => rstb_busyb1,
		 addrb => llr_ram_addrb,
		 doutb => llr_ram_doutb(1079 DOWNTO 0)
	  );

	Inst_ldpc_decode_llr_ram_p2 : ldpc_decode_llr_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => llr_ram_wea,
		 addra => llr_ram_addra,
		 rstb => i_rst,
		 dina => llr_ram_dina(2159 DOWNTO 1080),
		 clkb => i_clk,
		 rsta_busy => rsta_busya2,   
         rstb_busy => rstb_busyb2,
		 addrb => llr_ram_addrb,
		 doutb => llr_ram_doutb(2159 DOWNTO 1080)
	  );
	  
	Inst_ldpc_decode_parameter: ldpc_decode_parameter 
	  PORT MAP(
		i_clk => i_clk,
		i_rst => i_rst,
		iv_len => iv_len_d2,
		iv_rate => iv_rate_d2,
		i_ctrl_en => ctrl_in,
		o_pos_en => pos_en,
		o_weight => weight,
		ov_pos => pos,
		ov_fwdshift => fwdshift,
		ov_revshift => revshift,
		o_ctrl_en => ctrl_out
	  );
	  
	Inst_fwd_barrel_shifter_360 : ldpc_decode_barrel_shifter_360
    Port MAP(
        i_clk    => i_clk,
        i_rst    => i_rst,
        i_valid  => ctrl_out_d5,
        iv_shift => fwdshift_d5,
        iv_data  => fwdshifter_in,
        o_valid  => fwdshifter_out_en,
        ov_data  => fwdshifter_out
    );
	
	Inst_ldpc_decode_CNU_param_fifo : ldpc_decode_CNU_param_fifo
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

	Inst_rev_barrel_shifter_360 : ldpc_decode_barrel_shifter_360
    Port MAP(
        i_clk    => i_clk,
        i_rst    => i_rst,
        i_valid  => fifo_ctrl_out_d3,
        iv_shift => fifo_revshift_d3,
        iv_data  => revshifter_in,
        o_valid  => revshifter_out_en,
        ov_data  => revshifter_out
    );
	
	Inst_ldpc_decode_temp_ram_p1 : ldpc_decode_temp_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => temp_ram_wea,
		 addra => temp_ram_addra,
		 rstb => i_rst,
		 dina => temp_ram_dina(1079 DOWNTO 0),
		 rsta_busy => tmprsta_busya1,
		 rstb_busy => tmprstb_busyb1,
		 clkb => i_clk,
		 addrb => temp_ram_addrb,
		 doutb => temp_ram_doutb(1079 DOWNTO 0)
	  );
	  
	Inst_ldpc_decode_temp_ram_p2 : ldpc_decode_temp_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => temp_ram_wea,
		 addra => temp_ram_addra,
		 rstb => i_rst,
		 dina => temp_ram_dina(2159 DOWNTO 1080),
		 clkb => i_clk,
		 rsta_busy => tmprsta_busya2,
		 rstb_busy => tmprstb_busyb2,
		 addrb => temp_ram_addrb,
		 doutb => temp_ram_doutb(2159 DOWNTO 1080)
	  );
	  
	Inst_ldpc_decode_processor: ldpc_decode_processor PORT MAP(
		i_clk => i_clk,
		i_rst => i_rst,
		iv_data => decode_processor_in,
		i_data_en => decode_processor_in_en,
		i_weight => decode_processor_weight,
		ov_data => decode_processor_out,
		o_data_en => decode_processor_out_en
	);
	
	Inst_ldpc_decode_sum_ram_p1 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_1,
		 addra => sum_ram_addra_1,
		 rstb => i_rst,
		 dina => sum_ram_dina_1(989 downto 0),
		 rsta_busy => sumrsta_busya1,
		 rstb_busy => sumrstb_busyb1,
		 clkb => i_clk,
		 addrb => sum_ram_addrb_1,
		 doutb => sum_ram_doutb_1(989 downto 0)
	  );
	  
	Inst_ldpc_decode_sum_ram_p2 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_1,
		 addra => sum_ram_addra_1,
		 rstb => i_rst,
		 dina => sum_ram_dina_1(1979 downto 990),
		 clkb => i_clk,
		 rsta_busy => sumrsta_busya2,
         rstb_busy => sumrstb_busyb2,
		 addrb => sum_ram_addrb_1,
		 doutb => sum_ram_doutb_1(1979 downto 990)
	  );
	  
	Inst_ldpc_decode_sum_ram_p3 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_1,
		 addra => sum_ram_addra_1,
		 rstb => i_rst,
		 dina => sum_ram_dina_1(2969 downto 1980),
		 clkb => i_clk,
		 rsta_busy => sumrsta_busya3,
         rstb_busy => sumrstb_busyb3,
		 addrb => sum_ram_addrb_1,
		 doutb => sum_ram_doutb_1(2969 downto 1980)
	  );
	  
	Inst_ldpc_decode_sum_ram_p4 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_1,
		 addra => sum_ram_addra_1,
		 rstb => i_rst,
		 dina => sum_ram_dina_1(3959 downto 2970),
		 clkb => i_clk,
		 rsta_busy => sumrsta_busya4,
         rstb_busy => sumrstb_busyb4,
		 addrb => sum_ram_addrb_1,
		 doutb => sum_ram_doutb_1(3959 downto 2970)
	  );

	Inst_ldpc_decode_sum_ram_p5 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_2,
		 addra => sum_ram_addra_2,
		 rstb => i_rst,
		 dina => sum_ram_dina_2(989 downto 0),
		 rsta_busy => sumrsta_busya5,
		 rstb_busy => sumrstb_busyb5,
		 clkb => i_clk,
		 addrb => sum_ram_addrb_2,
		 doutb => sum_ram_doutb_2(989 downto 0)
	  );
	  
	Inst_ldpc_decode_sum_ram_p6 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_2,
		 addra => sum_ram_addra_2,
		 rstb => i_rst,
		 dina => sum_ram_dina_2(1979 downto 990),
		 rsta_busy => sumrsta_busya6,
		 rstb_busy => sumrstb_busyb6,
		 clkb => i_clk,
		 addrb => sum_ram_addrb_2,
		 doutb => sum_ram_doutb_2(1979 downto 990)
	  );
	  
	Inst_ldpc_decode_sum_ram_p7 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_2,
		 addra => sum_ram_addra_2,
		 rstb => i_rst,
		 dina => sum_ram_dina_2(2969 downto 1980),
		 rsta_busy => sumrsta_busya7,
		 rstb_busy => sumrstb_busyb7,
		 clkb => i_clk,
		 addrb => sum_ram_addrb_2,
		 doutb => sum_ram_doutb_2(2969 downto 1980)
	  );
	  
	Inst_ldpc_decode_sum_ram_p8 : ldpc_decode_sum_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => sum_ram_wea_2,
		 addra => sum_ram_addra_2,
		 rstb => i_rst,
		 dina => sum_ram_dina_2(3959 downto 2970),
		 rsta_busy => sumrsta_busya8,
		 rstb_busy => sumrstb_busyb8,
		 clkb => i_clk,
		 addrb => sum_ram_addrb_2,
		 doutb => sum_ram_doutb_2(3959 downto 2970)
	  );

	Inst_ldpc_decode_code_ram : ldpc_decode_code_ram
	  PORT MAP (
		 clka => i_clk,
		 wea => code_ram_wea,
		 rsta  => i_rst,
		 addra => code_ram_addra,
		 rsta_busy => codersta_busya,
		 dina => code_ram_dina,
		 douta => code_ram_douta
	  );	 
	  
	workflag_p : process(i_clk)
      begin
          if(i_clk'event and i_clk = '1')then
              workflag <= i_workflag;
          end if;
      end process;	  
	  
	block_2n_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				sum_ram_doutb_1_d1 <= (others => '0');
			else
			    sum_ram_doutb_1_d1 <= sum_ram_doutb_1;
			end if;
		end if;
	end process;

	llr_ram_input_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				llr_ram_wea <= (others => '1');
				llr_ram_dina <= (others => '0');
				cnt_360 <= 0;
				Blk_N_d1 <= (others => '1');
				Blk_K_d1 <= (others => '0');
				iv_len_d1 <= (others => '0');
				iv_rate_d1 <= (others => '0');
				iv_iter_d1 <= (others => '0');
				llr_adjust_en_d1 <= '0';
				if cnt_llr = 0 then --add to clear the data in the llr_ram when i_rst = 1
					llr_ram_addra <= (others => '0');
					cnt_llr <= cnt_llr + 1; 
				elsif(cnt_llr >= 1 and cnt_llr < 183)then
					llr_ram_addra <= llr_ram_addra + 1;
					cnt_llr <= cnt_llr + 1;
				else
					cnt_llr <= cnt_llr;
					llr_ram_addra <= (others => '0');
				end if;	
			else				
				cnt_llr <= 0;
				if(llr_adjust_en = '1')then
					if(cnt_360 = 44)then
						cnt_360 <= 0;
						llr_ram_wea <= "1";
						llr_ram_addra <= llr_ram_addra + '1';
					else
						cnt_360 <= cnt_360 + 1;
						llr_ram_wea <= "0";
						llr_ram_addra <= llr_ram_addra;
					end if;
				else
					cnt_360 <= 0;
					llr_ram_wea <= (others => '0');
					if(llr_ram_addra = Blk_N_d1)and(llr_ram_wea = "1")then
						llr_ram_addra <= (others => '0');
					else
						llr_ram_addra <= llr_ram_addra;
					end if;
				end if;
				if(llr_adjust_en = '1')and(llr_adjust_en_d1 = '0')then
				    Blk_N_d1 <= Blk_N;
				    Blk_K_d1 <= Blk_K;
				    iv_len_d1 <= iv_len;
				    iv_rate_d1 <= iv_rate;
				    iv_iter_d1 <= iv_iter;
				end if;
				llr_adjust_en_d1 <= llr_adjust_en;
				llr_ram_dina(48*cnt_360+47 downto 48*cnt_360) <= llr_adjust;--serial to parallel
			end if;
		end if;
	end process;

	llr_ram_output_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				ctrl_in <= '0';
				ctrl_out_d1 <= '0';
				ctrl_out_d2 <= '0';
				ctrl_out_d3 <= '0';
				ctrl_out_d4 <= '0';
				ctrl_out_d5 <= '0';
				ctrl_out_d6 <= '0';
				ctrl_out_d7 <= '0';
				ctrl_out_d8 <= '0';
				ctrl_out_d9 <= '0';
				llr_ram_addrb <= (others => '0');
				llr_ram_doutb_d1 <= (others => '0');
				llr_ram_doutb_d2 <= (others => '0');
				Blk_K_d2 <= (others => '0');
				iv_len_d2 <= (others => '0');
				iv_rate_d2 <= (others => '0');
				max_iterate <= (others => '0');
			else
				ctrl_out_d1 <= ctrl_out;
				ctrl_out_d2 <= ctrl_out_d1;
				ctrl_out_d3 <= ctrl_out_d2;
				ctrl_out_d4 <= ctrl_out_d3;
				ctrl_out_d5 <= ctrl_out_d4;
				ctrl_out_d6 <= ctrl_out_d5;
				ctrl_out_d7 <= ctrl_out_d6;
				ctrl_out_d8 <= ctrl_out_d7;
				ctrl_out_d9 <= ctrl_out_d8;

				if(llr_ram_addra = Blk_N_d1)and(llr_ram_wea = "1")then--start
					ctrl_in <= '1';
				    Blk_K_d2 <= Blk_K_d1;
				    iv_len_d2 <= iv_len_d1;
				    iv_rate_d2 <= iv_rate_d1;
				    max_iterate <= iv_iter_d1;
				elsif(fifo_ctrl_out_d3 = '0' and fifo_ctrl_out_d4 = '1' and iterate_loop < max_iterate )then--VNU(variable node update)
					ctrl_in <= '1';
				elsif(ctrl_out = '0' and ctrl_out_d1 = '1')then
					ctrl_in <= '0';	
				elsif(max_iterate = iterate_loop)then
					ctrl_in <= '0';
				else
					ctrl_in <= ctrl_in;	
				end if;
				
				if(ctrl_out = '1')then
				    llr_ram_addrb <= pos;
				elsif(decode_finish_en = '1')then
					llr_ram_addrb <= cnt_out;
				else
					llr_ram_addrb <= (others => '0');
				end if;
				llr_ram_doutb_d1 <= llr_ram_doutb;
				llr_ram_doutb_d2 <= llr_ram_doutb_d1;
				
			end if;
		end if;
	end process;

	param_fifo_ctrl : process(i_clk)
	begin	
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				fifo_din <= (others => '0');
				fifo_wr_en <= '0';
				fifo_rd_en <= '0';

				fifo_ctrl_out_d1 <= '0';
				fifo_ctrl_out_d2 <= '0';
				fifo_ctrl_out_d3 <= '0';
				fifo_ctrl_out_d4 <= '0';
				fifo_ctrl_out_d5 <= '0';
				fifo_ctrl_out_d6 <= '0';
				fifo_ctrl_out_d7 <= '0';
				fifo_revshift_d1 <= (others => '0');
				fifo_revshift_d2 <= (others => '0');
				fifo_revshift_d3 <= (others => '0');
				fifo_pos_d1      <= (others => '0');
				fifo_pos_d2      <= (others => '0');
				fifo_pos_d3      <= (others => '0');
				fifo_pos_d4      <= (others => '0');
				fifo_pos_d5      <= (others => '0');
				fifo_pos_d6      <= (others => '0');
				fifo_pos_en_d1   <= '0';
				fifo_pos_en_d2   <= '0';
				fifo_pos_en_d3   <= '0';
				fifo_pos_en_d4   <= '0';
				fifo_pos_en_d5   <= '0';
				fifo_pos_en_d6   <= '0';
			else
				-- fifo wr ctrl
				fifo_wr_en <= ctrl_out or ctrl_out_d1;
				fifo_din <= ctrl_out & revshift & pos & pos_en;
				-- fifo rd ctrl
				if(decode_processor_out_en = '1')then
					fifo_rd_en <= '1';
				elsif(fifo_empty = '1')then
					fifo_rd_en <= '0';
				end if;
				-- fifo rd_out delay to ctrl_out,revshift,pos and pos_en 
				fifo_ctrl_out_d1 <= fifo_dout(18);
				fifo_ctrl_out_d2 <= fifo_ctrl_out_d1;
				fifo_ctrl_out_d3 <= fifo_ctrl_out_d2;
				fifo_ctrl_out_d4 <= fifo_ctrl_out_d3;
				fifo_ctrl_out_d5 <= fifo_ctrl_out_d4;
				fifo_ctrl_out_d6 <= fifo_ctrl_out_d5;
				fifo_ctrl_out_d7 <= fifo_ctrl_out_d6;
				fifo_revshift_d1 <= fifo_dout(17 downto 9);
				fifo_revshift_d2 <= fifo_revshift_d1;
				fifo_revshift_d3 <= fifo_revshift_d2;
				fifo_pos_d1      <= fifo_dout(8 downto 1);
				fifo_pos_d2      <= fifo_pos_d1;
				fifo_pos_d3      <= fifo_pos_d2;
				fifo_pos_d4      <= fifo_pos_d3;
				fifo_pos_d5      <= fifo_pos_d4;
				fifo_pos_d6      <= fifo_pos_d5;
				fifo_pos_en_d1   <= fifo_dout(0);
				fifo_pos_en_d2   <= fifo_pos_en_d1;
				fifo_pos_en_d3   <= fifo_pos_en_d2;
				fifo_pos_en_d4   <= fifo_pos_en_d3;
				fifo_pos_en_d5   <= fifo_pos_en_d4;
				fifo_pos_en_d6   <= fifo_pos_en_d5;		
			end if;
		end if;
	end process;

	temp_sum_ram_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				pos_d1 <= (others => '0');
				pos_d2 <= (others => '0');
				pos_d3 <= (others => '0');
				pos_d4 <= (others => '0');
				pos_d5 <= (others => '0');
				pos_d6 <= (others => '0');
				pos_d7 <= (others => '0');
				pos_d8 <= (others => '0');
				pos_en_d1 <= '0';
				pos_en_d2 <= '0';
				pos_en_d3 <= '0';
				pos_en_d4 <= '0';
				pos_en_d5 <= '0';
				pos_en_d6 <= '0';

				temp_ram_wea 	   <= (others => '1');
				temp_ram_dina 	   <= (others => '0');
				temp_ram_addrb 	   <= (others => '0');
				temp_ram_doutb_d1  <= (others => '0');

				sum_ram_state      <= '0';
				sum_ram_wea_1      <= (others => '1');
				sum_ram_dina_1     <= (others => '0');
				sum_ram_addrb_1    <= (others => '0');
				sum_ram_doutb_1_d1 <= (others => '0');
				sum_ram_wea_2      <= (others => '1');
				sum_ram_dina_2     <= (others => '0');
				sum_ram_addrb_2    <= (others => '0');
				sum_ram_doutb_2_d1 <= (others => '0');
				
				if cnt = 0 then --add to clear the data in the nodedata_ram and Data_Sum_ram when i_rst = 1
					temp_ram_addra <= (others=>'0');
					sum_ram_addra_1 <= (others=>'0');
					sum_ram_addra_2 <= (others=>'0');
					cnt <= cnt + 1; 
				elsif(cnt >= 1 and cnt	 < 183)then
					temp_ram_addra <= temp_ram_addra + '1';
					sum_ram_addra_1 <= sum_ram_addra_1 + '1';
					sum_ram_addra_2 <= sum_ram_addra_2 + '1';
					cnt <= cnt + 1;
				elsif (cnt >= 183 and cnt	 < 850) then 	
					temp_ram_addra <= temp_ram_addra + '1';
					cnt <= cnt + 1;
				else
					temp_ram_addra <= (others=>'0');
					sum_ram_addra_1 <= (others=>'0');
					sum_ram_addra_2 <= (others=>'0');
				end if;	
				
				
				-- temp_ram_state <= '0';
				-- temp_ram_state_d1 <= '0';
				-- temp_ram_state_d2 <= '0';
				-- temp_ram_state_d3 <= '0';
				-- temp_ram_state_d4 <= '0';
				-- temp_ram_state_d5 <= '0';
				-- temp_ram_state_d6 <= '0';
				-- temp_ram_state_d7 <= '0';
				-- temp_ram_doutb_d1 <= (others => '0');
				-- temp_ram_doutb_d2 <= (others => '0');
				-- temp_ram_doutb_d3 <= (others => '0');
				-- temp_ram_doutb_d4 <= (others => '0');
				-- temp_ram_doutb_d5 <= (others => '0');
				iterate_loop <= (others => '0');

				-- temp_ram_rd_cnt <= (others => '0');

				-- bypass_we_2   <= '0'; 
                -- bypass_addra_2 <= (others => '0');
                -- bypass_dina_2 <= (others => '0');
			else
				pos_d1 <= pos;
				pos_d2 <= pos_d1;
				pos_d3 <= pos_d2;
				pos_d4 <= pos_d3;
				pos_d5 <= pos_d4;
				pos_d6 <= pos_d5;
				pos_d7 <= pos_d6;
				pos_d8 <= pos_d7;
				
				pos_en_d1 <= pos_en;
				pos_en_d2 <= pos_en_d1;
				pos_en_d3 <= pos_en_d2;
				pos_en_d4 <= pos_en_d3;
				pos_en_d5 <= pos_en_d4;
				pos_en_d6 <= pos_en_d5;

				temp_ram_doutb_d1  <= temp_ram_doutb;

				sum_ram_doutb_1_d1 <= sum_ram_doutb_1;
				sum_ram_doutb_2_d1 <= sum_ram_doutb_2;

				cnt <= 0;
				if(fifo_ctrl_out_d6 = '1')then		
					temp_ram_wea <= (others => '1');
					temp_ram_addra <= temp_ram_addra + '1';
					temp_ram_dina <= revshifter_out;
				else
					temp_ram_wea <= (others => '0');
					temp_ram_addra <= (others => '0');
					temp_ram_dina <= (others => '0');
				end if;
				
				-- if (ctrl_out_d8 = '0' and ctrl_out_d9 = '1')then
				-- 	temp_ram_rd_cnt <= temp_ram_addra;
				-- end if;
					
				
				if(iterate_loop < max_iterate)then
					if(ctrl_out = '1' )then
						temp_ram_addrb <= temp_ram_addrb + '1';
					else
						temp_ram_addrb <= (others => '0');
					end if;
				else
					temp_ram_addrb <= (others => '0');
				end if;
				
				-- temp_ram_doutb_d1 <= temp_ram_doutb(2160 downto 1081)&temp_ram_doutb(1079 downto 0);
				-- temp_ram_doutb_d2 <= temp_ram_doutb_d1;
				-- temp_ram_doutb_d3 <= temp_ram_doutb_d2;
				-- temp_ram_doutb_d4 <= temp_ram_doutb_d3;
				-- temp_ram_doutb_d5 <= temp_ram_doutb_d4;
				
				-- if(ctrl_out = '0' and ctrl_out_d1 = '1')then
				-- 	temp_ram_state <= not temp_ram_state;
				-- else
				-- 	temp_ram_state <= temp_ram_state;
				-- end if;
				
				-- temp_ram_state_d1 <= temp_ram_state;
				-- temp_ram_state_d2 <= temp_ram_state_d1;
				-- temp_ram_state_d3 <= temp_ram_state_d2;
				-- temp_ram_state_d4 <= temp_ram_state_d3;
				-- temp_ram_state_d5 <= temp_ram_state_d4;
				-- temp_ram_state_d6 <= temp_ram_state_d5;
				-- temp_ram_state_d7 <= temp_ram_state_d6;

				if(llr_ram_addra = Blk_N_d1)and(llr_ram_wea = "1")then
					iterate_loop <= "00000000";
				elsif(fifo_ctrl_out_d1 = '0' and fifo_ctrl_out_d2 = '1')then --after CNU finish and before ctrl_in begin
					iterate_loop <= iterate_loop + '1';
				else
					iterate_loop <= iterate_loop;
				end if;

				if(llr_ram_addra = Blk_N_d1)and(llr_ram_wea = "1")then
					sum_ram_state <= '0';
				elsif(fifo_ctrl_out_d6 = '0')and(fifo_ctrl_out_d7 = '1')then
					sum_ram_state <= not sum_ram_state;
				end if;

				-- -- Update bypass pipeline (T-2 data)
				-- bypass_we_2    <= sum_ram_wea_1(0); 
                -- bypass_addra_2 <= sum_ram_addra_1;
                -- bypass_dina_2  <= sum_ram_dina_1;

				if(fifo_ctrl_out_d6 = '1' and sum_ram_state = '0')then		
					sum_ram_wea_1 <= (others => '1');
					sum_ram_addra_1 <= fifo_pos_d6;
					for i in 359 downto 0 loop
                        -- Pri 1: T-1 RAW hazard (back-to-back)
                        if (sum_ram_wea_1(0) = '1' and fifo_pos_d6 = sum_ram_addra_1) then
                            -- Forward from T-1 (sum_ram_dina_1)
                            sum_ram_dina_1(11*i+10 downto 11*i) <= sum_ram_dina_1(11*i+10 downto 11*i) 
                                + (revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5 downto 6*i));
                        else
                            sum_ram_dina_1(11*i+10 downto 11*i) <= sum_ram_doutb_1(11*i+10 downto 11*i) 
                                + (revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5 downto 6*i));
                        end if;
                    end loop;
				else
					sum_ram_wea_1 <= (others => '0');
					sum_ram_addra_1 <= (others => '0');
					sum_ram_dina_1 <= (others => '0');
				end if;

				if(fifo_ctrl_out_d4 = '1' and sum_ram_state = '0')then 
					if(fifo_pos_en_d4 = '1')then
						sum_ram_addrb_1 <= fifo_pos_d4;
					else
						sum_ram_addrb_1 <= (others => '0');
					end if;
				elsif(ctrl_out = '1' and sum_ram_state = '1')then
					sum_ram_addrb_1 <= pos;
				elsif(decode_finish_en = '1' and sum_ram_state = '1')then
					sum_ram_addrb_1 <= cnt_out;
				else
					sum_ram_addrb_1 <= (others => '0');
				end if;

				if(fifo_ctrl_out_d6 = '1' and sum_ram_state = '1')then		
					sum_ram_wea_2 <= (others => '1');
					sum_ram_addra_2 <= fifo_pos_d6;
					for i in 359 downto 0 loop
                        -- Pri 1: T-1 RAW hazard (back-to-back)
                        if (sum_ram_wea_2(0) = '1' and fifo_pos_d6 = sum_ram_addra_2) then
                            -- Forward from T-1 (sum_ram_dina_1)
                            sum_ram_dina_2(11*i+10 downto 11*i) <= sum_ram_dina_2(11*i+10 downto 11*i) 
                                + (revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5 downto 6*i));
                        else
                            sum_ram_dina_2(11*i+10 downto 11*i) <= sum_ram_doutb_2(11*i+10 downto 11*i) 
                                + (revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5)&revshifter_out(6*i+5 downto 6*i));
                        end if;
                    end loop;
				else
					sum_ram_wea_2 <= (others => '0');
					sum_ram_addra_2 <= (others => '0');
					sum_ram_dina_2 <= (others => '0');
				end if;
				
				if(fifo_ctrl_out_d4 = '1' and sum_ram_state = '1')then 
					if(fifo_pos_en_d4 = '1')then
						sum_ram_addrb_2 <= fifo_pos_d4;
					else
						sum_ram_addrb_2 <= (others => '0');
					end if;
				elsif(ctrl_out = '1' and sum_ram_state = '0')then
					sum_ram_addrb_2 <= pos;
				elsif(decode_finish_en = '1' and sum_ram_state = '0')then
					sum_ram_addrb_2 <= cnt_out;
				else
					sum_ram_addrb_2 <= (others => '0');
				end if;
				
			end if;
		end if;
	end process;
	
	decode_processor_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				decode_processor_in 	<= (others => '0');
				decode_processor_in_en  <= '0';
				decode_processor_weight <= '0';
				-- decode_processor_out_d1 <= (others => '0');
				-- decode_processor_out_d2 <= (others => '0');
				-- decode_processor_out_d3 <= (others => '0');
				-- decode_processor_out_d4 <= (others => '0');
				-- decode_processor_out_d5 <= (others => '0');
			else
				decode_processor_in     <= fwdshifter_out;
				decode_processor_in_en  <= fwdshifter_out_en;
				decode_processor_weight <= weight_d8;
				
				-- decode_processor_out_d1 <= decode_processor_out;
				-- decode_processor_out_d2 <= decode_processor_out_d1;
				-- decode_processor_out_d3 <= decode_processor_out_d2;
				-- decode_processor_out_d4 <= decode_processor_out_d3;
				-- decode_processor_out_d5 <= decode_processor_out_d4;
				
			end if;
		end if;
	end process;
	
	
	variable_node_update_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				vnu_data <= (others => '0');
			else
--				if(ctrl_out_d2 = '1' and temp_ram_state_d2 = '0')then 
--					for i in 359 downto 0 loop
--						vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5 downto 6*i)) 
--						+ sum_ram_doutb_1(11*i+10 downto 11*i) 
--						- (temp_ram_doutb_d4(6*i+5)&temp_ram_doutb_d4(6*i+5)&temp_ram_doutb_d4(6*i+5)&temp_ram_doutb_d4(6*i+5)&temp_ram_doutb_d4(6*i+5)&temp_ram_doutb_d4(6*i+5 downto 6*i));
--					end loop;
--				elsif(decode_finish_en_d3 = '1')then--when decode finish 
--					for i in 359 downto 0 loop
--						vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5)&llr_ram_doutb(6*i+5 downto 6*i)) 
--							+ sum_ram_doutb_1(11*i+10 downto 11*i); 	
--					end loop;
--				else
--					vnu_data <= (others => '0');
--				end if;
               if(ctrl_out_d3 = '1')then 
               
                    if(workflag = '1') and (sum_ram_state = '1') then
                        for i in 359 downto 0 loop
                            vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5 downto 6*i)) 
                            + sum_ram_doutb_1_d1(11*i+10 downto 11*i) 
                            - (temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5 downto 6*i));
                        end loop;
                    elsif (workflag = '1') and (sum_ram_state = '0') then 
						for i in 359 downto 0 loop
                            vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5 downto 6*i)) 
                            + sum_ram_doutb_2_d1(11*i+10 downto 11*i) 
                            - (temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5)&temp_ram_doutb_d1(6*i+5 downto 6*i));
                        end loop;
					else
                        for i in 359 downto 0 loop
                            vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5 downto 6*i));
                        end loop;                        
                    end if;
                    
				elsif(decode_finish_en_d4 = '1')then--when decode finish 
				    if(workflag = '1') and (sum_ram_state = '1') then
                        for i in 359 downto 0 loop
                            vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5 downto 6*i)) 
                                + sum_ram_doutb_1_d1(11*i+10 downto 11*i); 	
                        end loop;
					elsif(workflag = '1') and (sum_ram_state = '0') then
						for i in 359 downto 0 loop
                            vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5 downto 6*i)) 
                                + sum_ram_doutb_2_d1(11*i+10 downto 11*i); 	
                        end loop;
                    else
                        for i in 359 downto 0 loop
                            vnu_data(11*i+10 downto 11*i) <= (llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5)&llr_ram_doutb_d1(6*i+5 downto 6*i));
                        end loop;                   
                    end if;
				else
					vnu_data <= (others => '0');
				end if;
			end if;
		end if;
	end process;
	
	decode_code_out_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				code_ram_wea <= (others => '1');
				code_ram_addra <= (others => '0');
				code_ram_dina <= (others => '0');
				decode_finish_en <= '0';
				decode_finish_en_d1 <= '0';
				decode_finish_en_d2 <= '0';
				decode_finish_en_d3 <= '0';
				decode_finish_en_d4 <= '0';
				cnt_out <= (others => '0');
				cnt_out_d1 <= (others => '0');
				cnt_out_d2 <= (others => '0');
				cnt_out_d3 <= (others => '0');
				cnt_out_d4 <= (others => '0');
				code_out_en <= '0';
				code_out_en_d1 <= '0';
				code_out_en_d2 <= '0';
				code_out_en_d3 <= '0';
				cnt_out_360 <= 0;
				cnt_out_360_d1 <= 0;
				cnt_out_360_d2 <= 0;
				o_data <= (others => '0');
				o_data_en <= '0';
                tmp_data <= (others => '0');
                tmp_data_en <= '0';
				code_ram_douta_d1 <= (others => '0');
				Blk_K_d3 <= (others => '0');
				Blk_K_d4 <= (others => '0');
			else
				if(iterate_loop = max_iterate)and(fifo_ctrl_out_d6 = '0')and(fifo_ctrl_out_d7 = '1')then
					decode_finish_en <= '1';
				    Blk_K_d3 <= Blk_K_d2;
				elsif(cnt_out = Blk_K_d3)then
					decode_finish_en <= '0';
				end if;
				
				decode_finish_en_d1 <= decode_finish_en; 
				decode_finish_en_d2 <= decode_finish_en_d1; 
				decode_finish_en_d3 <= decode_finish_en_d2; 
				decode_finish_en_d4 <= decode_finish_en_d3; 
				
				code_ram_douta_d1 <= code_ram_douta;
				
				if(decode_finish_en_d3 = '0' and decode_finish_en_d4 = '1')then
					code_out_en <= '1';
				    Blk_K_d4 <= Blk_K_d3;
				elsif(cnt_out_360 = 43 and code_ram_addra = Blk_K_d4)then--358
					code_out_en <= '0';
				end if;
				
				code_out_en_d1 <= code_out_en;
				code_out_en_d2 <= code_out_en_d1;
				code_out_en_d3 <= code_out_en_d2;
				
				if(decode_finish_en = '1')then
					cnt_out <= cnt_out + '1';
				else
					cnt_out <= (others => '0');
				end if;
				
				cnt_out_d1 <= cnt_out;
				cnt_out_d2 <= cnt_out_d1;
				cnt_out_d3 <= cnt_out_d2;
				cnt_out_d4 <= cnt_out_d3;
				
				if(decode_finish_en_d4 = '1')then
					code_ram_wea <= "1";
					code_ram_addra <= cnt_out_d4;
					for i in 359 downto 0 loop
						code_ram_dina(i) <= vnu_data(11*i+10);
					end loop;
				elsif(code_out_en = '1' and code_out_en_d1 = '0')then 
					code_ram_wea <= (others => '0');
					code_ram_addra <= "00000001";
					code_ram_dina <= (others => '0');
				elsif(cnt_out_360 = 44)then--359
					code_ram_wea <= (others => '0');
					code_ram_addra <= code_ram_addra + '1';
					code_ram_dina <= (others => '0');
				elsif(cnt_out_360 = 44 and code_ram_addra = Blk_K_d4)then--359
					code_ram_wea <= (others => '0');
					code_ram_addra <= (others => '0');
					code_ram_dina <= (others => '0');
				else
					code_ram_wea <= (others => '0');
					code_ram_addra <= code_ram_addra;
					code_ram_dina <= (others => '0');
				end if;
				
				if(code_out_en_d1 = '1')then
					if(cnt_out_360 = 44)then--360/8-1
						cnt_out_360 <= 0;
					else
						cnt_out_360 <= cnt_out_360 + 1;
					end if;
				else
					cnt_out_360 <= 0;
				end if;
				cnt_out_360_d1 <= cnt_out_360;
				cnt_out_360_d2 <= cnt_out_360_d1;
				if(code_out_en_d3 = '1')then 
					tmp_data <= code_ram_douta_d1(cnt_out_360_d2*8+7 downto cnt_out_360_d2*8);
				else
					tmp_data <= (others => '0');
				end if;
				tmp_data_en <= code_out_en_d3;								
			end if;
            o_data(0) <= tmp_data(7);
            o_data(1) <= tmp_data(6);
            o_data(2) <= tmp_data(5);
            o_data(3) <= tmp_data(4);
            o_data(4) <= tmp_data(3);
            o_data(5) <= tmp_data(2);
            o_data(6) <= tmp_data(1);
            o_data(7) <= tmp_data(0);
            o_data_en <= tmp_data_en;
		end if;
	end process;
	
	barrel_fwdshifter_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				fwdshift_d1 <= (others => '0');
				fwdshift_d2 <= (others => '0');
				fwdshift_d3 <= (others => '0');
				fwdshift_d4 <= (others => '0');
				fwdshift_d5 <= (others => '0');
				fwdshifter_in <= (others => '0');
				
				revshifter_in <= (others => '0');

				-- fwdshifter_temp1 <= (others => '0');
				-- fwdshifter_temp2 <= (others => '0');
				-- fwdshift87_d1 <= (others => '0');
				-- fwdshift87_d2 <= (others => '0');
				-- fwdshift87_d3 <= (others => '0');
				-- fwdshift87_d4 <= (others => '0');
				-- fwdshift87_d5 <= (others => '0');
				-- fwdshift64_d1 <= (others => '0');
				-- fwdshift64_d2 <= (others => '0');
				-- fwdshift64_d3 <= (others => '0');
				-- fwdshift64_d4 <= (others => '0');
				-- fwdshift64_d5 <= (others => '0');
				-- fwdshift64_d6 <= (others => '0');
				-- fwdshift30_d1 <= (others => '0');
				-- fwdshift30_d2 <= (others => '0');
				-- fwdshift30_d3 <= (others => '0');
				-- fwdshift30_d4 <= (others => '0');
				-- fwdshift30_d5 <= (others => '0');
				-- fwdshift30_d6 <= (others => '0');
				-- fwdshift30_d7 <= (others => '0');
				weight_d1 <= '0';
				weight_d2 <= '0';
				weight_d3 <= '0';
				weight_d4 <= '0';
				weight_d5 <= '0';
				weight_d6 <= '0';
				weight_d7 <= '0';
				weight_d8 <= '0';
			else
				fwdshift_d1 <= fwdshift;
				fwdshift_d2 <= fwdshift_d1;
				fwdshift_d3 <= fwdshift_d2;
				fwdshift_d4 <= fwdshift_d3;
				fwdshift_d5 <= fwdshift_d4;

				-- fwdshift87_d1 <= fwdshift(8 downto 7);
				-- fwdshift87_d2 <= fwdshift87_d1;
				-- fwdshift87_d3 <= fwdshift87_d2;
				-- fwdshift87_d4 <= fwdshift87_d3;
				-- fwdshift87_d5 <= fwdshift87_d4;
				
				-- fwdshift64_d1 <= fwdshift(6 downto 4);
				-- fwdshift64_d2 <= fwdshift64_d1;
				-- fwdshift64_d3 <= fwdshift64_d2;
				-- fwdshift64_d4 <= fwdshift64_d3;
				-- fwdshift64_d5 <= fwdshift64_d4;
				-- fwdshift64_d6 <= fwdshift64_d5;
				
				-- fwdshift30_d1 <= fwdshift(3 downto 0);
				-- fwdshift30_d2 <= fwdshift30_d1;
				-- fwdshift30_d3 <= fwdshift30_d2;
				-- fwdshift30_d4 <= fwdshift30_d3;
				-- fwdshift30_d5 <= fwdshift30_d4;
				-- fwdshift30_d6 <= fwdshift30_d5;
				-- fwdshift30_d7 <= fwdshift30_d6;
				
				weight_d1 <= weight;
				weight_d2 <= weight_d1;
				weight_d3 <= weight_d2;
				weight_d4 <= weight_d3;
				weight_d5 <= weight_d4;
				weight_d6 <= weight_d5;
				weight_d7 <= weight_d6;
				weight_d8 <= weight_d7;
				
				--forward barrel shifter before CNU in
				if(ctrl_out_d4 = '1')then -- variable node update
				-- change:When initializing LLR input address 181 (bubble), assign value 31 instead of 0
					if(pos_d4 = "10110101")then
						for i in 359 downto 0 loop 
							fwdshifter_in(i*6+5 downto 6*i) <= "011111";
						end loop;
					elsif(iterate_loop = "00000000")then -- init iteration
						fwdshifter_in <= llr_ram_doutb_d2;
					else 								 -- other iteration 
						for i in 359 downto 0 loop 
							if(vnu_data(11*i+10 downto 11*i) <= "00000011111" or vnu_data(11*i+10 downto 11*i) > "11111100000" )then
								fwdshifter_in(6*i+5 downto 6*i) <= vnu_data(11*i+5 downto 11*i);
							else
								fwdshifter_in(6*i+5 downto 6*i) <= vnu_data(11*i+10)&(not vnu_data(11*i+10))&(not vnu_data(11*i+10))&(not vnu_data(11*i+10))&(not vnu_data(11*i+10))&vnu_data(11*i+10);
							end if;	
						end loop;
					end if;
				else
					fwdshifter_in <= (others => '0');
				end if;

				-- reverse barrel shifter after CNU out
				if(fifo_ctrl_out_d2 = '1')then
					revshifter_in <= decode_processor_out;
				else
					revshifter_in <= (others => '0');
				end if;

				
-- --<<<<<<<< 130M	
-- 			case fwdshift87_d5 is
-- 				when "00" => fwdshifter_temp1 <= fwdshifter_in;
-- 				when "01" => fwdshifter_temp1 <= fwdshifter_in(539 downto 0)&fwdshifter_in(2159 downto 540);
-- 				when "10" => fwdshifter_temp1 <= fwdshifter_in(1079 downto 0)&fwdshifter_in(2159 downto 1080);
-- 				when others => fwdshifter_temp1 <= fwdshifter_in(1619 downto 0)&fwdshifter_in(2159 downto 1620);
-- 			end case;	


			
-- 			case fwdshift64_d6 is
-- 				when "000" => fwdshifter_temp2 <= fwdshifter_temp1(2153 downto 0)&"011111";
-- 				when "001" => fwdshifter_temp2 <= fwdshifter_temp1;
-- 				when "010" => fwdshifter_temp2 <= fwdshifter_temp1(89 downto 0)&fwdshifter_temp1(2159 downto 90);
-- 				when "011" => fwdshifter_temp2 <= fwdshifter_temp1(179 downto 0)&fwdshifter_temp1(2159 downto 180);
-- 				when "100" => fwdshifter_temp2 <= fwdshifter_temp1(269 downto 0)&fwdshifter_temp1(2159 downto 270);
-- 				when "101" => fwdshifter_temp2 <= fwdshifter_temp1(359 downto 0)&fwdshifter_temp1(2159 downto 360);
-- 				when "110" => fwdshifter_temp2 <= fwdshifter_temp1(449 downto 0)&fwdshifter_temp1(2159 downto 450);
-- 				when others => fwdshifter_temp2 <= "000000"&fwdshifter_temp1(2159 downto 6);
-- 			end case;

-- 			case fwdshift30_d7 is
-- 				when "0000" => fwdshifter_out <= fwdshifter_temp2;
-- 				when "0001" => fwdshifter_out <= fwdshifter_temp2(5 downto 0)&fwdshifter_temp2(2159 downto 6);
-- 				when "0010" => fwdshifter_out <= fwdshifter_temp2(11 downto 0)&fwdshifter_temp2(2159 downto 12);
-- 				when "0011" => fwdshifter_out <= fwdshifter_temp2(17 downto 0)&fwdshifter_temp2(2159 downto 18);
-- 				when "0100" => fwdshifter_out <= fwdshifter_temp2(23 downto 0)&fwdshifter_temp2(2159 downto 24);
-- 				when "0101" => fwdshifter_out <= fwdshifter_temp2(29 downto 0)&fwdshifter_temp2(2159 downto 30);
-- 				when "0110" => fwdshifter_out <= fwdshifter_temp2(35 downto 0)&fwdshifter_temp2(2159 downto 36);
-- 				when "0111" => fwdshifter_out <= fwdshifter_temp2(41 downto 0)&fwdshifter_temp2(2159 downto 42);
-- 				when "1000" => fwdshifter_out <= fwdshifter_temp2(47 downto 0)&fwdshifter_temp2(2159 downto 48);
-- 				when "1001" => fwdshifter_out <= fwdshifter_temp2(53 downto 0)&fwdshifter_temp2(2159 downto 54);
-- 				when "1010" => fwdshifter_out <= fwdshifter_temp2(59 downto 0)&fwdshifter_temp2(2159 downto 60);
-- 				when "1011" => fwdshifter_out <= fwdshifter_temp2(65 downto 0)&fwdshifter_temp2(2159 downto 66);
-- 				when "1100" => fwdshifter_out <= fwdshifter_temp2(71 downto 0)&fwdshifter_temp2(2159 downto 72);
-- 				when "1101" => fwdshifter_out <= fwdshifter_temp2(77 downto 0)&fwdshifter_temp2(2159 downto 78);
-- 				when "1110" => fwdshifter_out <= fwdshifter_temp2(83 downto 0)&fwdshifter_temp2(2159 downto 84);
-- 				when others => fwdshifter_out <= fwdshifter_temp2(89 downto 0)&fwdshifter_temp2(2159 downto 90);
-- 			end case;

			end if;
		end if;
	end process;	
	
		-- =========================================================================
-- ����ר�ã����м��ź�д�� TXT �ļ� (�ۺ�ʱ���Զ�����)
-- =========================================================================
-- synthesis translate_off
-- debug_dump_process : process(i_clk)
--     -- ����Ҫ���ɵ� txt �ļ� (�������к����ǻ��������� Vivado/Modelsim ���̸�Ŀ¼��)
--     file f_llr       : text open write_mode is "D:/wwc_prj/vivado_vhdl/ldpc_matlab/tmp_code_decode/dump_01_llr_ram.txt";
--     file f_vnu       : text open write_mode is "D:/wwc_prj/vivado_vhdl/ldpc_matlab/tmp_code_decode/dump_02_vnu_data.txt";
--     file f_fwdshifter   : text open write_mode is "D:/wwc_prj/vivado_vhdl/ldpc_matlab/tmp_code_decode/dump_03_fwdshifter_out.txt";
--     file f_cnu       : text open write_mode is "D:/wwc_prj/vivado_vhdl/ldpc_matlab/tmp_code_decode/dump_04_cnu_out.txt";
--     file f_sum       : text open write_mode is "D:/wwc_prj/vivado_vhdl/ldpc_matlab/tmp_code_decode/dump_05_sum_ram.txt";
--     file f_temp      : text open write_mode is "D:/wwc_prj/vivado_vhdl/ldpc_matlab/tmp_code_decode/dump_06_temp_ram.txt";

--     variable l_llr     : line;
--     variable l_vnu     : line;
--     variable l_fwdshifter : line;
--     variable l_cnu     : line;
--     variable l_sum     : line;
--     variable l_temp    : line;
-- begin
--     if rising_edge(i_clk) then
--         if i_rst = '0' then
            
--             -- 1. ץȡ LLR RAM �������� (������ VNU �����ͬһ��ץȡ)
--             -- �뽫 ctrl_out_d3 �滻Ϊ��ʵ�ʴ����� VNU ������Ч����һ��ʹ��
--             if ((ctrl_out_d3 = '1' and temp_ram_state_d3 = '0') or decode_finish_en_d4 = '1') then 
--                 hwrite(l_llr, llr_ram_doutb_d1); -- ��16����д��
--                 writeline(f_llr, l_llr);
--             end if;

--             -- 2. ץȡ VNU ������ (���� LLR+SUM-TEMP �� 3960bit)
--             if ((ctrl_out_d4 = '1' and temp_ram_state_d4 = '0') or decode_finish_en_d4 = '1') then 
--                 hwrite(l_vnu, vnu_data);
--                 writeline(f_vnu, l_vnu);
--             end if;

--             -- 3. ץȡ fwdShifter Out ��λ��� (����/������ɣ�����ץ��һ��)
--             if (ctrl_out_d8 = '1') then 
--                 hwrite(l_fwdshifter, fwdshifter_out);
--                 writeline(f_fwdshifter, l_fwdshifter);
--             end if;

--             -- 4. ץȡ CNU У��ڵ���½��
--             if (ctrl_out_d4 = '1' and temp_ram_state_d3 = '1') then 
--                 hwrite(l_cnu, decode_processor_out_d5);
--                 writeline(f_cnu, l_cnu);
--             end if;

--             -- 5. ץȡ SUM RAM �������� (���� VNU �ۼ�ǰ)
--             if ((ctrl_out_d3 = '1' and temp_ram_state_d3 = '0') or decode_finish_en_d4 = '1') then 
--                 hwrite(l_sum, sum_ram_doutb_1_d1);
--                 writeline(f_sum, l_sum);
--             end if;

--             -- 6. ץȡ TEMP RAM �������� (����ؼ�����ʷ��Ϣ)
--             if (ctrl_out_d3 = '1' and temp_ram_state_d3 = '0') then 
--                 hwrite(l_temp, temp_ram_doutb_d5);
--                 writeline(f_temp, l_temp);
--             end if;

--         end if;
--     end if;
-- end process;
-- synthesis translate_on
-- =========================================================================

end Behavioral;