function [ poly , GF_mm, correctNum, parity_R, message_K, codeword_N ] = dvbs2x_bch_parameter(n_ldpc ,CR_Num)
switch n_ldpc
    case 32400
        GF_mm =15;%% 有限域为GF(2^15)
        correctNum =12;%% 不同码率的十种码字的可纠错数均为12个
        parity_R = GF_mm * correctNum;%% 校验位长度等于有限域维度和可纠错数的乘积
        switch CR_Num
            case 1
                message_K = 5660;
                codeword_N = 5840;
            case 2
                message_K = 7740;
                codeword_N = 7920;
            case 3
                message_K = 10620;
                codeword_N = 10800;
            otherwise
                error('dvb_s2x_bch UNKNOWN CODING RATE');
        end
    case 16200   %% 当帧长为短帧时(n_ldpc=16200)
        GF_mm =14;%% 有限域为GF(2^14)
        correctNum =12;%% 不同码率的十种码字的可纠错数均为12个
        parity_R = GF_mm * correctNum;%% 校验位长度等于有限域维度和可纠错数的乘积
        switch CR_Num
            %%%% DVB-S2 %%%%
            case 1
                message_K = 3072;
                codeword_N = 3240;
            case 2
                message_K = 5232;
                codeword_N = 5400;
            case 3
                message_K = 6312;
                codeword_N = 6480;
            case 4
                message_K = 7032;
                codeword_N = 7200;
            case 5  %%dvb-t2(3/5)
                message_K = 9552;
                codeword_N = 9720;
            case 6
                message_K = 10632;
                codeword_N = 10800;
            case 7
                message_K = 11712;
                codeword_N = 11880;
            case 8
                message_K = 12432;
                codeword_N = 12600;
            case 9
                message_K = 13152;
                codeword_N = 13320;
            case 10
                message_K = 14232;
                codeword_N = 14400;
                %%%% DVB-S2X %%%%
            case 11
                message_K = 3792;
                codeword_N = 3960;
            case 12
                message_K = 4152;
                codeword_N = 4320;
            case 13
                message_K = 4872;
                codeword_N = 5040;
            case 14
                message_K = 7392;
                codeword_N = 7560;
            case 15
                message_K = 8472;
                codeword_N = 8640;
            case 16
                message_K = 9192;
                codeword_N = 9360;
            case 17
                message_K = 11352;
                codeword_N = 11520;
                %%% VL-SNR %%%%
            case 18 % 1/5 SF2
                message_K = 2512;
                codeword_N = 2680;
            otherwise
                error('dvb_s2_bch UNKNOWN CODING RATE');
        end

    case 64800  %% 当帧长为常帧时(n_ldpc=64800)，十一种码率的可纠错数不完全相同
        GF_mm =16;%% 有限域为GF(2^16)
        correctNum =12;
        switch CR_Num
            %%%% DVB-S2 %%%%
            case 1
                message_K = 16008;
                codeword_N = 16200;
            case 2
                message_K = 21408;
                codeword_N = 21600;
            case 3
                message_K = 25728;
                codeword_N = 25920;
            case 4
                message_K = 32208;
                codeword_N = 32400;
            case 5
                message_K = 38688;
                codeword_N = 38880;
            case 6
                correctNum =10;
                message_K = 43040;
                codeword_N = 43200;
            case 7
                message_K = 48408;
                codeword_N = 48600;
            case 8
                message_K = 51648;
                codeword_N = 51840;
            case 9
                correctNum =10;
                message_K = 53840;
                codeword_N = 54000;
            case 10
                correctNum = 8;
                message_K = 57472;
                codeword_N = 57600;
            case 11
                correctNum = 8;
                message_K = 58192;
                codeword_N = 58320;
                %%%% DVB-S2X %%%%
            case 12
                message_K = 14208;
                codeword_N = 14400;
            case 13
                message_K = 18528;
                codeword_N = 18720;
            case 14
                message_K = 28968;
                codeword_N = 29160;
            case 15
                message_K = 35448;
                codeword_N = 35640;
            case {16 , 25}
                message_K = 37248;
                codeword_N = 37440;
            case 17
                message_K = 40128;
                codeword_N = 40320;
            case 18
                message_K = 41208;
                codeword_N = 41400;
            case 19
                message_K = 44808;
                codeword_N = 45000;
            case 20
                message_K = 46608;
                codeword_N = 46800;
            case { 21 , 31}
                message_K = 50208;
                codeword_N = 50400;
            case 22  %% 和1/2码率的码字是一样的
                message_K = 32208;
                codeword_N = 32400;
            case 23
                message_K = 34368;
                codeword_N = 34560;
            case 24
                message_K = 35808;
                codeword_N = 36000;
            case 26
                message_K = 41568;
                codeword_N = 41760;
            case 27
                message_K = 44448;
                codeword_N = 44640;
            case 28
                message_K = 45888;
                codeword_N = 46080;
            case { 29 , 35 }
                message_K = 47328;
                codeword_N = 47520;
            case 30
                message_K = 48408;
                codeword_N = 48600;
            case 32
                message_K = 55248;
                codeword_N = 55440;
            case 33 %% 和3/5码率的码字是一样的
                message_K = 38688;
                codeword_N = 38880;
            case 34
                message_K = 43008;
                codeword_N = 43200;
            otherwise
                error('dvb_s2_bch UNKNOWN CODING RATE');
        end
        parity_R = GF_mm * correctNum;
    otherwise
        error('dvb_s2_bch UNKNOWN FEC BLOCK LENGTH');
end

