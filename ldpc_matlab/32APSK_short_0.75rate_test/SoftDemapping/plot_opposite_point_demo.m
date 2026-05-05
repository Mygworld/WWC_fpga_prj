function plot_opposite_point_demo(constellation, mapping, opposite_table)
% 演示函数：随机选择几个星座点，图示其在不同比特位上的“最近相反点”

    figure('Position', [100, 100, 1200, 800]);
    num_demos = 4; % 演示4个例子
    % 随机选择4个星座点进行演示（避免选择0，1等特殊点）
    demo_point_indices = randperm(length(constellation)-2, num_demos) + 1;

    for demo = 1:num_demos
        subplot(2, 2, demo);
        hold on;
        grid on;
        axis equal;

        % 当前演示的参考点
        i = demo_point_indices(demo);
        current_point = constellation(i);
        current_bits = dec2bin(mapping(i), 8); % 获取8位二进制标签

        % 绘制整个星座图背景
        scatter(real(constellation), imag(constellation), 30, [0.7, 0.7, 0.7], 'o');
        
        % 高亮显示当前参考点 s_i （用红色五角星）
        plot(real(current_point), imag(current_point), 'pr', 'MarkerSize', 15, 'LineWidth', 3);
        text(real(current_point)+0.05, imag(current_point), sprintf('s_{%d}', i), 'FontSize', 10, 'FontWeight', 'bold');

        % 随机选择2个比特位进行演示（例如第3位和第6位）
        demo_bits = [3, 6];
        colors = ['b', 'g']; % 为不同比特位分配不同颜色
        markers = ['^', 's']; % 为不同比特位分配不同标记

        for bit_idx = 1:length(demo_bits)
            j = demo_bits(bit_idx);
            % 从查找表中获取第j比特位的“最近相反点”索引
            k = opposite_table(i, j);
            opposite_point = constellation(k);
            opposite_bits = dec2bin(mapping(k), 8);

            % 高亮显示这个“最近相反点” s_k （用特定颜色和形状）
            plot(real(opposite_point), imag(opposite_point), ...
                 markers(bit_idx), 'Color', colors(bit_idx), ...
                 'MarkerSize', 12, 'LineWidth', 2.5);
            text(real(opposite_point)+0.05, imag(opposite_point), ...
                 sprintf('s_{%d}(b_%d)', k, j), 'Color', colors(bit_idx), ...
                 'FontSize', 9);

            % 绘制从参考点到相反点的连线，并标注距离
            line([real(current_point), real(opposite_point)], ...
                 [imag(current_point), imag(opposite_point)], ...
                 'Color', colors(bit_idx), 'LineStyle', '--', 'LineWidth', 1);
            dist = norm(current_point - opposite_point);
            mid_point = (current_point + opposite_point) / 2;
            text(real(mid_point), imag(mid_point), sprintf('d=%.3f', dist), ...
                 'Color', colors(bit_idx), 'FontSize', 8, 'BackgroundColor', 'white');
        end

        title(sprintf('点 s_{%d} (Bits: %s)', i, current_bits));
        xlabel('同相分量 (I)');
        ylabel('正交分量 (Q)');
        legend('星座点', '参考点 s_i', 'b_3 最近反点', 'b_6 最近反点', ...
               'Location', 'bestoutside');
    end
    sgtitle('BIT-SD 查找表验证：星座点与其在不同比特位上的“最近相反点”');
end