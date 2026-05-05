function [xa,xc]  = xSeqGen(len)
if nargin == 0
    len = 100;
end
%------------------------------------------------------------------------------
% Procedure
%------------------------------------------------------------------------------

% Initialize variables
srBin = [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]; % Shift register content
xa = zeros(1,len); % Initialize output
xc = zeros(1,len); % Initialize output
% Generates PRBS sequence
for n=1:len
    xa(n) = mod(srBin(14)+srBin(12)+srBin(3),2);
%     xb(n) = mod()
    xc(n) = srBin(18);  % Output-1
    fedBackBit = xor(srBin(11), srBin(18)); 
    srBin = [fedBackBit, srBin(1:17)];
end

end