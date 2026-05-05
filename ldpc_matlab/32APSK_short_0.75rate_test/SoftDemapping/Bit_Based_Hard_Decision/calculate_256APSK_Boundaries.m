function Boundary = calculate_256APSK_Boundaries(constellation,mod_scheme)
% calculate_256APSK_Boundaries_Symmetric 利用对称性计算256APSK的相位和幅值边界
%   输入:
%       constellation - 复数数组，表示256APSK星座点
%   输出:
%       Boundary - 结构体，包含以下字段:
%           phase_boundaries        : 相位边界值(适用于标准256APSK星座点)
%           amplitude_boundaries    : 幅值边界值(适用于标准256APSK星座点)
%           phase_boundaries_p1     : 相位边界值(适用于非标准256APSK星座点中相位大于pi/4的星座点)
%           amplitude_boundaries_p1 : 幅值边界值(适用于非标准256APSK星座点中相位大于pi/4的星座点)
%           phase_boundaries_p2     : 相位边界值(适用于非标准256APSK星座点中相位小于pi/4的星座点)
%           amplitude_boundaries_p2 : 幅值边界值(适用于非标准256APSK星座点中相位小于pi/4的星座点)

    M           = log2(length(constellation));
    X_shift     = 0.042; % 偏移因子
    Y_shift     = 0; % 偏移因子
    Sym_shift   = complex(X_shift,Y_shift);

    amplitude_boundaries    = zeros(1,M);
    amplitude_boundaries_p1 = zeros(1,M);
    amplitude_boundaries_p2 = zeros(1,M);
    phase_boundaries        = zeros(1,M);
    % phase_boundaries_p1     = zeros(1,M);
    % phase_boundaries_p2     = zeros(1,M);

    %% 确定幅值边界
    constellation_1st       = complex(abs(real(constellation)),abs(imag(constellation)));
    constellation_1st_p1    = constellation_1st(angle(constellation_1st) >= pi/4);
    constellation_1st_p2    = constellation_1st(angle(constellation_1st) <  pi/4);

    sorted_constellation    = sort(constellation_1st, 'ComparisonMethod', 'abs');
    sorted_constellation_p1 = sort(constellation_1st_p1, 'ComparisonMethod', 'abs');
    sorted_constellation_p2 = sort(constellation_1st_p2, 'ComparisonMethod', 'abs');

    amplitudes_all          = abs(sorted_constellation);
    amplitudes_p1           = abs(sorted_constellation_p1);
    amplitudes_p2           = abs(sorted_constellation_p2);

    amplitude_diff_all      = diff(amplitudes_all);
    amplitude_diff_p1       = diff(amplitudes_p1);
    amplitude_diff_p2       = diff(amplitudes_p2);

    [~, boundary_index_all] = findpeaks(amplitude_diff_all, 'MinPeakHeight', max(amplitude_diff_all)/4);
    [~, boundary_index_p1]  = findpeaks(amplitude_diff_p1, 'MinPeakHeight', 0);
    [~, boundary_index_p2]  = findpeaks(amplitude_diff_p2, 'MinPeakHeight', 0);

    boundary_radii_all      = [amplitudes_all(1);amplitudes_all(boundary_index_all + 1)];
    amplitude_boundaries    = (boundary_radii_all(1:end-1) + boundary_radii_all(2:end))/2;

    if (mod_scheme == "256apsk_3")
        boundary_radii_p1   = [amplitudes_p1(1);amplitudes_p1(boundary_index_p1 + 1)];
        boundary_radii_p2   = [amplitudes_all(4);amplitudes_p2(1);amplitudes_p2(boundary_index_p2 + 1)];
    
        amplitude_boundaries_p1(1)  = (boundary_radii_p1( 2) + boundary_radii_p1( 3))/2;
        amplitude_boundaries_p1(2)  = (boundary_radii_p1( 4) + boundary_radii_p1( 5))/2;
        amplitude_boundaries_p1(3)  = (boundary_radii_p1( 8) + boundary_radii_p1( 9))/2;
        amplitude_boundaries_p1(4)  = (boundary_radii_p1(12) + boundary_radii_p1(13))/2;
        amplitude_boundaries_p1(5)  = (boundary_radii_p1(16) + boundary_radii_p1(17))/2;
        amplitude_boundaries_p1(6)  = (boundary_radii_p1(20) + boundary_radii_p1(21))/2;
        amplitude_boundaries_p1(7)  = (boundary_radii_p1(24) + boundary_radii_p1(25))/2;
        amplitude_boundaries_p1(8)  = (boundary_radii_p1(28) + boundary_radii_p1(29))/2;
    
        amplitude_boundaries_p2(1)  = (boundary_radii_p2( 1) + boundary_radii_p2( 2))/2;
        amplitude_boundaries_p2(2)  = (boundary_radii_p2( 5) + boundary_radii_p2( 6))/2;
        amplitude_boundaries_p2(3)  = (boundary_radii_p2( 9) + boundary_radii_p2(10))/2;
        amplitude_boundaries_p2(4)  = (boundary_radii_p2(13) + boundary_radii_p2(14))/2;
        amplitude_boundaries_p2(5)  = (boundary_radii_p2(17) + boundary_radii_p2(18))/2;
        amplitude_boundaries_p2(6)  = (boundary_radii_p2(21) + boundary_radii_p2(22))/2;
        amplitude_boundaries_p2(7)  = (boundary_radii_p2(25) + boundary_radii_p2(26))/2;
        amplitude_boundaries_p2(8)  = (boundary_radii_p2(29) + boundary_radii_p2(30))/2;
    elseif (mod_scheme == "256apsk_2")
        boundary_radii_p1   = [amplitudes_p1(1);amplitudes_p1(boundary_index_p1 + 1)];
        boundary_radii_p2   = [amplitudes_p2(1);amplitudes_p2(boundary_index_p2 + 1)];
    
        amplitude_boundaries_p1   = amplitude_boundaries;
        amplitude_boundaries_p2   = amplitude_boundaries;
    else
        amplitude_boundaries_p1   = amplitude_boundaries;
        amplitude_boundaries_p2   = amplitude_boundaries;
    end

    %% 确定相位边界
    outerpoints         = sorted_constellation(abs(sorted_constellation) > amplitude_boundaries(end));
    outerpoints         = outerpoints(1:4:end);
    outerpoints_middle  = (outerpoints(1:end-1) + outerpoints(2:end))/2;
    phase_boundaries    = angle(outerpoints_middle + Sym_shift);

    % num_phase_sectors   = 32; % [32 32 32 32 32 32 32 32];
    % phase_steps         = 2*pi./num_phase_sectors;
    % phase_boundaries    = phase_steps*(1:7);
    

    %% 将结果存入结构体
    Boundary.phase_boundaries = phase_boundaries;
    Boundary.amplitude_boundaries = amplitude_boundaries;
    Boundary.amplitude_boundaries_p1 = amplitude_boundaries_p1;
    Boundary.amplitude_boundaries_p2 = amplitude_boundaries_p2;
    Boundary.Sym_shift = Sym_shift;
end