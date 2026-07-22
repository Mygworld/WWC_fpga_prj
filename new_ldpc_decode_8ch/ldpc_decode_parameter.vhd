----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:03:14 06/26/2015 
-- Design Name: 
-- Module Name:    ldpc_decode_parameter - Behavioral 
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

entity ldpc_decode_parameter is
    Port ( i_clk 	   : in  STD_LOGIC;
           i_rst 	   : in  STD_LOGIC;
           iv_len 	   : in  STD_LOGIC_VECTOR (1 downto 0);
           iv_rate 	   : in  STD_LOGIC_VECTOR (5 downto 0);
           i_ctrl_en   : in  STD_LOGIC;
		   o_pos_en    : out  STD_LOGIC;
           o_weight    : out  STD_LOGIC;
           ov_pos 	   : out  STD_LOGIC_VECTOR (7 downto 0);
           ov_fwdshift : out  STD_LOGIC_VECTOR (8 downto 0);
		   ov_revshift : out  STD_LOGIC_VECTOR (8 downto 0);
           o_ctrl_en   : out  STD_LOGIC);
end ldpc_decode_parameter;

architecture Behavioral of ldpc_decode_parameter is

	COMPONENT ldpc_decode_parameter_rom
	  PORT (
		 clka : IN STD_LOGIC;
		 rsta : IN STD_LOGIC;
		 ena : IN STD_LOGIC;
		 addra : IN STD_LOGIC_VECTOR(14 DOWNTO 0);
		 douta : OUT STD_LOGIC_VECTOR(18 DOWNTO 0)
	  );
	END COMPONENT;
	
	signal ena : std_logic;
	signal addra : std_logic_vector(14 downto 0);
	signal douta : std_logic_vector(18 downto 0);
	signal i_ctrl_en_d1 : std_logic;
	signal weight_d1 : std_logic;

	-- This function packages one combinational transform for readability and
    -- consistency.  Synthesis normally inlines it; it is not a resource-saving
    -- software subroutine.
    function reverse_shift_code(raw_shift : STD_LOGIC_VECTOR(8 downto 0))
        return STD_LOGIC_VECTOR is
        variable rev_shift : STD_LOGIC_VECTOR(8 downto 0);
    begin
        -- Same inverse code as the reverse branch of ldpc_decode_parameter.
        rev_shift(6 downto 4) := not raw_shift(6 downto 4);
        if raw_shift(6 downto 4) = "000" then
            rev_shift(8 downto 7) := raw_shift(8 downto 7);
            rev_shift(3 downto 0) := raw_shift(3 downto 0);
        else
            rev_shift(8 downto 7) := not raw_shift(8 downto 7);
            rev_shift(3 downto 0) := not raw_shift(3 downto 0);
        end if;
        return rev_shift;
    end function;

