function [syndrome,Syn_ErrFlag] = bchdec_SyndCal (HardInput,codeword_N,GF_mm,index_of,alpha_to,DouCorrNum)
%% syndrome calculate %%
%// Odd syndrome) ** 2  //偶数伴随式等于奇数伴随式的平方
syndrome = zeros(1,DouCorrNum);
syndrome(:) = HardInput(1);
GF_sum = 2^GF_mm-1;
for i = 2 : codeword_N 
    for j = 1 : 2 : DouCorrNum-1
        %syndrome(j) = bitxor(syndrome(j),alpha_to(mod(index_of(syndrome(j))+j,2^GF_mm-1)+1)) ;
        if syndrome(j) == 0
            syndrome(j) = HardInput(i);% by 20150413 上午，index_of的检索值不能为0
        else    
            syndrome(j) = bitxor(HardInput(i),alpha_to(mod(index_of(syndrome(j))+j,GF_sum)+1)) ;
        end
    end 
end 
%// Even syndromes 计算偶数伴随式
%//Even syndrome = (Odd syndrome) ** 2  //偶数伴随式等于奇数伴随式的平方
%%计算偶数伴随式syndrome(2j)=syndrome(j)^2=syndrome(j)*syndrome(j)
for i = 2 : 2 : DouCorrNum
    j = i / 2;
    if (syndrome(j) == 0)
        syndrome(i) = 0;
    else
        syndrome(i) =  alpha_to(mod(2 * index_of(syndrome(j)) ,GF_sum)+1);
    end   
end
%% 指示码字是否有错 %%
Syn_ErrFlag = 0;% 该码字没有错误
for i = 1 : DouCorrNum
    if (syndrome(i) ~= 0)
        Syn_ErrFlag = 1 ;	%// set flag if non-zero syndrome => error 
    end
end

end