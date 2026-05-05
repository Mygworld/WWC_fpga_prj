function [location,decode_flag,err_num,DecData] = bch_decoder(codeword_N,correctNum,inDecData,alpha_to,index_of,GF_mm) 
%% 本函数用于进行BCH译码。BCH译码主要分为三步：1.求伴随式；2.用BM迭代算法求出错误位置多项式；3.用钱搜索求出错误位置多项式的根，也就是码字错误比特的位置
% 输出参数：
%     location -- 码字错误比特的位置
%     decode_flag -- 标志译码是否成功 /* 1 for success; 0 for fail */
%     err_num -- 码字错误比特数
%     DecData -- 译码输出，即译出的码字
% 输入参数：
%     codeword_N -- 编码后的码长
%     parallel -- 并行计算伴随式的并行支路数
%     parity_R -- 校验位长度
%     T_G_R -- 求伴随式的查找表矩阵 /* lookahead matrix for BCH code */
%     correctNum -- 可纠错数t  /* correct number */
%     inDecData -- 译码输入
%     alpha_to -- 有限域元素
%     index_of -- 有限域元素的指数
%     GF_mm -- 有限域的维度/* Dimension of Galoise Field */
% 变量声明：
%     DouCorrNum：double correctNum,即可纠错数的二倍, DouCorrNum = 2*correctNum
%     syn: /*Syndrome values*/ 伴随式的值
%     syn_error: /*Syndrome error indicator*/ 伴随式错误标志 /* if (syn(i) ~= 0) ,syn_error = 1 ; else, syn_error = 0 ;*/
%     idx: /* step number */ BM迭代算法中的迭代步数j,idx ranges from -1 to 2*t
%     sigma_x: /* Error locator polynomial */ 错误位置多项式sigma(x)
%     deg_sigma_x: /* Degree of sigma(x) */ 错误位置多项式sigma(x)的次数D(j)，即多项式的系数不为零的x的最高次数

%函数主体

  
 DouCorrNum = 2*correctNum;
 location = 0;
 decode_flag = 0;
 err_num = 0 ;   
 DecData = fliplr(inDecData);
  %% 求伴随式 %%
  [syn,syn_error] = bchdec_SyndCal(inDecData,codeword_N,GF_mm,index_of,alpha_to,DouCorrNum);
 if ~syn_error          %// No errors
	 decode_flag = 1 ;	%译码成功，接收的码字没有错误，不用纠错
 else
  %% BM迭代算法 %%
   [idx,sigma_x,deg_sigma_x] = bchDec_iterate_BM(syn,correctNum,DouCorrNum,alpha_to,index_of,GF_mm) ;
   test_sigma_x = zeros(1,24);
   for i = 1:deg_sigma_x(DouCorrNum) 
      test_sigma_x(1,i) = sigma_x(idx+1,i+1);
   end 
   
   if (deg_sigma_x(DouCorrNum) <= correctNum)%如果deg_sigma_x(DouCorrNum)<=correctNum,说明没有超出可纠错上限，可进行纠错，于是进行钱搜索找出错误位置   
  %% 钱搜索 %%
%    save( 'test_root_qian_source.mat','sigma_x' );
     [err_num,location] = bchDec_Qian_root(idx,sigma_x,deg_sigma_x,DouCorrNum,alpha_to,index_of,GF_mm) ;
     error_location = zeros (1,codeword_N);
     for i = 1:err_num
         temp = location(i);
         error_location (temp) = 1;
     end
%      save( 'test_root_qian_compare1.mat','error_location' );
  %% 进行纠错 %%   
      if (err_num == deg_sigma_x(DouCorrNum))   %// Number of roots = degree of sigma_x hence <= correctNum //根的数量=错误位置多项式的阶数<=可纠错数correctNum             
	     decode_flag = 1 ;		 
         if (location ~=0 )
	         for i = 1: deg_sigma_x(DouCorrNum)         
                DecData(location(i)) = bitxor(DecData(location(i)),1); %%%// Correct errors by flipping the error bit //二进制情况下将错误位置与1进行异或即可完成纠错;
           end
         end
      end
  end
		
end


