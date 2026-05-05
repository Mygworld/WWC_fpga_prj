function out = eliminate0(datain)
%删除最高位0
for idx=1:length(datain)
    if datain(end) ~=0
        out = datain;
        break
    elseif datain(end) ==0
        datain(end) = [];
    end 
end