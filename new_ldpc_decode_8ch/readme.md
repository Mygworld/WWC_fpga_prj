# new_ldpc_decode_8ch

change temp_ram write logic and add sum_ram ping-pong for providing decode sudu
include parameter,

原工程3/4短码译码速度：

- 单次迭代时钟数：351

- 60次迭代时钟数：21056 
- 译码总时钟数含adjust和输出：24613

资源使用：92461LUT和180BRAM

修改后译码速度：

- 单次迭代时钟数：190

- 60次迭代时钟数：11403
- 译码总时钟数含adjust和输出：14975

资源使用

