function EbNo = dvbs2x_ldpc_EbNo(MODCOD)
switch MODCOD
    case 1
        EbNo=0:0.1:15;
    case 2
        EbNo=0:0.1:15;
    case 3
        EbNo=1:0.1:15;
    case 4
        EbNo=2.5:0.1:15;
    case 5
        EbNo=3:0.1:15;
    case 6
        EbNo=3:0.1:15;
    case 7
        EbNo=2:0.1:15;
    case 8
        EbNo=2:0.1:15;
    case 9
        EbNo=4:0.1:15;
    case 10
        EbNo=4:0.1:15;
    case 11
        EbNo=3.5:0.1:15;
    case 12
        EbNo=3.5:0.1:15;
    case 13
        EbNo=4:0.1:15;
    case 14
        EbNo=5:0.1:15;
    case 15
        EbNo=5:0.1:15;
    case 16
        EbNo=5:0.1:15;
    case 17
        EbNo=2.5:0.1:15;
    case 18
        EbNo=3:0.1:15;
    case 19
        EbNo=3:0.1:15;
    case 20
        EbNo=3:0.1:15;
    case 21
        EbNo=4:0.1:15;
    case 22
        EbNo=5:0.1:15;
    case 23
        EbNo=6:0.1:15;
    case 24
        EbNo=6:0.1:15;
    case 25
        EbNo=7:0.1:15;
    case 26
        EbNo=7:0.1:15;
    case 27
        EbNo=8:0.1:15;
    case 28
        EbNo=8:0.1:15;
    case 29
        EbNo=9:0.1:15;
    case 30
        EbNo=7:0.1:15;
    case 31
        EbNo=10:0.1:15;
    case 32
        EbNo=10:0.1:15;
    case 33
        EbNo=9:0.1:15;
    case 34
        EbNo=10:0.1:15;
    case 35
        EbNo=10:0.1:15;
    case 36
        EbNo=10:0.1:15;
    case 37
        EbNo=10:0.1:15;
    case 38
        EbNo=10:0.1:15;
    case 39
        EbNo=0:0.1:15;
    case 40
        EbNo=0:0.1:15;
    case 41
        EbNo=0:0.1:15;
    case 42
        EbNo=1:0.1:15;
    case 43
        EbNo=1:0.1:15;
    case 44
        EbNo=1:0.1:15;
    case 45
        EbNo=2:0.1:15;
    case 46
        EbNo=2.5:0.1:15;
    case 47
        EbNo=3:0.1:15;
    case 48
        EbNo=3:0.1:15;
    case 49
        EbNo=3:0.1:15;
    case 50
        EbNo=3.5:0.1:15;
    case 51
        EbNo=3.5:0.1:15;
    case 52
        EbNo=4:0.1:15;
    case 53
        EbNo=4:0.1:15;
    case 54
        EbNo=5:0.1:15;
    case 55
        EbNo=5.5:0.1:15;
    case 56
        EbNo=5.5:0.1:15; % 32APSK 3/4 的 SNR 测试区间
    otherwise
        error('comm:dvbs2xldpc:UnsupportedMODCOD', ...
            'MODCOD not supported');
end


