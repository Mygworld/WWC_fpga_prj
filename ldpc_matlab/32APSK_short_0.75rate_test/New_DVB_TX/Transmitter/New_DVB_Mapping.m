function dataOut = New_DVB_Mapping(dataIn,ModOrder,StdConstellation)
%  ////////////////////////////////////////////////////////////////////////
%  New_DVB_Mapping：【DVB-S2X标准】比特映射 QPSK-256APSK
%
%  Note：基于dvbs2x_bitMapping简化，去除VLSNR
%
%  Input：
%    dataIn  —— 比特数据
%    ModOrder —— 调制阶数
%    mapping —— 映射星座点
%  Output：
%    dataOut —— 映射符号数据
%
%  Author:
%
%  Date:
%
%  Log:
%
%  ////////////////////////////////////////////////////////////////////////

%% 生成星座点
signal = reshape(dataIn,ModOrder,length(dataIn)/ModOrder);
signal = signal(ModOrder:-1:1,:);
signal_value = bi2de(signal')+1;
%% 星座映射
dataOut = StdConstellation(signal_value);

