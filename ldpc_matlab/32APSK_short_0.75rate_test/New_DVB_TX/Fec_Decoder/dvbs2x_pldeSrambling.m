function plSrambDataOut = dvbs2x_pldeSrambling(frameDataOut,Para,simFrmNum,plSrambRn,work)
%% pldeSrambling 【物理帧解扰】
%
% Note: 利用发射端扰码序列恢复接收端加扰的数据及导频符号
%      
%
% Input：
%   frameDataOut —— 待解扰数据
%   Para —— 当前物理帧参数集合
%   simFrmNum —— 输入帧数量，默认为1
%   faultTolerant ——  帧同步容错个数
%   work —— 解扰工作状态指示符号
%
% Output：
%   plSrambDataOut —— 解扰数据输出
%
%
% Author: 甄文晔
%
% Date: 2023.10.8
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log: v1.1 增加函数输入输出接口说明
% 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if work ~=1
    plSrambDataOut = frameDataOut;
else
    SizeHeadPL = Para.SizeHeadPL;
    frmLen = length(frameDataOut)/simFrmNum;
    Rn = plSrambRn;
    plSrambDataOut = frameDataOut;
    for idxFrmNum = 1:simFrmNum
        for jdxFemLeb = SizeHeadPL+1:frmLen
            switch Rn(jdxFemLeb - SizeHeadPL)
                case 0
                    plSrambDataOut((idxFrmNum-1)*frmLen + jdxFemLeb) = frameDataOut((idxFrmNum-1)*frmLen + jdxFemLeb);
                case 1
                    plSrambDataOut((idxFrmNum-1)*frmLen + jdxFemLeb) = -1j * frameDataOut((idxFrmNum-1)*frmLen + jdxFemLeb);
                case 2
                    plSrambDataOut((idxFrmNum-1)*frmLen + jdxFemLeb) = -frameDataOut((idxFrmNum-1)*frmLen + jdxFemLeb);
                case 3
                    plSrambDataOut((idxFrmNum-1)*frmLen + jdxFemLeb) = 1j * frameDataOut((idxFrmNum-1)*frmLen + jdxFemLeb);
            end
        end
    end
end
end