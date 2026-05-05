
function llr = demap_max_log_map(r, constellation, mapping, noise_var)
    % 标准MAX-LOG-MAP算法
    M = length(constellation);
    num_bits = 8;
    llr = zeros(1, num_bits);
    
    for bit = 1:num_bits
        min_dist_0 = inf;
        min_dist_1 = inf;
        
        for i = 1:M
            distance = abs(r - constellation(i))^2;
            current_label = dec2bin(mapping(i), 8);
            
            if current_label(bit) == '0'
                if distance < min_dist_0
                    min_dist_0 = distance;
                end
            else
                if distance < min_dist_1
                    min_dist_1 = distance;
                end
            end
        end
        
        llr(bit) = (min_dist_1 - min_dist_0) / noise_var;
    end
end