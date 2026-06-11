## different version's resource and timing delay result

#### version1:Split single-cycle timing (ping/pong_reg rd to ram_dina) into 2-stage pipeline and no change q_x7 and INFO_LEN

- resource:

  ![image-20260610174440341](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260610174440341.png)

- timing:

  ![image-20260610174433835](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260610174433835.png)

#### version2:Split single-cycle timing (ping/pong_reg rd to ram_dina) into 2-stage pipeline and  change q_x7 and INFO_LEN

- resource:

  ![image-20260610174308773](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260610174308773.png)

- timing:

  ![image-20260610174328541](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260610174328541.png)

#### version3:Split 1120-depth large array into two 560-depth arrays,cut giant MUX long route

- resource:
  ![image-20260610185441556](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260610185441556.png)
- timing:
  ![image-20260610185636750](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260610185636750.png)

#### version4:Split single-cycle timing (ping/pong_reg rd to ram_dina) into 2-stage pipeline and  change q_x7 and INFO_LEN,but ping_reg wr and  ram_dina wr use for cycle.

- resource:

  ![image-20260611111842056](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260611111842056.png)

- timing:

  ![image-20260611111900449](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20260611111900449.png)

