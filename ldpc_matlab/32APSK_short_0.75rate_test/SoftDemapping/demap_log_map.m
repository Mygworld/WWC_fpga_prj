
function llr = demap_log_map(r, constellation, mapping, noise_var)
    % 标准LOG-MAP算法
    M = length(constellation);
    num_bits = 5;
    llr = zeros(1, num_bits);
    
    for bit = 1:num_bits
        sum_exp_0 = 0;
        sum_exp_1 = 0;
        
        for i = 1:M
            distance = abs(r - constellation(i))^2;
            prob = exp(-distance / noise_var);
            
            current_label = dec2bin(mapping(i), 8);
            if current_label(bit) == '0'
                sum_exp_0 = sum_exp_0 + prob;
            else
                sum_exp_1 = sum_exp_1 + prob;
            end
        end
        
        llr(bit) = log(sum_exp_0 / sum_exp_1);
    end
end