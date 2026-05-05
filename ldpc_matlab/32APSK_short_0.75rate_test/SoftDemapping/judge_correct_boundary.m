

%% faf 
outerpoints = constellation(abs(constellation) > 1.6);
outerpoints_1st = outerpoints((real(outerpoints) > 0 ) & (imag(outerpoints) > 0));

x_shift = 0.040;
y_shift = 0;
shift_point = complex(x_shift,y_shift);

phase_angles_rad = angle(outerpoints_1st);
[sorted_phase_rad, sort_index] = sort(phase_angles_rad);
sorted_constellation = outerpoints_1st(sort_index); % 同步排序星座点
phase_boundaries_rad = (sorted_phase_rad(2:end) + sorted_phase_rad(1:end-1)) / 2;

% 可视化：绘制星座图及相位边界
figure;
% 1. 绘制星座点
scatter(real(sorted_constellation), imag(sorted_constellation), 100, 'filled', 'b');
hold on;
grid on;
axis equal;
xlabel('同相分量 (I)');
ylabel('正交分量 (Q)');
title('标准星座点及相位边界');

% 为每个点添加标签
% for k = 1:length(sorted_constellation)
%     text(real(sorted_constellation(k)), imag(sorted_constellation(k))+0.1, ...
%          sprintf('点%d (%.1f°)', k, sorted_phase_rad(k)), ...
%          'HorizontalAlignment', 'center');
% end

% 2. 绘制从原点出发的相位边界线（射线）
for k = 1:length(phase_boundaries_rad)
    boundary_angle = phase_boundaries_rad(k);
    % 绘制一条足够长的线
    line_len = max(abs([real(sorted_constellation), imag(sorted_constellation)])) * 1.2;
    x_end = line_len * cos(boundary_angle);
    y_end = line_len * sin(boundary_angle);
    plot([-x_shift, x_end], [-y_shift, y_end], 'r--', 'LineWidth', 1);
    % text(x_end*0.8, y_end*0.8, sprintf('%.1f°', phase_boundaries_rad(k)), ...
    %      'Color', 'r', 'BackgroundColor', 'white');
end

% 3. 绘制坐标轴
plot([-0.5, 1.2*max(real(sorted_constellation))], [0,0], 'k-'); % x-axis
plot([0,0], [-0.5, 1.2*max(imag(sorted_constellation))], 'k-'); % y-axis
legend('星座点', '相位边界', 'Location', 'best');
hold on;

% fprintf('\n=== 硬判决使用方法 ===\n');
% fprintf('对于一个接收到的复数信号，计算其相位角（使用 angle 函数，并转换为度）。\n');
% fprintf('然后将其与上述相位边界值进行比较，即可判定它属于哪个星座点。\n');

constellation_1st = constellation((real(constellation) > 0) & (imag(constellation) > 0));
plot((constellation_1st),'g*')
hold off;

% constellation_1st = constellation((real(constellation) > 0) & (imag(constellation) > 0));
% plot((constellation_1st + 0.0723),'g*')
% hold off;