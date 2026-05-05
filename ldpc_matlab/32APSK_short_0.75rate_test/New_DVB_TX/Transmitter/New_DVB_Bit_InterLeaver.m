function [dataOut] = New_DVB_Bit_InterLeaver(dataIn,LDPC_LEN,New_DVB_MODCOD,Work)
%  ////////////////////////////////////////////////////////////////////////
%  New_DVB_Bit_InterLeaver ：【DVB-S2X标准】比特交织器
%
%  Note：
%    基于dvbs2x_interleaver简化
%
%  Input：
%    dataIn —— 待比特交织数据
%    LDPC_LEN —— 码长
%    New_DVB_MODCOD —— DVB-S2X协议标准MODCOD
%    Work —— 比特交织器是否工作
%  Output：
%    dataOut —— 比特交织后输出
%
%  Author: 郭志鹏
%
%  Date : 2026.01.09
%
%  Log:
%
%  ////////////////////////////////////////////////////////////////////////
if Work == false
    % 比特交织器不工作，直接退出
    dataOut = dataIn;
    return;
end

%%  配置交织顺序
if New_DVB_MODCOD < 128 % DVB S2
    TMP_MODCOD = fix(New_DVB_MODCOD/4);
else % DVB S2X
    TMP_MODCOD = New_DVB_MODCOD - mod(New_DVB_MODCOD,2);
end
switch TMP_MODCOD
    case {1,2,3,4,5,6,7,8,9,10,11,132,134,136,60,61,62,63,64,65,66,33,34,35,36,37,38,39,40,41,...
            42,216,218,220,222,224,226,128,130}
        interleave = 0;
    case {12,44}
        interleave = 321;
    case {13,14,15,16,17,138,140,142,45,46,47,48,234}
        interleave = 123;
    case {144,146,228,230,232}
        interleave = 213;
    case {18,19,20,21,22,23,158,164,50,51,52,53,54,244}
        interleave = 1234;
    case {154,242}
        interleave = 4312;
    case {148,156,170}
        interleave = 4321;
    case 160
        interleave = 4123;
    case {162,168}
        interleave = 4132;
    case {150,166}
        interleave = 3421;
    case 172
        interleave = 1432;
    case 152
        interleave = 3412;
    case {24,25,26,27,28,56,57,58,59}
        interleave = 12345;
    case 174
        interleave = 32541;
    case {178,180}
        interleave = 51423;
    case 182
        interleave = 51324;
    case 184
        interleave = 416325;
    case 190
        interleave = 312654;
    case 194
        interleave = 235164;
    case 198
        interleave = 532164;
    case 186
        interleave = 631254;
    case 200
        interleave = 5361427;
    case 202
        interleave = 5241367;
    case 204
        interleave = 51483267;
    case 208
        interleave = 57431682;
    case 210
        interleave = 86753412;
    case 214
        interleave = 61854723;
    case {206,212}
        interleave = 12345678;
    case {236,238}
        interleave = 3214;
    case 240
        interleave = 3241;
    case 246
        interleave = 52341;
    case 248
        interleave = 21534;
    otherwise
        error('Not valid interleave way')
end

%% 交织
dataOut = zeros(1,length(dataIn));
if interleave==0
    dataOut = dataIn;
elseif interleave<999  %8psk
    l = LDPC_LEN/3;
    a = mod(interleave,10);
    b = floor(interleave/10);
    b = mod(b,10);
    c = floor(interleave/100);
    dataOut(1:3:end)= dataIn(l*(c-1)+1:l*c);
    dataOut(2:3:end)= dataIn(l*(b-1)+1:l*b);
    dataOut(3:3:end)= dataIn(l*(a-1)+1:l*a);
elseif interleave<9999 %16apsk
    l = LDPC_LEN/4;
    a = mod(interleave,10);
    b = floor(interleave/10);
    b = mod(b,10);
    c = floor(interleave/100);
    c = mod(c,10);
    d = floor(interleave/1000);
    dataOut(1:4:end)=dataIn(l*(d-1)+1:l*d);
    dataOut(2:4:end)= dataIn(l*(c-1)+1:l*c);
    dataOut(3:4:end)= dataIn(l*(b-1)+1:l*b);
    dataOut(4:4:end)= dataIn(l*(a-1)+1:l*a);
