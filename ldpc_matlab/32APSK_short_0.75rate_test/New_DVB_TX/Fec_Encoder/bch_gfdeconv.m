function r = bch_gfdeconv(a,b)
%% bch_gfdeconv: 有限域除法
%
% Note：right msb
%   Matlab Inner Func:
%   1. fliplr 
% 
% Input：
%   a —— 被除数
%   b —— 除数
% Output：
%   r —— 余数
%
% Author: 甄文晔
%
% Date: 2023.9.20
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log:
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%删除除数的最高位0 
b=eliminate0(b);

divisor_len = length(b);
while true
    a=eliminate0(a);
    dividend_len = length(a);
    if length(b)>length(a) %循环结束条件，a的最高位小于b则结束
        r=a;
        break
    else
       for cnt = 1:divisor_len
          a(dividend_len-cnt+1)= xor (a(dividend_len-cnt+1),b(divisor_len-cnt+1));
       end
    end
end
