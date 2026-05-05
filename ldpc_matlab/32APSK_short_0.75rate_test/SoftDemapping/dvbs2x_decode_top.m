function [ldpc_decode_out,bch_decode_out] = dvbs2x_decode_top(LLR,TxPara,WorkFlag,fixed_flag) 
    %% 临时译码顶层，测试用
    % 
    % 从DVBall.m中摘出来的
    % 2025.11.25 by GZP

    LDPC_iteration  = 60;
    %% LDPC译码
    if iscell(TxPara.LDPC.H)
    H = TxPara.LDPC.H{1}; % 如果是元胞数组，提取内容
    else
    H = TxPara.LDPC.H;    % 如果已经是数值矩阵，直接赋值
    end
    if iscell(TxPara.LDPC.H1_RW)
    H1_RW = TxPara.LDPC.H1_RW{1}; % 如果是元胞数组，提取内容
    else
    H1_RW = TxPara.LDPC.H1_RW;    % 如果已经是数值矩阵，直接赋值
    end
    [H_row,H_col,~] = find(H');  % 查找校验矩阵数据为1的行列序号
    H_SparseMat     = [H_row H_col];    % 将行列序号组为矩阵，该矩阵数据均为1，无需储存
    [M,N]           = size(H);   % 校验矩阵维度
    if fixed_flag == 1
        ldpc_decode_out = dvbs2ldpc_decode_NMSA_Modify_fixed(M,N,H_SparseMat,LLR,H1_RW, ...
                        TxPara.LDPC.q,LDPC_iteration,WorkFlag); % LDPC fixed译码
    else
        ldpc_decode_out = dvbs2ldpc_decode_NMSA_Modify(M,N,H_SparseMat,LLR,H1_RW, ...
                        TxPara.LDPC.q,LDPC_iteration,WorkFlag); % LDPC double译码
    end
    %% BCH译码
    deBchIn         = ldpc_decode_out(size(ldpc_decode_out,1),:); % 取出decode_ldpc的最后一行
    bch_decode_out  = dvbs2x_bch_decoder(TxPara.BCH.GF_mm,TxPara.BCH.CorrectNum, TxPara.BCH.Parity, ...
                        TxPara.BCH.K, TxPara.BCH.N, deBchIn(size(deBchIn,1),:),WorkFlag); % BCH译码
 
end