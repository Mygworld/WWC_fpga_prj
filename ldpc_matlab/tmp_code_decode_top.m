clc;clear;close all;
%% add path
addpath(genpath('D:\wwc_prj\vivado_vhdl\ldpc_matlab\tmp_code_decode\New_DVB_TX'));
addpath(genpath('D:\wwc_prj\vivado_vhdl\ldpc_matlab\tmp_code_decode\SoftDemapping'));

%% param init
WorkFlag    = true;
MODCOD_List = 98;
TxFrames = [];

for i = 1:length(MODCOD_List)
    %% sim param
    Target_Errors = 50;      % 
    Max_Frames    = 50000;   % 
    Batch_Size    = 8;       % parallel
    %FrmNum                          = 20;  % 每个MODCOD帧数
    NewWaveGen.MODCOD               = MODCOD_List(i); %  4 48 72 96 184 200 204
    NewWaveGen.Encoder_Work_Flag    = 1;
    NewWaveGen.PLScram_Work_Flag    = 0;

    
    %% 3. 数据源生成 (DVB-S2X 组帧)
    
    [SysPara]   = New_DVB_Modcod_Message_Get(NewWaveGen.MODCOD);
    [SysPara]   = New_DVB_BCH_LDPC_Encoder_Message_Get(SysPara);
    TxSymLen    = SysPara.PLFrm.frmLen - 90;

    K = size(SysPara.LDPC.H1, 2);
    N = size(SysPara.LDPC.H, 2);
    
    % noise param
    % EbNo = 4.5:0.1:20;
    EbNo = dvbs2x_ldpc_EbNo(56);
    EsNo_dB = EbNo + 10*log10(K/N*SysPara.ConType);
    %EsNo_dB = 50;

    tx_ref_syms = zeros(FrmNum, TxSymLen);

    ber_double = zeros(1,length(EsNo_dB));
    error_num_double = 0;
    total_num_double = 0;
    all_error_num_double = 0;
    all_total_num_double = 0;

    ber_fixed = zeros(1,length(EsNo_dB));
    error_num_fixed = 0;
    total_num_fixed = 0;
    all_error_num_fixed = 0;
    all_total_num_fixed = 0;
    %% parallel calu
    parpool;
    for idx = 10:length(EbNo)
        error_num_double = 0;
        total_num_double = 0;
        all_error_num_double = 0;
        all_total_num_double = 0;

        error_num_fixed = 0;
        total_num_fixed = 0;
        all_error_num_fixed = 0;
        all_total_num_fixed = 0;
    
        fprintf('Generating DVB-S2X TX Frames (MODCOD = %d,EsNo = %d)...\n', NewWaveGen.MODCOD,EsNo_dB(idx));
        for num = 1:FrmNum
            TxFrame = New_DVB_Transmitter_Top(NewWaveGen);
            % tx_ref_syms(num,:) = TxFrame.TxSymbol;
            TxFrames = TxFrame.TxSymbol;
            rx_symbols  = awgn(TxFrames , EsNo_dB(idx), 'measured'); % add awgn noise
            % demod(fpga)
            LLR = dvbs2x_demod_MAX(rx_symbols,SysPara.ModScheme,SysPara.ConMap,10^(- EsNo_dB(idx) / 10));
            
            % double
            [~,rx_log_map_bits] = dvbs2x_decode_top(LLR,SysPara,WorkFlag,0);
            error_num_double = sum(TxFrame.TxRawBit ~= rx_log_map_bits);
            total_num_double = SysPara.BCH.K;
            all_error_num_double = all_error_num_double + error_num_double;
            all_total_num_double = all_total_num_double + total_num_double;
            % fixed(2.4)
            dvbs2_deil_LLR2 = decimalcut(LLR,3);% fixed 2.4
            [~,rx_log_map_bits] = dvbs2x_decode_top(dvbs2_deil_LLR2,SysPara,WorkFlag,1);
            error_num_fixed = sum(TxFrame.TxRawBit ~= rx_log_map_bits);
            total_num_fixed = SysPara.BCH.K;
            all_error_num_fixed = all_error_num_fixed + error_num_fixed;
            all_total_num_fixed = all_total_num_fixed + total_num_fixed;

            
        end
        ber_double(idx) = all_error_num_double/all_total_num_double;
        ber_fixed(idx) = all_error_num_fixed/all_total_num_fixed;
        fprintf('current ber_double = %d,ber_fixed = %d...\n',ber_double(idx),ber_fixed(idx));
        if ber_double(idx)==0
            break;
        end
    end
    %% figure 
    % figure(MODCOD)
    %
    % semilogy(EsNo_dB,Pe,'rdiamond-','linewidth',2);
    % hold on
    % grid on
    % xlabel('Es/No,dB');
    % ylabel('Bit Error Rate');
    % s = ['save dvbs2x_modcod_MAX_' int2str(MODCOD) '.mat  EsNo_dB Pe'];
    % eval(s);
    % ---------------------------------------------------------------
    figure('Name', 'LDPC Architecture Performance', 'Position', [150, 150, 900, 400]);

    % legend1:ber of 32APSK short 3/4rate double_ldpc
    subplot(1,2,1);
    semilogy(EsNo_dB, ber_double, 'b-o', 'LineWidth', 2, 'MarkerSize', 7);hold on; 
    semilogy(EsNo_dB, ber_fixed,  'r-*', 'LineWidth', 2, 'MarkerSize', 7);
    grid on; xlabel('Eb/No (dB)'); ylabel('BER');
    title('ber of 32APSK short 3/4rate double_ldpc or fixed_ldpc');
    legend('ber_double','ber_fixed');

    

end

