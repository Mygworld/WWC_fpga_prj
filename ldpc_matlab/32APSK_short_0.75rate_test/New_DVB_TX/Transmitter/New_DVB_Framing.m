function dataOut = New_DVB_Framing(dataIn,PLSHeader,LDPC_LEN,ModOrder,pilotFlag,pilotBlock)
%  ////////////////////////////////////////////////////////////////////////
%  New_DVB_Framing：【DVB-S2X标准】组帧
%
%  Note：基于dvbs2x_frameForming简化，去除VLSNR
%
%  Input：
%    dataIn     —— 星座映射后的数据
%    PLSHeader  —— 帧头序列
%    LDPC_LEN   —— LDPC编码的长度，64800或16200
%    ModOrder   —— 调制阶数
%    pilotFlag  —— 导频有无的信息，1表示有，0表示无
%  Output：
%    dataOut —— 映射符号数据
%
%  Author:
%
%  Date:
%
%  Log:
%
%  ////////////////////////////////////////////////////////////////////////
SizePilot  = 36;        % 一个导频块内含有36个符号
SizeSlot   = 90;        % 一个SLOT中包含的符号数
SizeHeadPL = 90;        % 每个帧头含的符号数
if ModOrder == 7
    N = LDPC_LEN + 90;
else
    N = LDPC_LEN;
end
numSlotPerFrm= ceil(N/ModOrder/SizeSlot); % 计算SLOT块数
if  pilotFlag ==0   %无导频时
    PLFrame=zeros(1,numSlotPerFrm*SizeSlot+SizeHeadPL); %存放产生的帧数据（帧个数≥1）
    sizeFrame=numSlotPerFrm*SizeSlot+SizeHeadPL;   %每帧的符号数
    for frmIdx=1:1
        PLFrame((1+(frmIdx-1)*sizeFrame):(SizeHeadPL+(frmIdx-1)*sizeFrame)) = PLSHeader;  %插入帧头
        PLFrame((SizeHeadPL+1+(frmIdx-1)*sizeFrame):(frmIdx*sizeFrame))=...      %将调制符号放入帧中
            dataIn((1+(frmIdx-1)*SizeSlot*numSlotPerFrm):(frmIdx*SizeSlot*numSlotPerFrm));
    end
else        % 含有导频的情况
    if mod(numSlotPerFrm,16)==0
        numPilotPerFrm = numSlotPerFrm/16-1;        % 当帧头位置与导频冲突时，不插导频
    else
        numPilotPerFrm = fix(numSlotPerFrm/16);        %每一帧的导频块个数
    end
    PLFrame = zeros(1,SizeHeadPL+numSlotPerFrm*SizeSlot+numPilotPerFrm*SizePilot);%存放产生的帧数据（帧个数≥1）
    sizeFrame = SizeHeadPL+numSlotPerFrm*SizeSlot+numPilotPerFrm*SizePilot;  %每帧的符号数
    for frmIdx=1:1
        frmHeadStPos = 1+(frmIdx-1)*sizeFrame;              %每帧的帧头的起始位置
        frmHeadEndPos = SizeHeadPL+(frmIdx-1)*sizeFrame;    %每帧的帧头的结束位置
        modDataStPos = 1+(frmIdx-1)*numSlotPerFrm*SizeSlot; % 每帧中第一个调制符号在modDataOut中的起始位置
        PLFrame(frmHeadStPos:frmHeadEndPos)=PLSHeader;      %插入帧头
        for pilotIdx=1:numPilotPerFrm          %插入数据和导频
            PLFrame((frmHeadEndPos +1+(pilotIdx-1)*(SizeSlot*16+SizePilot)):(frmHeadEndPos + pilotIdx*(SizeSlot*16+SizePilot)))=...
                [dataIn((modDataStPos+(pilotIdx-1)*SizeSlot*16):(modDataStPos+pilotIdx*SizeSlot*16-1))  pilotBlock];
        end
        PLFrame((frmHeadEndPos+ numPilotPerFrm*(SizeSlot*16+SizePilot)+ 1):(frmIdx*sizeFrame))=...  %%将每帧中不足16 slots的数据插入到帧中
            dataIn((modDataStPos+numPilotPerFrm*SizeSlot*16):(frmIdx*numSlotPerFrm*SizeSlot));
    end
end
dataOut = PLFrame;
end
