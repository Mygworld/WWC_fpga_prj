function [out_point,out_symbol,out_distance] = dvbs2x_ccsds_hard_decision_symbol(input,mapnum,constellation,mapping)
%%
out_point       = input;
out_symbol      = zeros(1,length(input));
out_distance    = zeros(1,length(input));
for idx = 1 : length(input)
    [distince,mapping_numbr] = min(abs(repmat(input(idx),1,mapnum)-constellation));
    out_point(idx)      = constellation(mapping_numbr);
    out_symbol(idx)     = mapping(mapping_numbr);
    out_distance(idx)   = distince;
end
end
