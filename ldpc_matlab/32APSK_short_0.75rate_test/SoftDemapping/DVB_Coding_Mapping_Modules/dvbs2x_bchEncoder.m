function [dataOut] = dvbs2x_bchEncoder(dataIn,GF_mm,poly,correctNum,BCH_N,work)
%% dvbs2x_bchEncoder：【DVB-S2X标准】BCH编码
%
% Note：
%   Matlab Inner Func:
%   1. fliplr 
% 
% Input：
%   dataIn —— 基带帧
%   GF_mm —— GF域阶数
%   poly —— BCH码生成多项式
%   correctNum —— 可纠错个数
%   work —— BCH编码器是否工作
% Output：
%   dataOut —— BCH编码后输出
%
% Author: 甄文晔
%
% Date: 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log:
% 替换gfdeconv内部函数
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if work == true
    % BCH编码器工作
    lm_bch_input = [dataIn zeros(1,GF_mm*correctNum)];    % 先预置校验码空间
    r= bch_gfdeconv(fliplr(lm_bch_input),fliplr(poly));
    %[~,r] = gfdeconv(fliplr(lm_bch_input),fliplr(poly)); % 有限域除法 在GF(2)域 除数、被除数翻转
    dataOut = [dataIn fliplr([r zeros(1,GF_mm*correctNum-length(r))])];  % 前面放信息位，后面放校验码
else
    % BCH编码器不工作
    dataOut = [dataIn zeros(1,BCH_N-length(dataIn))];
end


end
