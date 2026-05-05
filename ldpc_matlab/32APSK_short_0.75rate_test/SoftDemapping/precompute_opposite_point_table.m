
function opposite_point_table = precompute_opposite_point_table(constellation, mapping)
    % 预计算查找表：对于每个星座点和每个比特位，找到最近的相反比特星座点
    M = length(constellation);
    num_bits = 8; % 256APSK有8个比特
    
    opposite_point_table = zeros(M, num_bits);
    
    for i = 1:M
        current_point = constellation(i);
        current_label = dec2bin(mapping(i), 8); % 当前点的8位二进制标签
        
        for bit = 1:num_bits
            % 找到所有在当前比特位上与当前点值相反的点
            opposite_mask = false(M, 1);
            for j = 1:M
                opposite_label = dec2bin(mapping(j), 8);
                if opposite_label(bit) ~= current_label(bit)
                    opposite_mask(j) = true;
                end
            end
            
            % 在这些相反点中找到距离最近的一个
            opposite_indices = find(opposite_mask);
            if ~isempty(opposite_indices)
                distances = abs(current_point - constellation(opposite_indices));
                [~, min_idx] = min(distances);
                opposite_point_table(i, bit) = opposite_indices(min_idx);
            end
        end
    end
end