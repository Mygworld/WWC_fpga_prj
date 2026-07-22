----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Wang Weichen
-- 
-- Create Date: 15:03:14 07/09/2026 
-- Design Name: 
-- Module Name: ldpc_layered_decode - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:
--   Universal DVB-S2/S2X layered-schedule reader for the existing 19-bit ROM.
--   基于现有 19 bit 参数 ROM 的 DVB-S2/S2X 通用分层调度读取模块。
--
--   One i_start pulse scans one complete iteration schedule.  i_advance may
--   pause the issue of new ROM requests; words already in the ROM pipeline
--   are still returned with o_word_valid='1'.
--   i_start 拉高一个时钟后扫描一次完整迭代参数；i_advance='0'
--   只停止新请求，已进入 ROM 流水线的数据仍会有效输出。
--
-- ROM word format / ROM 字格式:
--   bit 18      : weight; '0' marks the last valid slot of one layer
--                 weight='0' 表示当前字是本层最后一个有效 slot
--   bit 17      : legacy pos_en, not required by the layered datapath
--   bits 16:9   : variable-node block position pos
--   bits 8:0    : forward barrel-shift code
--
-- Important / 重要:
--   pos=181 is the only dummy CNU bubble.  A word with weight='0' and
--   pos/=181 is still a real edge and receives a message address.
--   仅 pos=181 是 CNU 气泡；weight='0' 的层尾字仍是真实边。
--
-- Removed redundant/debug ports / 已删除的冗余接口:
--   o_busy, o_row_start, o_row_active, o_dummy, o_pos_en_raw,
--   ov_layer_idx, ov_slot_idx and ov_rom_addr.
--   o_dummy is redundant because dummy = o_word_valid and not o_edge_valid.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ldpc_layered_parameter is
    Port (
        i_clk       : in  STD_LOGIC;
        i_rst       : in  STD_LOGIC;
        iv_len      : in  STD_LOGIC_VECTOR(1 downto 0);
        iv_rate     : in  STD_LOGIC_VECTOR(5 downto 0);

        -- One-clock request for a complete iteration schedule scan.  The first
        -- registered output is valid two clocks after this pulse is sampled.
        -- 启动一次完整迭代参数扫描；采样该脉冲后两拍输出首个有效参数。
        i_start     : in  STD_LOGIC;

        -- Release the next layer after the previous layer has completed every
        -- soft-total/check-message writeback.  The first layer is released by
        -- i_start and therefore does not need i_next_layer.  The first output
        -- of the released layer is valid two clocks after this pulse is sampled.
        -- 上一层所有 soft_total/check_msg 写回完成后，拉高一个时钟启动下一层；
        -- 采样该脉冲后两拍输出下一层首个有效参数。
        i_next_layer : in STD_LOGIC;

        -- Clock enable inside one layer.  Keep high for continuous slot issue;
        -- the module stops automatically after the configured final slot.
        -- 层内 ROM 请求使能；达到当前码率的固定 slot 数后自动停止。
        i_advance   : in  STD_LOGIC;

        -- Combinational indication that iv_len/iv_rate exists in this ROM.
        -- 当前帧长和码率在 ROM 地址表中有定义。
        o_supported : out STD_LOGIC;

        -- Pulses with the last valid schedule word.
        -- 与本次迭代最后一个参数字对齐。
        o_done      : out STD_LOGIC;

        -- Schedule output.  Other outputs are meaningful only when valid=1.
        -- 参数输出，其余输出仅在 o_word_valid='1' 时有效。
        o_word_valid : out STD_LOGIC;
        o_row_end    : out STD_LOGIC;
        o_edge_valid : out STD_LOGIC;
        ov_pos       : out STD_LOGIC_VECTOR(7 downto 0);
        ov_msg_addr  : out STD_LOGIC_VECTOR(9 downto 0);
        ov_fwd_shift : out STD_LOGIC_VECTOR(8 downto 0);
        ov_rev_shift : out STD_LOGIC_VECTOR(8 downto 0)
    );
end ldpc_layered_parameter;

