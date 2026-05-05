function [recei_signal,awgnOut] = dvbs2x_channel_sim(sig,simpara,normFsym)

%% AWGN
if isreal(sig)
    % 中频信号
    snr = simpara.EsNo_dB - 10*log10(0.5/normFsym);
else
    % 基带信号
    snr = simpara.EsNo_dB - 10*log10(1/normFsym);
end
awgnOut = awgn(sig, snr, 'measured');%加噪
% reqSNR = 10^(snr/10);
% sigPower = sum(abs(sig(:)).^2)/numel(sig);
% noisePower = sigPower/reqSNR;
% noise = sqrt(noisePower/2)* (randn(size(sig)));     %考虑到中频信号取实部造成的噪声损失3dB 噪声功率取1/2
% awgnOut = sig + noise;
%
%% frequency offset
if simpara.normFreq ~=0 || simpara.phase ~=0
    offsetOut = dvbs2x_addFreqOffset(awgnOut,1,simpara,1,normFsym);
else
    offsetOut = awgnOut;
end

%% 定时偏
% if simpara.timingfixDelay ~=0 || simpara.timingErr ~=0
%     add_timing_error(real(offsetOut),imag(offsetOut), length(offsetOut), simpara.timingfixDelay, simpara.timingErr, 0,0);
%     [cResultRe, cResultIm] = add_timing_error(real(offsetOut),imag(offsetOut),length(offsetOut),simpara.timingfixDelay,simpara.timingErr,1,1);
%     recei_signal           = real(cResultRe + 1i*cResultIm);
% else
    recei_signal = offsetOut;
% end
end