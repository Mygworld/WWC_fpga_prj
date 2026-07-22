----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:53:37 07/17/2026 
-- Design Name: 
-- Module Name:    ldpc_decode_barrel_shifter_360 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
-- 360-lane / 6-bit-per-lane barrel shifter used by the layered decoder.
--
-- This is the standalone version of the three-stage barrel-shift pipeline used in
-- new_dvb_rx_ldpc_decode_8path.vhd.  It is used for both:
--   1) forward shift before CNU input
--   2) reverse shift after CNU output
--
-- Latency: 5 clocks from i_valid/iv_data/iv_shift to o_valid/ov_data.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ldpc_decode_barrel_shifter_360 is
    Port (
        i_clk    : in  STD_LOGIC;
        i_rst    : in  STD_LOGIC;
        i_valid  : in  STD_LOGIC;
        iv_shift : in  STD_LOGIC_VECTOR(8 downto 0);
        iv_data  : in  STD_LOGIC_VECTOR(2159 downto 0);
        o_valid  : out STD_LOGIC;
        ov_data  : out STD_LOGIC_VECTOR(2159 downto 0)
    );
end ldpc_decode_barrel_shifter_360;

architecture Behavioral of ldpc_decode_barrel_shifter_360 is

    signal valid_d1, valid_d2, valid_d3 : STD_LOGIC := '0';
    signal sh64_d1                      : STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
    signal sh30_d1, sh30_d2             : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal stage1, stage2, stage3       : STD_LOGIC_VECTOR(2159 downto 0) := (others => '0');

begin

    ov_data  <= stage3;
    o_valid  <= valid_d3;

    process(i_clk)
    begin
        if (i_clk'event and i_clk = '1') then
            if (i_rst = '1') then
                valid_d1 <= '0';
                valid_d2 <= '0';
                valid_d3 <= '0';
                sh64_d1  <= (others => '0');
                sh30_d1  <= (others => '0');
                sh30_d2  <= (others => '0');
                stage1   <= (others => '0');
                stage2   <= (others => '0');
                stage3   <= (others => '0');
            else
                valid_d1 <= i_valid;
                valid_d2 <= valid_d1;
                valid_d3 <= valid_d2;

                sh64_d1 <= iv_shift(6 downto 4);
                sh30_d1 <= iv_shift(3 downto 0);
                sh30_d2 <= sh30_d1;

                -- Stage 1: 0/90/180/270 lane rotation.
                case iv_shift(8 downto 7) is
                    when "00"   => stage1 <= iv_data;
                    when "01"   => stage1 <= iv_data(539 downto 0)  & iv_data(2159 downto 540);
                    when "10"   => stage1 <= iv_data(1079 downto 0) & iv_data(2159 downto 1080);
                    when others => stage1 <= iv_data(1619 downto 0) & iv_data(2159 downto 1620);
                end case;

                -- Stage 2: 15-lane step.  The "000" and "111" cases keep the
                -- same boundary-fill behavior as the existing decoder.
                case sh64_d1 is
                    when "000"  => stage2 <= stage1(2153 downto 0) & "011111";
                    when "001"  => stage2 <= stage1;
                    when "010"  => stage2 <= stage1(89 downto 0)  & stage1(2159 downto 90);
                    when "011"  => stage2 <= stage1(179 downto 0) & stage1(2159 downto 180);
                    when "100"  => stage2 <= stage1(269 downto 0) & stage1(2159 downto 270);
                    when "101"  => stage2 <= stage1(359 downto 0) & stage1(2159 downto 360);
                    when "110"  => stage2 <= stage1(449 downto 0) & stage1(2159 downto 450);
                    when others => stage2 <= "000000" & stage1(2159 downto 6);
                end case;

                -- Stage 3: 0..15 lane rotation.
                case sh30_d2 is
                    when "0000" => stage3 <= stage2;
                    when "0001" => stage3 <= stage2(5 downto 0)   & stage2(2159 downto 6);
                    when "0010" => stage3 <= stage2(11 downto 0)  & stage2(2159 downto 12);
                    when "0011" => stage3 <= stage2(17 downto 0)  & stage2(2159 downto 18);
                    when "0100" => stage3 <= stage2(23 downto 0)  & stage2(2159 downto 24);
                    when "0101" => stage3 <= stage2(29 downto 0)  & stage2(2159 downto 30);
                    when "0110" => stage3 <= stage2(35 downto 0)  & stage2(2159 downto 36);
                    when "0111" => stage3 <= stage2(41 downto 0)  & stage2(2159 downto 42);
                    when "1000" => stage3 <= stage2(47 downto 0)  & stage2(2159 downto 48);
                    when "1001" => stage3 <= stage2(53 downto 0)  & stage2(2159 downto 54);
                    when "1010" => stage3 <= stage2(59 downto 0)  & stage2(2159 downto 60);
                    when "1011" => stage3 <= stage2(65 downto 0)  & stage2(2159 downto 66);
                    when "1100" => stage3 <= stage2(71 downto 0)  & stage2(2159 downto 72);
                    when "1101" => stage3 <= stage2(77 downto 0)  & stage2(2159 downto 78);
                    when "1110" => stage3 <= stage2(83 downto 0)  & stage2(2159 downto 84);
                    when others => stage3 <= stage2(89 downto 0)  & stage2(2159 downto 90);
                end case;

            end if;
        end if;
    end process;

end Behavioral;
