function [SysPara] = New_DVB_BCH_LDPC_Encoder_Message_Get(SysPara)
%  ////////////////////////////////////////////////////////////////////////
%  New_DVB_BCH_LDPC_Encoder_Message_Get：配置编码器相关参数
%
%  Note：基于dvbs2x_parameter_configuration简化
%
%  Input：
%    SysPara —— 系统参数
%
%  Output：
%    SysPara —— 发射机配置参数
%
%  Author: 郭志鹏
%
%  Date: 2026.01.09
%
%  Log:
%
%  ////////////////////////////////////////////////////////////////////////
%% configure
SysPara.VLSNRModeIndex = 0;
SofPL = [0 1 1 0 0 0 1 1 0 1 0 0 1 0 1 1 1 0 1 0 0 0 0 0 1 0];     % 帧起始序列

%% 生成物理层帧头 PLSHeader + VL-SNE Header(only for VL-SNR Mode)、超帧物理层帧头生成
[PLSCode,~] = dvbs2x_frameForming_plsCode(SysPara.MODCOD,SysPara.PilotType); % PLSCode
HeadPL = [SofPL PLSCode];       % 90比特物理层帧头帧头
% 对帧头进行pi/2BPSK调制
for i=1:1:13
    HeadPL(2*i-1) = (1-HeadPL(2*i-1)*2)/sqrt(2)+1i*(1-HeadPL(2*i-1)*2)/sqrt(2);
    HeadPL(2*i)   = -(1-HeadPL(2*i)*2)/sqrt(2)+1i*(1-HeadPL(2*i)*2)/sqrt(2);
end
if (SysPara.MODCOD  < 128) % S2
    for i=14:1:45
        HeadPL(2*i-1) = (1-HeadPL(2*i-1)*2)/sqrt(2)+1i*(1-HeadPL(2*i-1)*2)/sqrt(2);
        HeadPL(2*i)   = -(1-HeadPL(2*i)*2)/sqrt(2)+1i*(1-HeadPL(2*i)*2)/sqrt(2);
    end
else % S2x
    for i=14:1:45
        HeadPL(2*i-1) = -(1-HeadPL(2*i-1)*2)/sqrt(2)+1i*(1-HeadPL(2*i-1)*2)/sqrt(2);
        HeadPL(2*i)   = -(1-HeadPL(2*i)*2)/sqrt(2)-1i*(1-HeadPL(2*i)*2)/sqrt(2);
    end
end
SysPara.PLFrm.PLSHeader = HeadPL;

%% BCH编码参数
[SysPara.BCH.GenPoly, SysPara.BCH.GF_mm, SysPara.BCH.CorrectNum, SysPara.BCH.Parity, SysPara.BCH.K, SysPara.BCH.N] = dvbs2x_bch_parameter(SysPara.LDPC_LEN, SysPara.R_num);

%% LDPC编码参数
[para,SysPara.LDPC.q,SysPara.LDPC.H1_RW] = dvbs2x_ldpc_parameter(SysPara.LDPC_LEN ,SysPara.R_num ); % H矩阵生成参数
[SysPara.LDPC.H1, SysPara.LDPC.H2] = dvbs2x_ldpc_Hmatrix(para,SysPara.LDPC.q ); % 生成H1和H2
SysPara.LDPC.H = [SysPara.LDPC.H1, SysPara.LDPC.H2]; % 生成H矩阵

%% 星座映射参数
[constellation, mapping] = dvbs2x_constellation(SysPara.ModScheme,SysPara.RadiusRatio);
con_map = zeros(1,size(mapping,2));
con_map(mapping+1) = constellation; % 生成星座映射参数
SysPara.ConMap = con_map;
SysPara.mapping = mapping;

%% 物理层帧参数
[SysPara.PLFrm.frmLen ,SysPara.PLFrm.numSlotPerFrm ,SysPara.PLFrm.numPilotPerFrm ] = dvbs2x_plfrmLenCal(SysPara.LDPC_LEN ,SysPara.ConType ,SysPara.PilotType ,0);

%% 物理层加扰序列
SysPara.PLFrm.Rn  = plSrambRnSeqGen(0); % 0-6

end