elseif interleave<99999 %32apsk
    l = LDPC_LEN/5;
    a = mod(interleave,10);
    b = floor(interleave/10);
    b = mod(b,10);
    c = floor(interleave/100);
    c = mod(c,10);
    d = floor(interleave/1000);
    d = mod(d,10);
    e = floor(interleave/10000);
    dataOut(1:5:end) = dataIn(l*(e-1)+1:l*e);
    dataOut(2:5:end) = dataIn(l*(d-1)+1:l*d);
    dataOut(3:5:end) = dataIn(l*(c-1)+1:l*c);
    dataOut(4:5:end) = dataIn(l*(b-1)+1:l*b);
    dataOut(5:5:end) = dataIn(l*(a-1)+1:l*a);
elseif interleave<999999 %64apsk
    l = LDPC_LEN/6;
    a = mod(interleave,10);
    b = floor(interleave/10);
    b = mod(b,10);
    c = floor(interleave/100);
    c = mod(c,10);
    d = floor(interleave/1000);
    d = mod(d,10);
    e = floor(interleave/10000);
    e = mod(e,10);
    f = floor(interleave/100000);
    dataOut(1:6:end) = dataIn(l*(f-1)+1:l*f);
    dataOut(2:6:end) = dataIn(l*(e-1)+1:l*e);
    dataOut(3:6:end) = dataIn(l*(d-1)+1:l*d);
    dataOut(4:6:end) = dataIn(l*(c-1)+1:l*c);
    dataOut(5:6:end) = dataIn(l*(b-1)+1:l*b);
    dataOut(6:6:end) = dataIn(l*(a-1)+1:l*a);
elseif interleave<9999999 %128apsk
    dataOut=zeros(1,LDPC_LEN+6);
    dataIn = [dataIn zeros(1,6)];
    l = (LDPC_LEN+6)/7;
    a = mod(interleave,10);
    b = floor(interleave/10);
    b = mod(b,10);
    c = floor(interleave/100);
    c = mod(c,10);
    d = floor(interleave/1000);
    d = mod(d,10);
    e = floor(interleave/10000);
    e = mod(e,10);
    f = floor(interleave/100000);
    f = mod(f,10);
    g = floor(interleave/1000000);
    dataOut(1:7:end) = dataIn(l*(g-1)+1:l*g);
    dataOut(2:7:end) = dataIn(l*(f-1)+1:l*f);
    dataOut(3:7:end) = dataIn(l*(e-1)+1:l*e);
    dataOut(4:7:end) = dataIn(l*(d-1)+1:l*d);
    dataOut(5:7:end) = dataIn(l*(c-1)+1:l*c);
    dataOut(6:7:end) = dataIn(l*(b-1)+1:l*b);
    dataOut(7:7:end) = dataIn(l*(a-1)+1:l*a);
    dataOut = [dataOut ones(1,84)];
elseif interleave<99999999 %256apsk
    l = LDPC_LEN/8;
    a = mod(interleave,10);
    b = floor(interleave/10);
    b = mod(b,10);
    c = floor(interleave/100);
    c = mod(c,10);
    d = floor(interleave/1000);
    d = mod(d,10);
    e = floor(interleave/10000);
    e = mod(e,10);
    f = floor(interleave/100000);
    f = mod(f,10);
    g = floor(interleave/1000000);
    g = mod(g,10);
    h = floor(interleave/10000000);
    dataOut(1:8:end) = dataIn(l*(h-1)+1:l*h);
    dataOut(2:8:end) = dataIn(l*(g-1)+1:l*g);
    dataOut(3:8:end) = dataIn(l*(f-1)+1:l*f);
    dataOut(4:8:end) = dataIn(l*(e-1)+1:l*e);
    dataOut(5:8:end) = dataIn(l*(d-1)+1:l*d);
    dataOut(6:8:end) = dataIn(l*(c-1)+1:l*c);
    dataOut(7:8:end) = dataIn(l*(b-1)+1:l*b);
    dataOut(8:8:end) = dataIn(l*(a-1)+1:l*a);
end

end






