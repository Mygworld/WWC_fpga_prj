function [idx,sigma_x,deg_sigma_x] = bchDec_iterate_BM(syn,correctNum,DouCorrNum,alpha_to,index_of,GF_mm) 

   
    %% BM迭代算法 %%
    syn(DouCorrNum+1)=0;
    syn(DouCorrNum+2)=0;
    %%%%  读取伴随式的值的指数 %%%%
    syn_index = zeros ( 1,DouCorrNum+2 );
    for i = 1:DouCorrNum
        if ( syn(i) ~= 0 )
            syn_index(i) = index_of(syn(i));%%先将syn(i)转换成指数形式，syn(i)是有限域元素alpha_to( ),index_of(syn(i))是它的指数
        else
            syn_index(i) = index_of(2^GF_mm);%%syn(i) = index_of(2^GF_mm)=-1 ，（当syn(i)=0时，是syn(i)的指数是-1）alpha_to(2^GF_mm) = 0存放的是有限域元素0;
        end
    end
    
    %%%%  初始化  %%%%
    desc=zeros(1,DouCorrNum+4);                 %/Discrepancy 'mu'th discrepancy(差值Dj)
    deg_sigma_x = zeros(1,DouCorrNum+3);		%/ Degree of sigma_x (错误位置多项式的阶数）
    idx_deg= zeros(1,DouCorrNum+3);		        %/ Difference between step number and the degree of ELP  (迭代步数和错误位置多项式阶数的差值）
    sigma_x= zeros(DouCorrNum+4,DouCorrNum+4); 	%/ Error locator polynomial //错误位置多项式(sigma_x)

    %%%%  赋初始值  %%%%
    desc(1) = 0;				    %/* index form */ 指数形式
	desc(2) = syn_index(1);			%/* index form */
	deg_sigma_x(1) = 0;     %deg_sigma_x(0) = 0;    %/* deg_sigma_x( )是错误位置多项式的阶数 */
    deg_sigma_x(2) = 0;     %deg_sigma_x(1) = 0; 
    idx_deg(1) = -1;        %idx_deg(0) = -1;       %/* idx_deg[idx]是迭代的步数与错误位置多项式阶数的差值 */
    idx_deg(2) = 0;         %idx_deg(1) = 0;
    sigma_x(1,1) = 1;				%/* polynomial form */ 多项式形式
	sigma_x(2,1) = 1;				%/* polynomial form */
	  for i = 2: DouCorrNum
        sigma_x(1,i) = 0;			%/* polynomial form */
		sigma_x(2,i) = 0;			%/* polynomial form */
    end
    
    idx = -1;   %%(idx=-1~2t)  %%迭代到第idx步求得的错误位置多项式存放在sigma_x(idx+2,1:DouCorrNum)里，阶数放在deg_sigma_x(idx+2)里 （因为存储单元位置没有负数表示，所以-1=>1,0=>2)
 
	  while ((idx < (DouCorrNum-1)) && (deg_sigma_x(idx + 2 +1) <= correctNum)) %%当（迭代步数idx<（2t-1)且迭代到第idx步求得的错误位置多项式sigma_x(idx+2+1)的阶数deg_sigma_x（idx+2+1)<=t)时  
         %// even loops always produce no discrepany so they can be skipped 偶数循环总是不产生差值，即desc=0,因此将它们跳过
         idx = idx + 2;  
         if ( desc(idx+1) == -1)%%//报错！matlab里索引号从1开始，不能为0 //%%-1代表有限域元素0的指数
             deg_sigma_x(idx + 2+1) = deg_sigma_x(idx+1);  
             for i = 1 : deg_sigma_x(idx+1)+1
                 sigma_x(idx + 2+1,i) = sigma_x(idx+1,i);
             end
         else
             %// search for words with greatest idx_deg[q] for which desc[q]!=0 寻找idx之前的第q行使desc(q)不等于零的最大idx_deg(q)
			 q = idx - 2;
             if (q<0) 
                 q=0;
             end
			 %// Look for first non-zero desc(q) 寻找第一个使desc(q)非零的q
             while ((desc(q+1) == -1) && (q > 0))
                 q=q-2;
                 if (q < 0) 
                 q = 0;
                 end
             end
             %// Find q such that desc[idx]!=0 and idx_deg[q] is maximum 找到使desc(q）不等于0且使idx_deg(q)最大的q
	            if (q > 0)
                 j = q;%%先找到使desc(q）不等于0的最大q，然后循环往下找j,如果找到j满足(desc(j+1) ~= -1) && (idx_deg(q+1) < idx_deg(j+1))，则将j赋给q，如此循环可找到使idx_deg(q)最大的q
                 while (j > 0)
                     j=j-2;
                     if (j < 0) 
                         j = 0;
                         if ((desc(j+1) ~= -1) && (idx_deg(q+1) < idx_deg(j+1)))
                             q = j;
                         end
                     end				  	
                 end				
              end
             %// store degree of new sigma_x polynomial 存储新的错误位置多项式的阶数在deg_sigma_x(idx + 2+1 )中
             if (deg_sigma_x(idx+1) > deg_sigma_x(q+1) + idx - q)  
                 deg_sigma_x(idx + 2+1) = deg_sigma_x(idx+1);
             else
                 deg_sigma_x(idx + 2+1) = deg_sigma_x(q+1) + idx - q;
             end
             
             %// Form new sigma_x(x)  构造新的错误位置多项式
             for i = 1 : DouCorrNum  
                 sigma_x(idx + 2+1,i) = 0; %初始化
             end
             %idx是迭代步数，q是寻找到的idx之前的第q行使desc(q)不等于零的最大idx_deg(q)
             %(sigma_x(idx+2+1)=sigma_x(idx+1)+desc(idx+1)*desc(q+1)^(-1)*x^(idx-q)*sigma_x(q+1)
             %上面等式*x^(idx-q)相当于在sigma_x中右移两位，上式是计算公式，进行二进制计算要按以下代码计算
             for i = 1 : deg_sigma_x(q+1)+1
                 if (sigma_x(q+1,i) ~= 0)
                     sigma_x(idx + 2+1,i + idx - q) = alpha_to(mod(desc(idx+1) + 2^GF_mm-1 - desc(q+1) + index_of(sigma_x(q+1,i)), 2^GF_mm-1)+1);
                 end
             end
             for  i = 1 : deg_sigma_x(idx+1)+1 
                 sigma_x(idx + 2+1,i) = bitxor(sigma_x(idx + 2+1,i),sigma_x(idx+1,i));%相加 
             end
         end
         idx_deg(idx + 2+1) = idx + 1 - deg_sigma_x(idx + 2+1); %% idx_deg = 迭代步数 - 错误位置多项式的阶数
         %// Form (idx+2)th discrepancy. //构造新的第idx+2次差值desc(idx+2)
         %// No discrepancy computed on last  iteration//最后一次迭代不用计算差值decs
         if (idx < DouCorrNum)
             if (syn_index(idx + 2) ~= -1) %%用-1表示有限域元素0的指数，这就是如果syn_index(idx + 2)~=0
             	 desc(idx + 2+1) = alpha_to(syn_index(idx + 2)+1);%%先从指数形式转成对应有限域元素的二进制形式
             else
                 desc(idx + 2+1) = 0;
             end
             for i = 1 : deg_sigma_x(idx + 2+1) 
                 if ((syn_index(idx + 2 - i) ~= -1) && (sigma_x(idx + 2+1,i+1) ~= 0))
                     desc(idx + 2+1) = bitxor(desc(idx + 2+1),alpha_to(mod(syn_index(idx + 2 - i) + index_of(sigma_x(idx + 2+1,i+1)), 2^GF_mm-1)+1 )); %%%计算新的差值desc(idx+2+1)
                 end			 	
             end
              %// put desc[idx+2] into index form  将desc(q）变成指数形式
             if(desc(idx+2+1)~=0)
                 desc(idx + 2+1) = index_of(desc(idx + 2+1));	
             else
                 desc(idx + 2+1) = index_of(2^GF_mm);  %//  index_of(2^GF_mm) = -1
             end
             
         end
			
    end
    
    idx = idx+2;
    deg_sigma_x(DouCorrNum) = deg_sigma_x(idx+1);
    
end