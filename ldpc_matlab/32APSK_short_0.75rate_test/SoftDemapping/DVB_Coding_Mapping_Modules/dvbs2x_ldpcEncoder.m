function dataOut = dvbs2x_ldpcEncoder(dataIn,H1,VLSNRIndex,work)
% dvbs2x_ldpcEncoder：【DVB-S2X标准】LDPC编码
%
% Note：
%   Matlab Inner Func:
%   1. xor
%   2. mod
% Input：
%   dataIn —— 待LDPC编码数据
%   H1 —— 校验矩阵参数
%   VLSNRIndex —— 甚低信噪比模式序号
%   work —— LDPC编码器工作情况
% Output：
%   dataOut —— LDPC编码数据
%
% Author:
%
% Date:
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log:
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Add filler bits for shortened LDPC codes
if VLSNRIndex == 2
    dataIn = [zeros(1,640),dataIn];
elseif VLSNRIndex == 5
    dataIn = [zeros(1,560),dataIn];
end
%% 校验位生成
parity = mod(H1*double(dataIn)',2);
for i=1:size(H1,1)-1
    parity(i+1)=xor(parity(i+1),parity(i));
end
%% 针对VL-SNR模式下校验位进行打孔
if VLSNRIndex~=0
    switch VLSNRIndex
        case 1
            P=15;
            Xp=3240;
        case 2
            P=25;
            Xp=980;
        case 3
            P=15;
            Xp=1620;
        case 4
            P=13;
            Xp=1620;
        case 5
            P=30;
            Xp=250;
        case 6
            P=15;
            Xp=810;
        case 7
            P=10;
            Xp=1224;
        case 8
            P=8;
            Xp=1224;
        case 9
            P=8;
            Xp=1224;
    end
    idx = 1;
    while Xp>0
        parity(idx)=[];
        idx = idx+P-1;
        Xp = Xp-1;
    end
end
%% 信息位+校验位
if work == true
    % LDPC编码器工作
    dataOut=[dataIn parity.'];
else
    % LDPC编码器不工作
    dataOut=[dataIn zeros(1,length(parity))];
end
%% Remove filler bits and perform puncturing for VL-SNR frames
if VLSNRIndex == 2
    dataOut = dataOut(641:end);
elseif VLSNRIndex == 5
    dataOut = dataOut(561:end);
end




end