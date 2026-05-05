function pndata = pn_generater_test(Polynomial,needlen)
%% pn (m) 序列生成
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 说明
%input
%     Polynomia: 生成多项式设置 如 z^4+z^2+1
%     needlen  : 输出PN序列长度
%output
%     pndata   : 生成的PN序列
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

n=length(Polynomial); %生成多项式长度
len=2^n-1; % 得到最终生成的m序列的长度     
backQ=0; % 对应寄存器运算后的值，放在第一个寄存器
seq=zeros(1,len); % 给生成的m序列预分配
registers = ones(1,n); % 给寄存器分配初始结果
for i=1:len
    backQ = mod(sum(Polynomial.*registers), 2); %特定寄存器的值进行异或运算，即相加后模2
    registers(2:end) = registers(1:end-1); % 移位
    registers(1)=backQ; % 把异或的值放在第一个寄存器的位置
    seq(i)=backQ;
end
data_tmp = seq; % 输出序列结果

if needlen <= length(data_tmp) % 取得需要长度的pn序列
    pndata = data_tmp(1:needlen);
% else
%     disp("数据长度超出PN23序列长度范围！")
%     return
% end
elseif needlen > length(data_tmp)
    if needlen-length(data_tmp) <= length(data_tmp)
        pndata = [data_tmp,data_tmp(1:needlen-length(data_tmp))];
    else
        pndata1 = data_tmp;
        for i = 1: floor((needlen-length(data_tmp))./length(data_tmp))
            if i <= floor((needlen-length(data_tmp))./length(data_tmp))
                 pndata1 = cat(2,pndata1,data_tmp);%数据拼接
            end
        end
        residualen = (needlen-length(data_tmp))-(floor((needlen-length(data_tmp))./length(data_tmp))*length(data_tmp));
        pndata = cat(2,pndata1,data_tmp(1:residualen));
    end

end
end 
