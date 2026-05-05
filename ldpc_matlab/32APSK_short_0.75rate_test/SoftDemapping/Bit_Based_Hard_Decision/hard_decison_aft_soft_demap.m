function hard_symbol = hard_decison_aft_soft_demap(llr)
    hard_decision = llr;
    hard_bits(hard_decision >= 0) = 0;
    hard_bits(hard_decision < 0) = 1;
    hard_symbol = reshape(hard_bits,8,64800/8);
    hard_symbol = (2.^(7:-1:0))*hard_symbol + 1;
end