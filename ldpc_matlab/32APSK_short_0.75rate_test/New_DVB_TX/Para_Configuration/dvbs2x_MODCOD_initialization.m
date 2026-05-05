function [S2xWaveGen,lock] = dvbs2x_MODCOD_initialization(S2xWaveGen)
% dvbs2x_MODCOD_initialization：根据MODCOD初始化相关参数
%
% Note：
%   1. VLSNRModeIndex = 0，表示当前传输模式为传统模式（甚低信噪比模式关）。
%   [VL-SNR set1] MODCOD = 129，30780 symbols		
% 				VLSNRModeIndex = 1 -> QPSK 2/9 normal                       VLSNRModeIndex = 2 -> BPSK 1/5 medium
% 				VLSNRModeIndex = 3 -> BPSK 11/45 medium                     VLSNRModeIndex = 4 -> BPSK 1/3 medium
% 				VLSNRModeIndex = 5 -> BPSK 1/5 (Spreading Factor2) short    VLSNRModeIndex = 6 -> BPSK 11/45 (Spreading Factor2) short
%   [VL-SNR set2] MODCOD = 131，14976 symbols		
% 				VLSNRModeIndex = 7 -> BPSK 1/5 short                        VLSNRModeIndex = 8 -> BPSK 4/15 short
% 				VLSNRModeIndex = 9 -> BPSK 1/3 short
%   2. 这里的'bpsk'实际为pi/2-bpsk。
% Input：
%   S2xWaveGen —— 系统参数
% Output：
%   S2xWaveGen —— 系统参数
%   lock —— 锁定符
% Author: 甄文晔
%
% Date:
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log:
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% initiallize
lock = 1;                                       %
Num = length(S2xWaveGen.SysPara.MODCOD);        % MODCOD数量
S2xWaveGen.SysPara.N = zeros(1,Num);
S2xWaveGen.SysPara.R_num = zeros(1,Num);
S2xWaveGen.SysPara.ModScheme = cell(1,Num);
S2xWaveGen.SysPara.ConType = zeros(1,Num);
S2xWaveGen.SysPara.RadiusRatio = cell(1,Num);
S2xWaveGen.SysPara.CodeRateStr = cell(1,Num);
S2xWaveGen.SysPara.PilotType = zeros(1,Num);
%
for idx = 1:Num
    % 初始化导频模式 PilotType
    S2xWaveGen.SysPara.PilotType(idx) = mod(S2xWaveGen.SysPara.MODCOD(idx),2); % 当MODCOD为偶数时，无导频；反之为有导频模式
    S2xWaveGen.SysPara.MODCOD(idx) = S2xWaveGen.SysPara.MODCOD(idx)-S2xWaveGen.SysPara.PilotType(idx);
    S2xWaveGen.SF.PilotType(idx) = S2xWaveGen.SysPara.PilotType(idx);
    %
    tmpMODCOD = S2xWaveGen.SysPara.MODCOD(idx);
    %% DVB S2
    if tmpMODCOD < 128
        % S2xWaveGen.SysPara.MODCOD(idx) = fix(tmpMODCOD/4);
        if (mod(tmpMODCOD,4)==0) % normal frame length
            N = 64800;
        else
            N = 16200;
        end
        switch fix(tmpMODCOD/4)
            case 0 %Dummy Frame
                R_num = 1;ModScheme = 'qpsk';conType = 1;radiusRatio = [];codeRateStr = '1/4'; %对于Dummy Frame,此为无效变量
            case 1 %1/4
                R_num = 1; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '1/4';
            case 2 %1/3
                R_num = 2; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '1/3';
            case 3%2/5
                R_num = 3; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '2/5';
            case 4%1/2
                R_num = 4; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '1/2';
            case 5%3/5
                R_num = 5; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '3/5';
            case 6%2/3
                R_num = 6; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '2/3';
            case 7%3/4
                R_num = 7; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '3/4';
            case 8%4/5
                R_num = 8; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '4/5';
            case 9%5/6
                R_num = 9; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '5/6';
            case 10%8/9
                R_num = 10; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '8/9';
            case 11%9/10
                R_num = 11; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '9/10';
            case 12%3/5
                R_num = 5; ModScheme = '8psk'; conType = 3; radiusRatio = [];  codeRateStr = '3/5';
            case 13%2/3
                R_num = 6; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '2/3';
            case 14%3/4
                R_num = 7; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '3/4';
            case 15%5/6
                R_num = 9; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '5/6';
            case 16%8/9
                R_num = 10; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '8/9';
            case 17%9/10
                R_num = 11; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '9/10';
            case 18%2/3
                R_num = 6; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.15; codeRateStr = '2/3';
            case 19%3/4
                R_num = 7; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 2.85; codeRateStr = '3/4';
            case 20%4/5
                R_num = 8; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 2.75; codeRateStr = '4/5';
            case 21%5/6
                R_num = 9; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 2.70; codeRateStr = '5/6';
            case 22%8/9
                R_num = 10; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 2.60; codeRateStr = '8/9';
            case 23%9/10
                R_num = 11; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 2.57; codeRateStr = '9/10';
            case 24%dvbs2 3/4
                R_num = 7; ModScheme = '32apsk_1'; conType = 5; radiusRatio = [2.84 5.27]; codeRateStr = '3/4';
            case 25%dvbs2 4/5
                R_num = 8; ModScheme = '32apsk_1'; conType = 5; radiusRatio = [2.72 4.87]; codeRateStr = '4/5';
            case 26%dvbs2 5/6
                R_num = 9; ModScheme = '32apsk_1'; conType = 5; radiusRatio = [2.64 4.64]; codeRateStr = '5/6';
            case 27%dvbs2 8/9
                R_num = 10; ModScheme = '32apsk_1'; conType = 5; radiusRatio = [2.54 4.33];codeRateStr = '8/9';
            case 28%dvbs2 9/10 -- only for 64800
                R_num = 11; ModScheme = '32apsk_1'; conType = 5; radiusRatio = [2.53 4.30]; codeRateStr = '9/10';
            otherwise
                lock = 0;
        end
    else
    %% DVB S2X
        switch tmpMODCOD
            case 128%vl-snr 32400mode 
                switch S2xWaveGen.SysPara.VLSNRModeIndex(idx)
                    case 1
                        N = 64800;R_num = 12; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '2/9';
                    case 2
                        N = 32400;R_num = 1; ModScheme = 'bpsk'; conType = 1; radiusRatio = []; codeRateStr = '1/5';
                    case 3
                        N = 32400;R_num = 2; ModScheme = 'bpsk'; conType = 1; radiusRatio = []; codeRateStr = '11/45';
                    case 4
                        N = 32400;R_num = 3; ModScheme = 'bpsk'; conType = 1; radiusRatio = []; codeRateStr = '1/3';
                    case 5
                        N = 16200;R_num = 18; ModScheme = 'bpsk-s'; conType = 1; radiusRatio = []; codeRateStr = '1/5';
                    case 6
                        N = 16200;R_num = 11; ModScheme = 'bpsk-s'; conType = 1; radiusRatio = []; codeRateStr = '11/45';
                    otherwise
                        lock = 0;
                end
            case 130%vl-snr 16200
                switch S2xWaveGen.SysPara.VLSNRModeIndex(idx)
                    case 7
                        N = 16200;R_num = 1; ModScheme = 'bpsk'; conType = 1; radiusRatio = []; codeRateStr = '1/5';
                    case 8
                        N = 16200;R_num = 12; ModScheme = 'bpsk'; conType = 1; radiusRatio = []; codeRateStr = '4/15';
                    case 9
                        N = 16200;R_num = 2; ModScheme = 'bpsk'; conType = 1; radiusRatio = []; codeRateStr = '1/3';
                    otherwise
                        lock = 0;
                end
            case 132
                N = 64800; R_num = 13; ModScheme = 'qpsk'; conType = 2; radiusRatio = [];  codeRateStr = '13/45';
            case 134%9/20
                N = 64800; R_num = 14; ModScheme = 'qpsk'; conType = 2; radiusRatio = [];  codeRateStr = '9/20';
            case 136%11/20
                N = 64800; R_num = 15; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '11/20';
            case 138%100/180
                N = 64800; R_num = 24; ModScheme = '8apsk'; conType = 3; radiusRatio = [5.32 6.8]; codeRateStr = '5/9L';
            case 140%104/180
                N = 64800; R_num = 25; ModScheme = '8apsk'; conType = 3; radiusRatio = [6.39 8.0]; codeRateStr = '26/45L';
            case 142%23/36
                N = 64800; R_num = 18; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '23/36';
            case 144%25/36
                N = 64800; R_num = 19; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '25/36';
            case 146%13/18
                N = 64800; R_num = 20; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '13/18';
            case 148%90/180
                N = 64800; R_num = 22; ModScheme = '16apsk_2'; conType = 4; radiusRatio = 2.19; codeRateStr = '1/2L';
            case 150%96/180
                N = 64800; R_num = 23; ModScheme = '16apsk_2'; conType = 4; radiusRatio = 2.19; codeRateStr = '8/15L';
            case 152%100/180
                N = 64800; R_num = 24; ModScheme = '16apsk_2'; conType = 4; radiusRatio = 2.19; codeRateStr = '5/9L';
            case 154%26/45
                N = 64800; R_num = 16; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.7; codeRateStr = '26/45';
            case 156%dvbs2 3/5
                N = 64800; R_num = 5; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.7; codeRateStr = '3/5';
            case 158%18/30
                N = 64800; R_num = 33; ModScheme = '16apsk_3'; conType = 4; radiusRatio = []; codeRateStr = '3/5L';
            case 160%28/45
                N = 64800; R_num = 17; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.5; codeRateStr = '28/45';
            case 162%23/36
                N = 64800; R_num = 18; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.1; codeRateStr = '23/36';
            case 164%20/30
                N = 64800; R_num = 34; ModScheme = '16apsk_4'; conType = 4; radiusRatio = []; codeRateStr = '2/3L';
            case 166%25/36
                N = 64800; R_num = 19; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.1; codeRateStr = '25/36';
            case 168%13/18
                N = 64800; R_num = 20; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 2.85; codeRateStr = '13/18';
            case 170%140/180
                N = 64800; R_num = 31; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.6; codeRateStr = '7/9';
            case 172%154/180
                N = 64800; R_num = 32; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.2; codeRateStr = '77/90';
            case 174%dvbs2x 2/3
                N = 64800; R_num = 6; ModScheme = '32apsk_2'; conType = 5; radiusRatio = [2.85 5.55]; codeRateStr = '2/3L';
            case 178%128/180
                N = 64800; R_num = 28; ModScheme = '32apsk_3'; conType = 5; radiusRatio = [2.6 2.99 5.6]; codeRateStr = '32/45L';
            case 180%132/180
                N = 64800; R_num = 29; ModScheme = '32apsk_3'; conType = 5; radiusRatio = [2.6 2.86 5.6]; codeRateStr = '11/15';
            case 182%140/180
                N = 64800; R_num = 31; ModScheme = '32apsk_3'; conType = 5; radiusRatio = [2.8 3.08 5.6]; codeRateStr = '7/9';
            case 184%128/180
                N = 64800; R_num = 28; ModScheme = '64apsk_1'; conType = 6; radiusRatio = [1.88 2.72 3.95]; codeRateStr = '32/45L';
            case 186%132/180
                N = 64800; R_num = 29; ModScheme = '64apsk_3'; conType = 6; radiusRatio = [2.4 4.3 7]; codeRateStr = '11/15';
            case 190%7/9
                N = 64800; R_num = 21; ModScheme = '64apsk_2'; conType = 6; radiusRatio = [2.2 3.6 5.2]; codeRateStr = '7/9';
            case 194 %dvbs2 4/5
                N = 64800; R_num = 8; ModScheme = '64apsk_2'; conType = 6; radiusRatio = [2.2 3.6 5.2]; codeRateStr = '4/5';
            case 198%dvbs2 5/6
                N = 64800; R_num = 9; ModScheme = '64apsk_2'; conType = 6; radiusRatio = [2.2 3.5 5.0]; codeRateStr = '5/6';
            case 200%135/180
                N = 64800; R_num = 30; ModScheme = '128apsk'; conType = 7; radiusRatio = [1.715 2.118 2.681 2.75 3.819]; codeRateStr = '3/4';
            case 202%140/180
                N = 64800; R_num = 31; ModScheme = '128apsk'; conType = 7; radiusRatio = [1.715 2.118 2.681 2.75 3.733]; codeRateStr = '7/9';
            case 204%116/180
                N = 64800; R_num = 26; ModScheme = '256apsk_1'; conType = 8; radiusRatio = [1.791 2.405 2.980 3.569 4.235 5.078 6.536]; codeRateStr = '29/45L';
            case 206%20/30
                N = 64800; R_num = 34; ModScheme = '256apsk_2'; conType = 8; radiusRatio = []; codeRateStr = '2/3L';
            case 208%124/180
                N = 64800; R_num = 27; ModScheme = '256apsk_1'; conType = 8; radiusRatio = [1.791 2.405 2.980 3.569 4.235 5.078 6.536]; codeRateStr = '31/45L';
            case 210%128/180
                N = 64800; R_num = 28; ModScheme = '256apsk_1'; conType = 8; radiusRatio = [1.794 2.409 2.986 3.579 4.045 4.6 5.4]; codeRateStr = '32/45';
            case 212%22/30
                N = 64800; R_num = 35; ModScheme = '256apsk_3'; conType = 8; radiusRatio = []; codeRateStr = '11/15L';
            case 214%135/180
                N = 64800; R_num = 30; ModScheme = '256apsk_1'; conType = 8; radiusRatio = [1.794 2.409 2.986 3.579 4.045 4.5 5.2]; codeRateStr = '3/4';
            case 216%11/45
                N = 16200; R_num = 11; ModScheme = 'qpsk'; conType = 2;  radiusRatio = []; codeRateStr = '11/45';
            case 218%4/15
                N = 16200; R_num = 12; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '4/15';
            case 220%14/45
                N = 16200; R_num = 13; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '14/45';
            case 222%7/15
                N = 16200; R_num = 14; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '7/15';
            case 224%8/15
                N = 16200; R_num = 15; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '8/15';
            case 226%32/45
                N = 16200; R_num = 17; ModScheme = 'qpsk'; conType = 2; radiusRatio = []; codeRateStr = '32/45';
            case 228%7/15
                N = 16200; R_num = 14; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '7/15';
            case 230%8/15
                N = 16200; R_num = 15; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '8/15';
            case 232%26/45
                N = 16200; R_num = 16; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '26/45';
            case 234%32/45
                N = 16200; R_num = 17; ModScheme = '8psk'; conType = 3; radiusRatio = []; codeRateStr = '32/45';
            case 236%7/15
                N = 16200; R_num = 14; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.32; codeRateStr = '7/15';
            case 238%8/15
                N = 16200; R_num = 15; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.50; codeRateStr = '8/15';
            case 240%26/45
                N = 16200; R_num = 16; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.7; codeRateStr = '26/45';
            case 242%dvbs2 3/5
                N = 16200; R_num = 5; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 3.7; codeRateStr = '3/5';
            case 244%32/45
                N = 16200; R_num = 17; ModScheme = '16apsk_1'; conType = 4; radiusRatio = 2.85; codeRateStr = '32/45';
            case 246%dvbs2 2/3
                N = 16200; R_num = 6; ModScheme = '32apsk_2'; conType = 5; radiusRatio = [2.84 5.54]; codeRateStr = '2/3';
            case 248%32/45
                N = 16200; R_num = 17; ModScheme = '32apsk_2'; conType = 5; radiusRatio = [2.84 5.26]; codeRateStr = '32/45';
            otherwise
                lock = 0;
        end
    end
    % 输入MODCOD不匹配
    if lock == 0
        return;
    end
    % 更新
    S2xWaveGen.SysPara.N(idx) = N;
    S2xWaveGen.SysPara.R_num(idx) = R_num;
    S2xWaveGen.SysPara.ModScheme{idx} = ModScheme;
    S2xWaveGen.SysPara.ConType(idx)  = conType;
    if isempty(radiusRatio)
        S2xWaveGen.SysPara.RadiusRatio{idx} = [];
    else
        S2xWaveGen.SysPara.RadiusRatio{idx} = radiusRatio;
    end
    S2xWaveGen.SysPara.CodeRateStr{idx} = codeRateStr;
end

% S2xWaveGen.fs = S2xWaveGen.fsym*S2xWaveGen.BBFilter.Oversampling;                  % 采样率 =符号速率*上采样倍数

end