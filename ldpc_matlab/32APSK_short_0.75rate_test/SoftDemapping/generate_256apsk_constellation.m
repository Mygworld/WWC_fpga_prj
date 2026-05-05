%% 辅助函数定义
function [constellation, mapping] = generate_256apsk_constellation(radii, points_per_ring)
    % 生成256APSK星座图
    constellation = [];
    mapping = [];
    point_id = 0;
    
    for ring = 1:length(radii)
        radius = radii(ring);
        num_points = points_per_ring(ring);
        
        for i = 0:num_points-1
            angle = 2 * pi * i / num_points;
            point = radius * (cos(angle) + 1i * sin(angle));
            constellation = [constellation; point];
            mapping = [mapping; point_id];
            point_id = point_id + 1;
        end
    end
    
    % 归一化星座图功率
    avg_power = mean(abs(constellation).^2);
    constellation = constellation / sqrt(avg_power);
end