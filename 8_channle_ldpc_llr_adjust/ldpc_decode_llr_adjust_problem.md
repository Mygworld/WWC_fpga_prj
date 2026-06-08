### ldpc_decode_llr_adjust_problem

#### 1.时序违例

![](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260604163425724.png)

![image-20260607104242097](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260607104242097.png)

违例的**根本原因**：**高扇出 I/O 飞线**

**解决方法**：**输入/输出打拍缓冲** (I/O Registering)，带有庞大内部阵列的模块，所有的外部输入信号，进门第一件事必须先进寄存器（打一拍）；所有的输出信号，出门前必须从寄存器出。

vivado底层逻辑：

- 外部的物理管脚（Pin）是**唯一**的，它无法被复制。如果它直接驱动内部 2000 个触发器，这根线就必须拉得无限长。

- 如果你进门先打一拍（存入 `iv_llr_d1` 寄存器），Vivado 的物理优化（PhysOpt）算法发现这个寄存器扇出太高，它会**自动把这个寄存器克隆出几十份（Register Replication）**，散布到你阵列的各个角落。

**重点：作为子模块仍需要打拍，虽然会导致增加几千LUT资源使用，但会避免以下隐患**

- **高扇出（High Fan-out）拖死上游：**  `iv_llr` 进来后，要同时驱动几千个 `ping_bank` 寄存器。如果不打拍，这个“1 拖几千”的沉重物理负担，就会顺着网线直接砸给上游模块！上游模块原本好好的时序，会瞬间拖垮。

- **时序无底洞（Timing Blackhole）：** 假如上游模块内部有一段很长的组合逻辑（延迟 3ns），交织器内部又有一段组合逻辑（延迟 3ns）。你们单独看都能跑过 5ns (200MHz)。但如果拼在一起，**中间没有寄存器隔断**，总延迟变成了 `3ns + 3ns = 6ns`，整个大系统的时序当场爆炸！而且查错的时候根本不知道是谁的锅。

- **OBUF（输出缓冲器）的物理开关时间：**在 FPGA 中，把一个微弱的内部信号放大，并驱动到芯片外部真实的物理引脚上（比如驱动一个 3.3V 的外部芯片），物理晶体管的翻转是需要极其庞大能量和时间的。在 Virtex-7 上，这个 OBUF 的固有延迟就是 ~2.45 ns。

  ```vhdl
      -- =========================================================
      -- 强制输出寄存器打包到 IOB，消灭外部引脚走线延迟
      -- =========================================================
      attribute IOB : string;
      attribute IOB of ov_blk_k : signal is "true";
      attribute IOB of ov_blk_n : signal is "true";
      attribute IOB of ov_llr   : signal is "true";
      attribute IOB of o_llr_en : signal is "true";
  ```

  使用Attribute约束，强制IOB 寄存器封装，把输出触发器塞到芯片最边缘、紧挨着物理引脚的 IOB（输入/输出块）里面，如下图：

![image-20260608143315610](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260608143315610.png)

![image-20260608143804290](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260608143804290.png)

**非根本原因（X）**：从1120深度的寄存器数组里根据**动态变量抓取8个独立数据时，需要构建8个庞大的1120选1的多路选择器（MUX）树，既会产生大量的LUT资源，也有可能导致多路选择器扇出**

```vhdl
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
                    if (tx_arr_sel = '0') then
                        ram_dina <= ping_reg(conv_integer(("00" & tx_m_cnt) + q_x7)) & 
                                    ping_reg(conv_integer(("00" & tx_m_cnt) + q_x6)) & 
                                    ping_reg(conv_integer(("00" & tx_m_cnt) + q_x5)) & 
                                    ping_reg(conv_integer(("00" & tx_m_cnt) + q_x4)) & 
                                    ping_reg(conv_integer(("00" & tx_m_cnt) + q_x3)) & 
                                    ping_reg(conv_integer(("00" & tx_m_cnt) + q_x2)) & 
                                    ping_reg(conv_integer(("00" & tx_m_cnt) + q_x1)) & 
                                    ping_reg(conv_integer(tx_m_cnt));
                    else
                        ram_dina <= pong_reg(conv_integer(("00" & tx_m_cnt) + q_x7)) & 
                                    pong_reg(conv_integer(("00" & tx_m_cnt) + q_x6)) & 
                                    pong_reg(conv_integer(("00" & tx_m_cnt) + q_x5)) & 
                                    pong_reg(conv_integer(("00" & tx_m_cnt) + q_x4)) & 
                                    pong_reg(conv_integer(("00" & tx_m_cnt) + q_x3)) & 
                                    pong_reg(conv_integer(("00" & tx_m_cnt) + q_x2)) & 
                                    pong_reg(conv_integer(("00" & tx_m_cnt) + q_x1)) & 
                                    pong_reg(conv_integer(tx_m_cnt));
                    end if;

                    -- FSM transition & accumulator inc
                    if (tx_m_cnt = q_val - 1) then
                        tx_m_cnt <= (others => '0');
                        tx_m_offset <= (others => '0'); -- Reset accum at chunk end
                        
                        if (tx_j_cnt = 44) then
                            frame_ready <= '1'; -- Full frame done, notify read proc
                        end if;
                    else
                        tx_m_cnt <= tx_m_cnt + 1;
                        tx_m_offset <= tx_m_offset + 45; -- Add 45 per cycle
                    end if;
                end if;
```

#### 2.LUT资源消耗

**未优化前资源使用**：

![image-20260607124024954](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260607124024954.png)

可优化



#### 3.重复赋值问题

**尽量避免同一值在不同ifelse中赋值**

---

```vhdl
-- 修改前：

```







