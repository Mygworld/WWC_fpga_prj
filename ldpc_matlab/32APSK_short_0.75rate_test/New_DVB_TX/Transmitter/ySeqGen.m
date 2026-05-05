function [yb,yc]  = ySeqGen(len)
if nargin == 0
    len = 100;
end
%------------------------------------------------------------------------------
% Procedure
%------------------------------------------------------------------------------

% Initialize variables
srBin = ones(1,18); % Shift register content
yb = zeros(1,len); % Initialize output
yc = zeros(1,len); % Initialize output  

% Generates PRBS sequence
for n=1:len
    yb(n) = mod(srBin(13)+srBin(12)+srBin(10)+srBin(9)+srBin(8)+srBin(7)+srBin(6)+srBin(5)+srBin(4)+srBin(3),2);
    yc(n) = srBin(18);  % Output
    fedBackBit = mod(srBin(8)+srBin(11)+srBin(13)+srBin(18),2); % XOR bits 14 and 15
    srBin = [fedBackBit, srBin(1:17)];
end


end