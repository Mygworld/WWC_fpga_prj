

function llr = bit_sd_soft_decision(r, hard_bits, constellation, mapping, opposite_table, noise_var)
    % BIT-SD算法的软判决部分
    num_bits = 8;
    llr = zeros(1, num_bits);
    
    hard_decimal = hard_bits * (2.^(7:-1:0))';
    % 找到硬判决对应的星座点索引
    % hard_decimal = bin2dec(hard_bits);
    [~, hard_index] = ismember(hard_decimal, mapping);

    s_hard = constellation(hard_index);
    d_hard = abs(r - s_hard)^2;
    
    for bit = 1:num_bits
        % 获取最近相反点
        opposite_index = opposite_table(hard_index, bit);
        
        s_opposite = constellation(opposite_index);
        
        % 计算距离平方
        d_opposite = abs(r - s_opposite)^2;
        
        % 计算LLR（考虑硬判决的比特值）
        if hard_bits(bit)
            llr(bit) = (d_hard - d_opposite) / noise_var;
        else
            llr(bit) = (d_opposite - d_hard) / noise_var;
        end
    end
end