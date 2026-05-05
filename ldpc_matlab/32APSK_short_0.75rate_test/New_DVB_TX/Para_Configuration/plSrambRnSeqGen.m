function  Rn  = plSrambRnSeqGen(PLScrSeq)

%%
n = 10949*PLScrSeq; % Gold sequence index 0-6

Len = 180000;
len = 4e4;
MaxN = 66000;

%%
[~,xc]  = xSeqGen(Len+MaxN); % length = 180000
[~,yc]  = ySeqGen(Len);
zn = mod(xc(1+n:Len+n)+yc,2);
Rn = 2*zn(1+131072:131072+len) + zn(1:len);

% zn = mod([xc(1+n:2^18-1) xc(1:length(n))]+yc,2);