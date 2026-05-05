function [TestWave] = dd_input_para_get(MODCOD)
%% 生成DD纠偏所需参数
% MODCOD为DVBS2X协议中标准值
% 暂不支持短帧类型

TmpWave.SysPara.MODCOD = MODCOD - mod(MODCOD,2);
[TmpWave,~] = dvbs2x_MODCOD_initialization(TmpWave);

% 计算帧长和符号数
LocalFrmLen = [32490 21690 16290 13050 10890 9360 8190;
               33282 22914 16686 13338 11142 9576 8370];
pilot_number = [22 14 11 8 7 6 5];

frm_len = LocalFrmLen(mod(MODCOD,2)+1,TmpWave.SysPara.ConType-1);

% 有导频模式
pilot_index = [];
if mod(MODCOD,2) == 1
    first_pilot = 90+1440+1; % headlen+datalen
    pilot_index = first_pilot:first_pilot+35;
    for idx = 1:pilot_number(TmpWave.SysPara.ConType-1)-1
        pilot_index = [pilot_index pilot_index(end)+1440+1:pilot_index(end)+1440+36];
    end
else
    pilot_index = [];
end
% if TmpWave.SysPara.ConType == 7 
%     frm_len = (TmpWave.SysPara.N + 90)/7 + 90;
% else
%     frm_len = TmpWave.SysPara.N/TmpWave.SysPara.ConType + 90;
% end
map_num = 2^TmpWave.SysPara.ConType;

% 生成标准星座点 
[constellation, mapping,~,~,amplitude] = dvbs2x_constellation(TmpWave.SysPara.ModScheme{1},TmpWave.SysPara.RadiusRatio{1});
con_map = zeros(1,size(mapping,2));
con_map(mapping+1) = constellation;
TestWave.con_map = con_map;
TestWave.mapping = mapping;
TestWave.map_num = map_num;
TestWave.frm_len = frm_len;
TestWave.pilot_index = pilot_index;
TestWave.ModScheme = TmpWave.SysPara.ModScheme{1};
TestWave.MODCOD = MODCOD;
   
if (TmpWave.SysPara.ConType >= 6)
    % 计算外环判决相关参数
    [judge,ratio,std_points] = outer_ring_points_para_get(con_map,TmpWave.SysPara.RadiusRatio{1},TmpWave.SysPara.ModScheme{1},amplitude);
    
    TestWave.judge = judge^2; % 取模值平方 便于硬件计算比较
    TestWave.ratio = ratio;
    TestWave.std_points = std_points;
    TestWave.amplitude = amplitude;
    TestWave.N = TmpWave.SysPara.N;
    % disp("外环判决模式");
else
    % disp("非外环判决模式");
end