%%%%  根据不同帧长和可纠错数计算不同的生成多项式poly  %%%%
% 生成多项式见EN 302 307 v1.2.1 .pdf 的 table 6a（常帧）table 6b（短帧）。
switch n_ldpc
    case 64800
        % Non-zero powers (besides 0 and 16)
        nzp = {[2 3 5]                       ... g1=1+x^2+x^3+x^5+x^16
            [1 4 5 6 8]                   ... g2=1+x+x^4+x^5+x^6+x^8+x^16
            [2 3 4 5 7 8 9 10 11]         ... g3=1+x^2+x^3+x^4+x^5+x^7+x^8+x^9+x^l0+x^11+x^16
            [2 4 6 9 11 12 14]            ... g4=1+x^2+x^4+x^6+x^9+x^11+x^12+x^14+x^16
            [1 2 3 5 8 9 10 11 12]        ... g5=1+x+x^2+x^3+x^5+x^8+x^9+x^l0+x^11+x^12+x^16
            [2 4 5 7 8 9 10 12 13 14 15]  ... g6=1+x^2+x^4+x^5+x^7+x^8+x^9+x^l0+x^12+x^13+x^14+x^15+x^16
            [2 5 6 8 9 10 11 13 15]       ... g7=1+x^2+x^5+x^6+x^8+x^9+x^l0+x^11+x^13+x^15+x^16
            [1 2 5 6 8 9 12 13 14]        ... g8=1+x+x^2+x^5+x^6+x^8+x^9+x^12+x^13+x^14+x^16
            [5 7 9 10 11]                 ... g9=1+x^5+x^7+x^9+x^l0+x^11+x^16
            [1 2 5 7 8 10 12 13 14]       ... g10=1+x+x^2+x^5+x^7+x^8+x^10+x^12+x^13+x^14+x^16
            [2 3 5 9 11 12 13]            ... g11=1+x^2+x^3+x^5+x^9+x^11+x^12+x^13+x^16
            [1 5 6 7 9 11 12]};           ... g12=1+x+x^5+x^6+x^7+x^9+x^11+x^12+x^16
            g = zeros([12 16+1]);
        for n = 1:12
            g(n,[1 nzp{n}+1 end]) = 1;
        end

    case 32400
        % Non-zero powers (besides 0 and 15)
        nzp = {[2 3 5]                       ... g1=1+x^2+x^3+x^5+x^15
            [1 4 7 10 11]                 ... g2=1+x+x^4+x^7+x^10+x^11+x^15
            [2 4 6 8 10 12 13]            ... g3=1+x^2+x^4+x^6+x^8+x^10+x^12+x^13+x^l5
            [2 3 5 6 8 10 11]             ... g4=1+x^2+x^3+x^5+x^6+x^8+x^10+x^11+x^15
            [1 2 4 6 7 10 12]             ... g5=1+x+x^2+x^4+x^6+x^7+x^l0+x^12+x^15
            [4 6 7 12 13]                 ... g6=1+x^4+x^6+x^7+x^12+x^13+x^15
            [2 4 5 7 11 12 14]            ... g7=1+x^2+x^4+x^5+x^7+x^11+x^12+x^14+x^15
            [2 4 6 8 9 11 14]             ... g8=1+x^2+x^4+x^6+x^8+x^9+x^11+x^14+x^15
            [1 2 4 5 7 9 11 12 13]        ... g9=1+x+x^2+x^4+x^5+x^7+x^9+x^11+x^12+x^13+x^15
            [1 2 3 4 7 10 11 12 13]       ... g10=1+x+x^2+x^3+x^4+x^7+x^10+x^11+x^12+x^13+x^15
            [1 2 4 9 11]                  ... g11=1+x+x^2+x^4+x^9+x^11+x^15
            [2 4 8 10 11 13 14]};         ... g12=1+x^2+x^4+x^8+x^10+x^11+x^13+x^14+x^15
            g = zeros([12 15+1]);
        for n = 1:12
            g(n,[1 nzp{n}+1 end]) = 1;
        end

    case 16200
        % Non-zero powers (besides 0 and 14)
        nzp = {[1 3 5]                  ... g1=1+x+x^3+x^5+x^14
            [6 8 11]                 ... g2=1+x^6+x^8+x^11+x^14
            [1 2 6 9 10]             ... g3=1+x+x^2+x^6+x^9+x^10+x^14
            [4 7 8 10 12]            ... g4=1+x^4+x^7+x^8+x^10+x^12+x^14
            [2 4 6 8 9 11 13]        ... g5=1+x^2+x^4+x^6+x^8+x^9+x^11+x^13+x^14
            [3 7 8 9 13]             ... g6=1+x^3+x^7+x^8+x^9+x^13+x^14
            [2 5 6 7 10 11 13]       ... g7=1+x^2+x^5+x^6+x^7+x^10+x^11+x^13+x^14
            [5 8 9 10 11]            ... g8=1+x^5+x^8+x^9+x^10+x^11+x^14
            [1 2 3 9 10]             ... g9=1+x+x^2+x^3+x^9+x^10+x^14
            [3 6 9 11 12]            ... g10=1+x^3+x^6+x^9+x^11+x^12+x^14
            [4 11 12]                ... g11=1+x^4+x^11+x^12+x^14
            [1 2 3 5 6 7 8 10 13]};  ... g12=1+x+x^2+x^3+x^5+x^6+x^7+x^8+x^10+x^13+x^14
            g = zeros([12 14+1]);
        for n = 1:12
            g(n,[1 nzp{n}+1 end]) = 1;
        end
end
% Compute the generator polynomial by multiplying the first TErr BCH polynomials
% polynomial multiplication is a convolution
poly = gf(g(1,:),1);
for n = 2:correctNum
    poly = conv(poly, gf(g(n,:),1));%%进行卷积运算
end
poly = fliplr(logical(poly.x)); %水平翻转
poly = double(poly );   % 转换为浮点数
end