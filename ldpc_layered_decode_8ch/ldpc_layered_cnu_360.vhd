----------------------------------------------------------------------------------
-- 360-lane layered min-sum check-node unit.
--
-- One layer is collected a slot per clock.  Dummy slots keep the schedule
-- timing but do not participate in the minimum/sign calculation.  After the
-- row-end slot has been accepted, one R_new vector is returned per real edge
-- and in the same order as the real input edges.
--
-- The magnitude normalization is floor(minimum * 28 / 32), matching the
-- fixed-point layered MATLAB model used by this project.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ldpc_layered_cnu_360 is
    Port (
        i_clk          : in  STD_LOGIC;
        i_rst          : in  STD_LOGIC;
        i_slot_valid   : in  STD_LOGIC;
        i_edge_valid   : in  STD_LOGIC;
        i_dummy        : in  STD_LOGIC;
        i_row_end      : in  STD_LOGIC;
        iv_v2c_chk     : in  STD_LOGIC_VECTOR(2159 downto 0);
        o_r_valid      : out STD_LOGIC;
        o_r_edge_valid : out STD_LOGIC;
        ov_r_new_chk   : out STD_LOGIC_VECTOR(2159 downto 0)
    );
end ldpc_layered_cnu_360;

architecture Behavioral of ldpc_layered_cnu_360 is

    constant C_Z              : integer := 360;
    constant C_MAX_ROW_EDGES  : integer := 30;

    type mag_array_t is array(0 to C_Z-1) of STD_LOGIC_VECTOR(4 downto 0);
    type idx_array_t is array(0 to C_Z-1) of STD_LOGIC_VECTOR(4 downto 0);
    type edge_sign_mem_t is array(0 to C_MAX_ROW_EDGES-1) of
        STD_LOGIC_VECTOR(C_Z-1 downto 0);

    signal min1_r       : mag_array_t;
    signal min2_r       : mag_array_t;
    signal min_index_r  : idx_array_t;
    signal total_sign_r : STD_LOGIC_VECTOR(C_Z-1 downto 0) := (others => '0');
    signal edge_sign_mem : edge_sign_mem_t;

    signal collect_active : STD_LOGIC := '0';
    signal real_edge_count : integer range 0 to C_MAX_ROW_EDGES := 0;

    signal output_active     : STD_LOGIC := '0';
    signal output_edge_count : integer range 0 to C_MAX_ROW_EDGES := 0;
    signal output_index      : integer range 0 to C_MAX_ROW_EDGES-1 := 0;

