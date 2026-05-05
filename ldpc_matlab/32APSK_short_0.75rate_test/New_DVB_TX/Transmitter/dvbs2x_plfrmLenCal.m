function [frmLen,numSlotPerFrm,numPilotPerFrm] = dvbs2x_plfrmLenCal(N,conType,pilotFlag,vlsnrIndex)
SizePilot  = 36;        % 一个导频块内含有36个符号
SizeSlot   = 90;         % 一个SLOT中包含的符号数
SizeHeadPL = 90;       % 每个帧头含的符号数
%%
if conType == 7
    N = N + 90;
end
numSlotPerFrm= ceil(N/conType/SizeSlot); % 计算SLOT块数
%%
if vlsnrIndex == 0
    % Legacy 
    if  pilotFlag ==0   % 无导频时
        frmLen = SizeHeadPL + SizeSlot * numSlotPerFrm;
        numPilotPerFrm = 0;
    else
        numPilotPerFrm = ceil(numSlotPerFrm/16)-1;        % 每一帧的导频块个数
        frmLen = SizeHeadPL + SizeSlot * numSlotPerFrm + SizePilot * numPilotPerFrm;
    end

elseif vlsnrIndex <= 6
    % VLSNR Set 1
    frmLen = 33282;
    numSlotPerFrm = 21;     %
    numPilotPerFrm = 43;        % 25xPILOT_36 + 18xPILOT_34

elseif vlsnrIndex <= 9
    % VLSNR Set 2
    frmLen = 16686;
    numSlotPerFrm = 10;     %
    numPilotPerFrm = 21;        % 12xPILOT_36 + 9xPILOT_32
    
end


end

