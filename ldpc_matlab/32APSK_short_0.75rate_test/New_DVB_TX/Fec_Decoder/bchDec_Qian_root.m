function [err_num,location] = bchDec_Qian_root( idx,sigma_x,deg_sigma_x,DouCorrNum,alpha_to,index_of,GF_mm)  
 err_num = 0 ;
 location = 0;
 index_sigma_x= zeros(1,DouCorrNum+3);
 for i = 1:deg_sigma_x(DouCorrNum) 
    if(sigma_x(idx+1,i+1)~=0)
      index_sigma_x(i) = index_of(sigma_x(idx+1,i+1));%%将错误位置多项式的系数（是有限域元素）的指数形式放入寄存器index_sigma_x中
    else
      index_sigma_x(i) = index_of(2^GF_mm);
    end
 end
   
 %% // Begin chien search  //开始钱搜索
 for i = 1: 2^GF_mm-1 %// 串行进行钱搜索         
	sigma_sum = 1 ;%求和变量，以下for循环就是进行循环累加
    for j = 1: deg_sigma_x(DouCorrNum)
        if (index_sigma_x(j) ~= -1)%如果错误位置多项式的系数不为零                    
		   index_sigma_x(j) = mod((index_sigma_x(j) + j) , 2^GF_mm-1 );%则用错误位置多项式的系数sigma_x(j)乘以有限域元素alpha_to(j),在有限域中计算就是两者指数相加再模2^GF_mm-1
           sigma_sum = bitxor(sigma_sum,alpha_to(index_sigma_x(j)+1)) ;%求和
        end
    end                       
    %// store root and error location number indices 
    if sigma_sum==0     %如果求得的和等于0说明有错误，记录错误位置，如果不等于0说明正确                
	   err_num = err_num+1 ;  %若译码错误则译码错误计数器加1
       location(err_num) = 2^GF_mm-1 - i + 1 ;  %location存储译码错误的位置               
    end
 end
 
end