begin

    cnu_pipeline_pro : process(i_clk)
        variable min1_v       : STD_LOGIC_VECTOR(4 downto 0);
        variable min2_v       : STD_LOGIC_VECTOR(4 downto 0);
        variable min_index_v  : STD_LOGIC_VECTOR(4 downto 0);
        variable total_sign_v : STD_LOGIC;
        variable input_sign_v : STD_LOGIC;
        variable input_mag_v  : STD_LOGIC_VECTOR(4 downto 0);
        variable selected_mag_v : STD_LOGIC_VECTOR(4 downto 0);
        variable scaled10_v     : STD_LOGIC_VECTOR(9 downto 0);
        variable scaled_mag_v   : STD_LOGIC_VECTOR(4 downto 0);
        variable output_sign_v  : STD_LOGIC;
        variable edge_total_v   : integer range 0 to C_MAX_ROW_EDGES;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                collect_active   <= '0';
                real_edge_count  <= 0;
                output_active    <= '0';
                output_edge_count <= 0;
                output_index     <= 0;
                total_sign_r     <= (others => '0');
                o_r_valid        <= '0';
                o_r_edge_valid   <= '0';
                ov_r_new_chk     <= (others => '0');
                for lane in 0 to C_Z-1 loop
                    min1_r(lane)      <= (others => '1');
                    min2_r(lane)      <= (others => '1');
                    min_index_r(lane) <= (others => '0');
                end loop;
            else
                o_r_valid      <= '0';
                o_r_edge_valid <= '0';

                -- Output one real edge per clock.  All values used here were
                -- finalized by the preceding row-end input clock.
                if output_active = '1' then
                    for lane in 0 to C_Z-1 loop
                        if min_index_r(lane) =
                           conv_std_logic_vector(output_index, min_index_r(lane)'length) then
                            selected_mag_v := min2_r(lane);
                        else
                            selected_mag_v := min1_r(lane);
                        end if;

                        -- selected_mag * 28 = selected_mag * (32 - 4).
                        scaled10_v   := (selected_mag_v & "00000") -
                                        ("000" & selected_mag_v & "00");
                        scaled_mag_v := scaled10_v(9 downto 5);
                        output_sign_v := total_sign_r(lane) xor
                                         edge_sign_mem(output_index)(lane);

                        if scaled_mag_v = "00000" then
                            ov_r_new_chk(6*lane+5 downto 6*lane) <= "000000";
                        elsif output_sign_v = '0' then
                            ov_r_new_chk(6*lane+5 downto 6*lane) <=
                                '0' & scaled_mag_v;
                        else
                            ov_r_new_chk(6*lane+5 downto 6*lane) <=
                                '1' & ((not scaled_mag_v) + '1');
                        end if;
                    end loop;

                    o_r_valid      <= '1';
                    o_r_edge_valid <= '1';
                    if output_index = output_edge_count - 1 then
                        output_active <= '0';
                        output_index  <= 0;
                    else
                        output_index <= output_index + 1;
                    end if;
                end if;

                -- Collect the current layer.  i_dummy is retained in the
                -- interface for clarity; i_edge_valid is the authoritative
                -- qualification and prevents dummy data from entering CNU state.
                if i_slot_valid = '1' then
                    if collect_active = '0' then
                        edge_total_v := 0;
                    else
                        edge_total_v := real_edge_count;
                    end if;

                    for lane in 0 to C_Z-1 loop
                        if collect_active = '0' then
                            min1_v       := "11111";
                            min2_v       := "11111";
                            min_index_v  := "00000";
                            total_sign_v := '0';
                        else
                            min1_v       := min1_r(lane);
                            min2_v       := min2_r(lane);
                            min_index_v  := min_index_r(lane);
                            total_sign_v := total_sign_r(lane);
                        end if;

                        if (i_edge_valid = '1') and (i_dummy = '0') then
                            input_sign_v := iv_v2c_chk(6*lane+5);
                            if input_sign_v = '0' then
                                input_mag_v := iv_v2c_chk(6*lane+4 downto 6*lane);
                            else
                                input_mag_v :=
                                    (not iv_v2c_chk(6*lane+4 downto 6*lane)) + '1';
                            end if;

                            edge_sign_mem(edge_total_v)(lane) <= input_sign_v;
                            total_sign_v := total_sign_v xor input_sign_v;
                            if input_mag_v < min1_v then
                                min2_v      := min1_v;
                                min1_v      := input_mag_v;
                                min_index_v := conv_std_logic_vector(
                                    edge_total_v, min_index_v'length);
                            elsif input_mag_v < min2_v then
                                min2_v := input_mag_v;
                            end if;
                        end if;

                        min1_r(lane)      <= min1_v;
                        min2_r(lane)      <= min2_v;
                        min_index_r(lane) <= min_index_v;
                        total_sign_r(lane) <= total_sign_v;
                    end loop;

                    if (i_edge_valid = '1') and (i_dummy = '0') then
                        edge_total_v := edge_total_v + 1;
                    end if;

                    if i_row_end = '1' then
                        collect_active    <= '0';
                        real_edge_count   <= 0;
                        output_edge_count <= edge_total_v;
                        output_index      <= 0;
                        if edge_total_v > 0 then
                            output_active <= '1';
                        else
                            output_active <= '0';
                        end if;
                    else
                        collect_active  <= '1';
                        real_edge_count <= edge_total_v;
                    end if;
                end if;
            end if;
        end if;
    end process cnu_pipeline_pro;

end Behavioral;