begin

	parameter_rom : ldpc_decode_parameter_rom
	  PORT MAP (
		 clka => i_clk,
		 rsta => i_rst,
		 ena => '1',
		 addra => addra,
		 douta => douta
	  );
	  
	rom_ctrl : process(i_clk)
	begin
		if(i_clk'event and i_clk = '1')then
			if(i_rst = '1')then
				ena <= '0';
				addra <= (others => '1');
				o_pos_en <= '0';
				o_weight <= '0';
				ov_pos <= (others => '0');
				ov_fwdshift <= (others => '0');
				ov_revshift <= (others => '0');
				o_ctrl_en <= '0';
				i_ctrl_en_d1 <= '0';
				weight_d1 <= '0';
			else
				i_ctrl_en_d1 <= i_ctrl_en;
				
				if(i_ctrl_en_d1 = '1')then
					addra <= addra + '1';
					ena <= '1';
					o_weight <= douta(18);
					weight_d1 <= douta(18);
					o_pos_en <= douta(17);
					ov_pos <= douta(16 downto 9);
					ov_fwdshift <= douta(8 downto 0);
					ov_revshift <= reverse_shift_code(douta(8 downto 0));
					o_ctrl_en   <= (douta(18) or weight_d1);
				else
					ena <= '0';
					o_pos_en <= '0';
					o_weight <= '0';
					ov_pos <= (others => '0');
					ov_fwdshift <= (others => '0');
					ov_revshift <= (others => '0');
					o_ctrl_en <= '0';
					if(iv_len = "00")then
						case iv_rate is
						--DVB-S2X
							when "000000" => addra <= (others => '1');--2/9
							when "000001" => addra <= conv_std_logic_vector(564,15);--13/45
							when "000010" => addra <= conv_std_logic_vector(1209,15);--9/20
							when "000011" => addra <= conv_std_logic_vector(1907,15);--11/20
							when "000100" => addra <= conv_std_logic_vector(2641,15);--26/45
							when "000101" => addra <= conv_std_logic_vector(3406,15);--28/45
							when "000110" => addra <= conv_std_logic_vector(4091,15);--23/36
							when "000111" => addra <= conv_std_logic_vector(4746,15);--25/36
							when "001000" => addra <= conv_std_logic_vector(5466,15);--13/18
							when "001001" => addra <= conv_std_logic_vector(6171,15);--7/9
							when "001010" => addra <= conv_std_logic_vector(6896,15);--90/180
							when "001011" => addra <= conv_std_logic_vector(7621,15);--96/180
							when "001100" => addra <= conv_std_logic_vector(8382,15);--100/180
							when "001101" => addra <= conv_std_logic_vector(9107,15);--104/180
							when "001110" => addra <= conv_std_logic_vector(9872,15);--116/180
							when "001111" => addra <= conv_std_logic_vector(10645,15);--124/180
							when "010000" => addra <= conv_std_logic_vector(11434,15);--128/180
							when "010001" => addra <= conv_std_logic_vector(12219,15);--132/180
							when "010010" => addra <= conv_std_logic_vector(12992,15);--135/180
							when "010011" => addra <= conv_std_logic_vector(13762,15);--140/180
							when "010100" => addra <= conv_std_logic_vector(14567,15);--154/180
							when "010101" => addra <= conv_std_logic_vector(15352,15);--18/30
							when "010110" => addra <= conv_std_logic_vector(16149,15);--20/30
							when "010111" => addra <= conv_std_logic_vector(16994,15);--22/30
						--DVB-S2
							when "011000" => addra <= conv_std_logic_vector(19966,15);--1/4
							when "011001" => addra <= conv_std_logic_vector(20511,15);--1/3
							when "011010" => addra <= conv_std_logic_vector(21116,15);--2/5
							when "011011" => addra <= conv_std_logic_vector(21769,15);--1/2
							when "011100" => addra <= conv_std_logic_vector(22404,15);--3/5
							when "011101" => addra <= conv_std_logic_vector(23201,15);--2/3
							when "011110" => addra <= conv_std_logic_vector(23806,15);--3/4
							when "011111" => addra <= conv_std_logic_vector(24441,15);--4/5
							when "100000" => addra <= conv_std_logic_vector(25094,15);--5/6
							when "100001" => addra <= conv_std_logic_vector(25759,15);--8/9
							when "100010" => addra <= conv_std_logic_vector(26304,15);--9/10
							when others => addra <= (others => '1');
						end case;	
					elsif(iv_len = "01")then--32400
						case iv_rate is
							when "000000" => addra <= conv_std_logic_vector(17815,15);--1/5
							when "000001" => addra <= conv_std_logic_vector(18108,15);--11/45
							when "000010" => addra <= conv_std_logic_vector(18385,15);--1/3
							when others => addra <= (others => '1');
						end case;	
					else--16200
						case iv_rate is
						--DVB-S2X
							when "000000" => addra <= conv_std_logic_vector(18690,15);--11/45
							when "000001" => addra <= conv_std_logic_vector(18831,15);--4/15
							when "000010" => addra <= conv_std_logic_vector(19001,15);--14/45
							when "000011" => addra <= conv_std_logic_vector(19161,15);--7/15
							when "000100" => addra <= conv_std_logic_vector(19382,15);--8/15
							when "000101" => addra <= conv_std_logic_vector(19597,15);--26/45
							when "000110" => addra <= conv_std_logic_vector(19792,15);--32/45				
						--DVB-S2
							when "000111" => addra <= conv_std_logic_vector(26849,15);--1/5
							when "001000" => addra <= conv_std_logic_vector(26998,15);--1/3
							when "001001" => addra <= conv_std_logic_vector(27153,15);--2/5
							when "001010" => addra <= conv_std_logic_vector(27320,15);--4/9
							when "001011" => addra <= conv_std_logic_vector(27500,15);--3/5
							when "001100" => addra <= conv_std_logic_vector(27703,15);--2/3
							when "001101" => addra <= conv_std_logic_vector(27858,15);--11/15
							when "001110" => addra <= conv_std_logic_vector(28019,15);--7/9
							when "001111" => addra <= conv_std_logic_vector(28154,15);--37/45
							when "010000" => addra <= conv_std_logic_vector(28311,15);--8/9
							when others => addra <= (others => '1');
						end case;	
					end if;	

				end if;
				
			end if; 
		end if;
	end process;
		  
end Behavioral;