function [TxPara] = dvbs2x_parameter_configuration_v2(S2xWaveGen)
% dvbs2x_parameter_configuration：配置发射机参数
%
% Note：
%
% Input：
%   S2xWaveGen —— 系统参数
%
% Output：
%   TxPara —— 发射机配置参数
%
% Author: Guo ZP
%
% Date: 2025.11.25
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log: 用于软解映射算法验证 不含甚低信噪比 只为了提取编译码参数
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% initialize
Num = length(S2xWaveGen.SysPara.MODCOD);            %
%
TxPara.MODCOD = zeros(1,Num);
TxPara.PilotType = zeros(1,Num);
TxPara.VLSNRModeIndex = zeros(1,Num);
% BCH
TxPara.BCH.GenPoly = cell(1,Num);
TxPara.BCH.GF_mm = zeros(1,Num); 
TxPara.BCH.CorrectNum = zeros(1,Num);
TxPara.BCH.Parity = zeros(1,Num);
TxPara.BCH.K = zeros(1,Num);
TxPara.BCH.N = zeros(1,Num);
% LDPC
TxPara.LDPC.q = zeros(1,Num);
TxPara.LDPC.N = zeros(1,Num);
TxPara.LDPC.H1_RW = cell(1,Num);
TxPara.LDPC.H1 = cell(1,Num);
TxPara.LDPC.H2 = cell(1,Num);
TxPara.LDPC.H = cell(1,Num);
% Constellation Map
TxPara.ConMap = cell(1,Num);
% Physical Layer Frame
TxPara.PLFrm.PLSHeader = cell(1,Num);
TxPara.PLFrm.VLSNRHeader = cell(1,Num);
TxPara.PLFrm.frmLen = zeros(1,Num);
TxPara.PLFrm.numSlotPerFrm = zeros(1,Num);
TxPara.PLFrm.numPilotPerFrm = zeros(1,Num);



%% configure
SofPL = [0 1 1 0 0 0 1 1 0 1 0 0 1 0 1 1 1 0 1 0 0 0 0 0 1 0];      % 帧起始序列
for idx = 1:Num
    %%
    TxPara.MODCOD(idx) = S2xWaveGen.SysPara.MODCOD(idx);                    % MODCOD
    TxPara.PilotType(idx) = S2xWaveGen.SysPara.PilotType(idx);              % PilotType
   
    %% 生成物理层帧头 PLSHeader + VL-SNE Header(only for VL-SNR Mode)、超帧物理层帧头生成
    [PLSCode,~] = dvbs2x_frameForming_plsCode(TxPara.MODCOD(idx),TxPara.PilotType(idx)); % PLSCode
    HeadPL = [SofPL PLSCode];       % 90比特物理层帧头帧头
    % 对帧头进行pi/2BPSK调制
    for i=1:1:13
        HeadPL(2*i-1) = (1-HeadPL(2*i-1)*2)/sqrt(2)+1i*(1-HeadPL(2*i-1)*2)/sqrt(2);
        HeadPL(2*i)   = -(1-HeadPL(2*i)*2)/sqrt(2)+1i*(1-HeadPL(2*i)*2)/sqrt(2);
    end
    if (TxPara.MODCOD(idx) < 128) % S2
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
    TxPara.PLFrm.PLSHeader{idx} = HeadPL;
  
    %% BCH编码参数
    [TxPara.BCH.GenPoly{idx}, TxPara.BCH.GF_mm(idx), TxPara.BCH.CorrectNum(idx), TxPara.BCH.Parity(idx), TxPara.BCH.K(idx), TxPara.BCH.N(idx)] = dvbs2x_bch_parameter(S2xWaveGen.SysPara.N(idx),S2xWaveGen.SysPara.R_num(idx));

    %% LDPC编码参数
    [para, TxPara.LDPC.q(idx), TxPara.LDPC.H1_RW{idx}] = dvbs2x_ldpc_parameter(S2xWaveGen.SysPara.N(idx),S2xWaveGen.SysPara.R_num(idx)); % H矩阵生成参数
    [TxPara.LDPC.H1{idx}, TxPara.LDPC.H2{idx}] = dvbs2x_ldpc_Hmatrix(para,TxPara.LDPC.q(idx)); % 生成H1和H2
    TxPara.LDPC.H{idx} = [TxPara.LDPC.H1{idx}, TxPara.LDPC.H2{idx}]; % 生成H矩阵

    %% 星座映射参数
    [constellation, mapping] = dvbs2x_constellation(S2xWaveGen.SysPara.ModScheme{idx},S2xWaveGen.SysPara.RadiusRatio{idx});
    con_map = zeros(1,size(mapping,2));
    con_map(mapping+1) = constellation; % 生成星座映射参数
    TxPara.ConMap{idx} = con_map;

end

end