architecture Behavioral of ldpc_layered_parameter is

    COMPONENT ldpc_decode_parameter_rom
      PORT (
         clka  : IN  STD_LOGIC;
         rsta  : IN  STD_LOGIC;
         ena   : IN  STD_LOGIC;
         addra : IN  STD_LOGIC_VECTOR(14 DOWNTO 0);
         douta : OUT STD_LOGIC_VECTOR(18 DOWNTO 0)
      );
    END COMPONENT;

    constant C_DUMMY_POS : STD_LOGIC_VECTOR(7 downto 0) := x"B5"; -- 181

    -- The five all-zero words at the end of every ROM segment belong to the
    -- legacy pipeline guard area and are deliberately excluded.
    -- 每个码率段末尾的 5 个全零字是旧流水线保护区，不参与新分层调度。
    -- Store a 15-bit first address and a 10-bit schedule-word count.  The
    -- largest schedule contains 840 words, so a 15-bit last-address register
    -- and a 15-bit end comparator are unnecessary.
    -- 保存 15 bit 首地址和 10 bit 调度字数，不再保存 15 bit 末地址。
    signal cfg_base_addr_s : STD_LOGIC_VECTOR(14 downto 0) := (others => '0');
    signal cfg_word_num_s  : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal cfg_slot_num_s  : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');
    signal cfg_supported_s : STD_LOGIC := '0';

    signal rom_addr        : STD_LOGIC_VECTOR(14 downto 0) := (others => '0');
    signal words_left_r    : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal slots_left_r    : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');
    signal rom_data        : STD_LOGIC_VECTOR(18 downto 0);
    signal iteration_active : STD_LOGIC := '0';
    signal layer_issue_active : STD_LOGIC := '0';

    -- Request-valid and last-word tags match the synchronous ROM latency used
    -- by the original project.
    signal req_valid_d0    : STD_LOGIC := '0';
    signal req_valid_d1    : STD_LOGIC := '0';
    signal req_last_d0     : STD_LOGIC := '0';
    signal req_last_d1     : STD_LOGIC := '0';

    signal msg_count       : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');

    -- This function packages one combinational transform for readability and
    -- consistency.  Synthesis normally inlines it; it is not a resource-saving
    -- software subroutine.
    -- 函数只用于提高可读性并统一反向移位算法，综合时通常直接展开，
    -- 不会像软件子程序一样自动节省硬件资源。
    function reverse_shift_code(raw_shift : STD_LOGIC_VECTOR(8 downto 0))
        return STD_LOGIC_VECTOR is
        variable rev_shift : STD_LOGIC_VECTOR(8 downto 0);
    begin
        -- Same inverse code as the reverse branch of ldpc_decode_parameter.
        -- 与原参数模块反向移位分支保持一致。
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
         clka  => i_clk,
         rsta  => i_rst,
         ena   => '1',
         addra => rom_addr,
         douta => rom_data
      );

    ------------------------------------------------------------------------------
    -- ROM request, valid alignment and schedule-word decoding.
    -- ROM 请求、有效信号对齐及参数字解码。
    ------------------------------------------------------------------------------
    parameter_rom_ctrl_pro : process(i_clk)
    begin
        if (i_clk'event and i_clk = '1') then
            if (i_rst = '1') then
                rom_addr       <= (others => '0');
                words_left_r   <= (others => '0');
                slots_left_r   <= (others => '0');
                iteration_active <= '0';
                layer_issue_active <= '0';
                req_valid_d0   <= '0';
                req_valid_d1   <= '0';
                req_last_d0    <= '0';
                req_last_d1    <= '0';
                msg_count      <= (others => '0');

                o_done         <= '0';
                o_word_valid   <= '0';
                o_row_end      <= '0';
                o_edge_valid   <= '0';
                ov_pos         <= (others => '0');
                ov_msg_addr    <= (others => '0');
                ov_fwd_shift   <= (others => '0');
                ov_rev_shift   <= (others => '0');
            else
                -- Advance the tags already in the request pipeline.  The new
                -- d0 tags are assigned by one mutually exclusive decision
                -- tree below; do not use a default assignment followed by an
                -- override in another if statement.
                req_valid_d1 <= req_valid_d0;
                req_last_d1  <= req_last_d0;

                if (i_start = '1') then
                    if (cfg_supported_s = '1') then
                        rom_addr     <= cfg_base_addr_s;
                        words_left_r <= cfg_word_num_s - '1';
                        slots_left_r <= cfg_slot_num_s - '1';

                        req_valid_d0       <= '1';
                        req_last_d0        <= '0';
                        iteration_active   <= '1';
                        layer_issue_active <= '1';
                    else
                        iteration_active <= '0';
                        layer_issue_active <= '0';
                        req_valid_d0 <= '0';
                        req_last_d0  <= '0';
                    end if;

                -- Start the first request of the next layer.  The request-side
                -- slot counter prevents any next-layer word entering the ROM
                -- before this explicit release pulse.
                elsif (iteration_active = '1') and (layer_issue_active = '0') and
                      (i_next_layer = '1') then
                    rom_addr     <= rom_addr + '1';
                    words_left_r <= words_left_r - '1';
                    slots_left_r <= cfg_slot_num_s - '1';

                    req_valid_d0       <= '1';
                    req_last_d0        <= '0';
                    layer_issue_active <= '1';

                -- Continue issuing the remaining slots of the active layer.
                elsif (layer_issue_active = '1') and (i_advance = '1') then
                    rom_addr     <= rom_addr + '1';
                    words_left_r <= words_left_r - '1';
                    slots_left_r <= slots_left_r - '1';
                    req_valid_d0 <= '1';

                    if (words_left_r = conv_std_logic_vector(1, words_left_r'length)) then
                        iteration_active <= '0';
                        layer_issue_active <= '0';
                        req_last_d0 <= '1';
                    else
                        req_last_d0 <= '0';
                        if (slots_left_r = conv_std_logic_vector(1, slots_left_r'length)) then
                            layer_issue_active <= '0';
                        end if;
                    end if;
                
                -- No request is issued while a layer is paused or after the
                -- iteration has completed.  rom_addr and both remaining-count
                -- registers therefore keep their current values.
                -- 层暂停或迭代结束时不发出请求，ROM 地址及剩余计数器保持不变。
                else
                    req_valid_d0 <= '0';
                    req_last_d0  <= '0';
                end if;

                -- One output assignment path avoids multiple independent if
                -- statements writing the same valid/control signals.
                if (req_valid_d1 = '1') then
                    o_word_valid <= '1';
                    o_done       <= req_last_d1;
                    o_row_end    <= not rom_data(18);
                    ov_pos       <= rom_data(16 downto 9);
                    ov_msg_addr  <= msg_count;
                    ov_fwd_shift <= rom_data(8 downto 0);
                    ov_rev_shift <= reverse_shift_code(rom_data(8 downto 0));

                    if (rom_data(16 downto 9) = C_DUMMY_POS) then
                        o_edge_valid <= '0';
                    else
                        o_edge_valid <= '1';
                    end if;
                else
                    o_word_valid <= '0';
                    o_done       <= '0';
                    o_row_end    <= '0';
                    o_edge_valid <= '0';
                end if;

                -- Keep all msg_count assignments in the same priority tree.
                -- A new scan resets the address even if an old response is
                -- still retiring from the ROM pipeline.
                if (i_start = '1') then
                    msg_count <= (others => '0');
                elsif (req_valid_d1 = '1') and (rom_data(16 downto 9) /= C_DUMMY_POS) then
                    msg_count <= msg_count + '1';
                end if;
            end if;
        end if;
    end process parameter_rom_ctrl_pro;

    ------------------------------------------------------------------------------
    -- ROM segment decoder.  Values are the first address and the number of
    -- schedule words; the five legacy trailing zero words are not included.
    -- ROM 分段译码：输出真实调度区首地址和字数，不包含末尾 5 个全零字。
    ------------------------------------------------------------------------------
    parameter_config_decode_pro : process(iv_len, iv_rate)
        variable base_addr_v : STD_LOGIC_VECTOR(14 downto 0);
        variable word_num_v  : STD_LOGIC_VECTOR(9 downto 0);
        variable slot_num_v  : STD_LOGIC_VECTOR(4 downto 0);
        variable supported_v : STD_LOGIC;
    begin
        base_addr_v := (others => '0');
        word_num_v  := (others => '0');
        slot_num_v  := (others => '0');
        supported_v := '1';

        case iv_len is
            when "00" =>                    -- Normal frame / 64800 bit
                case iv_rate is
                    -- DVB-S2X
                    when "000000" => base_addr_v := conv_std_logic_vector(    0, 15); word_num_v := conv_std_logic_vector(560, 10); slot_num_v := conv_std_logic_vector( 4, 5); -- 2/9
                    when "000001" => base_addr_v := conv_std_logic_vector(  565, 15); word_num_v := conv_std_logic_vector(640, 10); slot_num_v := conv_std_logic_vector( 5, 5); -- 13/45
                    when "000010" => base_addr_v := conv_std_logic_vector( 1210, 15); word_num_v := conv_std_logic_vector(693, 10); slot_num_v := conv_std_logic_vector( 7, 5); -- 9/20
                    when "000011" => base_addr_v := conv_std_logic_vector( 1908, 15); word_num_v := conv_std_logic_vector(729, 10); slot_num_v := conv_std_logic_vector( 9, 5); -- 11/20
                    when "000100" => base_addr_v := conv_std_logic_vector( 2642, 15); word_num_v := conv_std_logic_vector(760, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 26/45
                    when "000101" => base_addr_v := conv_std_logic_vector( 3407, 15); word_num_v := conv_std_logic_vector(680, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 28/45
                    when "000110" => base_addr_v := conv_std_logic_vector( 4092, 15); word_num_v := conv_std_logic_vector(650, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 23/36
                    when "000111" => base_addr_v := conv_std_logic_vector( 4747, 15); word_num_v := conv_std_logic_vector(715, 10); slot_num_v := conv_std_logic_vector(13, 5); -- 25/36
                    when "001000" => base_addr_v := conv_std_logic_vector( 5467, 15); word_num_v := conv_std_logic_vector(700, 10); slot_num_v := conv_std_logic_vector(14, 5); -- 13/18
                    when "001001" => base_addr_v := conv_std_logic_vector( 6172, 15); word_num_v := conv_std_logic_vector(720, 10); slot_num_v := conv_std_logic_vector(18, 5); -- 7/9
                    when "001010" => base_addr_v := conv_std_logic_vector( 6897, 15); word_num_v := conv_std_logic_vector(720, 10); slot_num_v := conv_std_logic_vector( 8, 5); -- 90/180
                    when "001011" => base_addr_v := conv_std_logic_vector( 7622, 15); word_num_v := conv_std_logic_vector(756, 10); slot_num_v := conv_std_logic_vector( 9, 5); -- 96/180
                    when "001100" => base_addr_v := conv_std_logic_vector( 8383, 15); word_num_v := conv_std_logic_vector(720, 10); slot_num_v := conv_std_logic_vector( 9, 5); -- 100/180
                    when "001101" => base_addr_v := conv_std_logic_vector( 9108, 15); word_num_v := conv_std_logic_vector(760, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 104/180
                    when "001110" => base_addr_v := conv_std_logic_vector( 9873, 15); word_num_v := conv_std_logic_vector(768, 10); slot_num_v := conv_std_logic_vector(12, 5); -- 116/180
                    when "001111" => base_addr_v := conv_std_logic_vector(10646, 15); word_num_v := conv_std_logic_vector(784, 10); slot_num_v := conv_std_logic_vector(14, 5); -- 124/180
                    when "010000" => base_addr_v := conv_std_logic_vector(11435, 15); word_num_v := conv_std_logic_vector(780, 10); slot_num_v := conv_std_logic_vector(15, 5); -- 128/180
                    when "010001" => base_addr_v := conv_std_logic_vector(12220, 15); word_num_v := conv_std_logic_vector(768, 10); slot_num_v := conv_std_logic_vector(16, 5); -- 132/180
                    when "010010" => base_addr_v := conv_std_logic_vector(12993, 15); word_num_v := conv_std_logic_vector(765, 10); slot_num_v := conv_std_logic_vector(17, 5); -- 135/180
                    when "010011" => base_addr_v := conv_std_logic_vector(13763, 15); word_num_v := conv_std_logic_vector(800, 10); slot_num_v := conv_std_logic_vector(20, 5); -- 140/180
                    when "010100" => base_addr_v := conv_std_logic_vector(14568, 15); word_num_v := conv_std_logic_vector(780, 10); slot_num_v := conv_std_logic_vector(30, 5); -- 154/180
                    when "010101" => base_addr_v := conv_std_logic_vector(15353, 15); word_num_v := conv_std_logic_vector(792, 10); slot_num_v := conv_std_logic_vector(11, 5); -- 18/30
                    when "010110" => base_addr_v := conv_std_logic_vector(16150, 15); word_num_v := conv_std_logic_vector(840, 10); slot_num_v := conv_std_logic_vector(14, 5); -- 20/30
                    when "010111" => base_addr_v := conv_std_logic_vector(16995, 15); word_num_v := conv_std_logic_vector(816, 10); slot_num_v := conv_std_logic_vector(17, 5); -- 22/30
                    -- DVB-S2
                    when "011000" => base_addr_v := conv_std_logic_vector(19967, 15); word_num_v := conv_std_logic_vector(540, 10); slot_num_v := conv_std_logic_vector( 4, 5); -- 1/4
                    when "011001" => base_addr_v := conv_std_logic_vector(20512, 15); word_num_v := conv_std_logic_vector(600, 10); slot_num_v := conv_std_logic_vector( 5, 5); -- 1/3
                    when "011010" => base_addr_v := conv_std_logic_vector(21117, 15); word_num_v := conv_std_logic_vector(648, 10); slot_num_v := conv_std_logic_vector( 6, 5); -- 2/5
                    when "011011" => base_addr_v := conv_std_logic_vector(21770, 15); word_num_v := conv_std_logic_vector(630, 10); slot_num_v := conv_std_logic_vector( 7, 5); -- 1/2
                    when "011100" => base_addr_v := conv_std_logic_vector(22405, 15); word_num_v := conv_std_logic_vector(792, 10); slot_num_v := conv_std_logic_vector(11, 5); -- 3/5
                    when "011101" => base_addr_v := conv_std_logic_vector(23202, 15); word_num_v := conv_std_logic_vector(600, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 2/3
                    when "011110" => base_addr_v := conv_std_logic_vector(23807, 15); word_num_v := conv_std_logic_vector(630, 10); slot_num_v := conv_std_logic_vector(14, 5); -- 3/4
                    when "011111" => base_addr_v := conv_std_logic_vector(24442, 15); word_num_v := conv_std_logic_vector(648, 10); slot_num_v := conv_std_logic_vector(18, 5); -- 4/5
                    when "100000" => base_addr_v := conv_std_logic_vector(25095, 15); word_num_v := conv_std_logic_vector(660, 10); slot_num_v := conv_std_logic_vector(22, 5); -- 5/6
                    when "100001" => base_addr_v := conv_std_logic_vector(25760, 15); word_num_v := conv_std_logic_vector(540, 10); slot_num_v := conv_std_logic_vector(27, 5); -- 8/9
                    when "100010" => base_addr_v := conv_std_logic_vector(26305, 15); word_num_v := conv_std_logic_vector(540, 10); slot_num_v := conv_std_logic_vector(30, 5); -- 9/10
                    when others   => supported_v := '0';
                end case;

            when "01" =>                    -- Medium frame / 32400 bit
                case iv_rate is
                    when "000000" => base_addr_v := conv_std_logic_vector(17816, 15); word_num_v := conv_std_logic_vector(288, 10); slot_num_v := conv_std_logic_vector(4, 5); -- 1/5
                    when "000001" => base_addr_v := conv_std_logic_vector(18109, 15); word_num_v := conv_std_logic_vector(272, 10); slot_num_v := conv_std_logic_vector(4, 5); -- 11/45
                    when "000010" => base_addr_v := conv_std_logic_vector(18386, 15); word_num_v := conv_std_logic_vector(300, 10); slot_num_v := conv_std_logic_vector(5, 5); -- 1/3
                    when others   => supported_v := '0';
                end case;

            when others =>                  -- Short frame / 16200 bit
                case iv_rate is
                    -- DVB-S2X
                    when "000000" => base_addr_v := conv_std_logic_vector(18691, 15); word_num_v := conv_std_logic_vector(136, 10); slot_num_v := conv_std_logic_vector( 4, 5); -- 11/45
                    when "000001" => base_addr_v := conv_std_logic_vector(18832, 15); word_num_v := conv_std_logic_vector(165, 10); slot_num_v := conv_std_logic_vector( 5, 5); -- 4/15
                    when "000010" => base_addr_v := conv_std_logic_vector(19002, 15); word_num_v := conv_std_logic_vector(155, 10); slot_num_v := conv_std_logic_vector( 5, 5); -- 14/45
                    when "000011" => base_addr_v := conv_std_logic_vector(19162, 15); word_num_v := conv_std_logic_vector(216, 10); slot_num_v := conv_std_logic_vector( 9, 5); -- 7/15
                    when "000100" => base_addr_v := conv_std_logic_vector(19383, 15); word_num_v := conv_std_logic_vector(210, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 8/15
                    when "000101" => base_addr_v := conv_std_logic_vector(19598, 15); word_num_v := conv_std_logic_vector(190, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 26/45
                    when "000110" => base_addr_v := conv_std_logic_vector(19793, 15); word_num_v := conv_std_logic_vector(169, 10); slot_num_v := conv_std_logic_vector(13, 5); -- 32/45
                    -- DVB-S2
                    when "000111" => base_addr_v := conv_std_logic_vector(26850, 15); word_num_v := conv_std_logic_vector(144, 10); slot_num_v := conv_std_logic_vector( 4, 5); -- 1/5
                    when "001000" => base_addr_v := conv_std_logic_vector(26999, 15); word_num_v := conv_std_logic_vector(150, 10); slot_num_v := conv_std_logic_vector( 5, 5); -- 1/3
                    when "001001" => base_addr_v := conv_std_logic_vector(27154, 15); word_num_v := conv_std_logic_vector(162, 10); slot_num_v := conv_std_logic_vector( 6, 5); -- 2/5
                    when "001010" => base_addr_v := conv_std_logic_vector(27321, 15); word_num_v := conv_std_logic_vector(175, 10); slot_num_v := conv_std_logic_vector( 7, 5); -- 4/9
                    when "001011" => base_addr_v := conv_std_logic_vector(27501, 15); word_num_v := conv_std_logic_vector(198, 10); slot_num_v := conv_std_logic_vector(11, 5); -- 3/5
                    when "001100" => base_addr_v := conv_std_logic_vector(27704, 15); word_num_v := conv_std_logic_vector(150, 10); slot_num_v := conv_std_logic_vector(10, 5); -- 2/3
                    when "001101" => base_addr_v := conv_std_logic_vector(27859, 15); word_num_v := conv_std_logic_vector(156, 10); slot_num_v := conv_std_logic_vector(13, 5); -- 11/15 (3/4)
                    when "001110" => base_addr_v := conv_std_logic_vector(28020, 15); word_num_v := conv_std_logic_vector(130, 10); slot_num_v := conv_std_logic_vector(13, 5); -- 7/9
                    when "001111" => base_addr_v := conv_std_logic_vector(28155, 15); word_num_v := conv_std_logic_vector(152, 10); slot_num_v := conv_std_logic_vector(19, 5); -- 37/45
                    when "010000" => base_addr_v := conv_std_logic_vector(28312, 15); word_num_v := conv_std_logic_vector(135, 10); slot_num_v := conv_std_logic_vector(27, 5); -- 8/9
                    when others   => supported_v := '0';
                end case;
        end case;

        cfg_base_addr_s <= base_addr_v;
        cfg_word_num_s  <= word_num_v;
        cfg_slot_num_s  <= slot_num_v;
        cfg_supported_s <= supported_v;
        o_supported     <= supported_v;
    end process parameter_config_decode_pro;


end Behavioral;
