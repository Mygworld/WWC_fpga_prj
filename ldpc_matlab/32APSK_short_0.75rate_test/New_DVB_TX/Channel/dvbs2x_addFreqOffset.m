function out = dvbs2x_addFreqOffset(in,framidx,simpara,sim4work,normFsym)
persistent anglelast;
if framidx==1
    anglelast = 0;
end
if sim4work==0
    normFreq = simpara.normFreq;
else
    normFreq = normFsym*simpara.normFreq;
end
angle = zeros(1,length(in));
for idxangle = 1:length(in)
    if idxangle == 1
        angle(idxangle) = anglelast + 2*pi*normFreq;
    else
        angle(idxangle) = angle(idxangle-1) + 2*pi*normFreq;
    end
    if angle(idxangle)>2*pi
        angle(idxangle) = angle(idxangle) - 2*pi;
    elseif angle(idxangle)<0
        angle(idxangle) = angle(idxangle) + 2*pi;
    end
end
out = in.*exp(1j*(angle+simpara.phase));%加偏
anglelast = angle(end);