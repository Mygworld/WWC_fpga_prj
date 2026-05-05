function [ldpc_decode_out,bch_decode_out] = New_DVB_Decode_Top(LLR,SysPara,WorkFlag) 
%  ////////////////////////////////////////////////////////////////////////
%  New_DVB_Decode_Top : 临时译码顶层，测试用
%  Note: 源自DVBall.m
%    
%  input： 
%      LLR              : 待纠偏数据
%      SysPara          : BCH、LDPC译码参数
%      WorkFlag         ：工作开关
%  output：
%      ldpc_decode_out  : LDPC译码输出
%      bch_decode_out   ：BCH译码输出
%
% Author: 郭志鹏
%
% Date: 2025.11.25
%
%  ////////////////////////////////////////////////////////////////////////
    LDPC_iteration  = 90;
    %% LDPC译码
    H = SysPara.LDPC.H;
    [H_row,H_col,~] = find(H');  % 查找校验矩阵数据为1的行列序号
    H_SparseMat     = [H_row H_col];    % 将行列序号组为矩阵，该矩阵数据均为1，无需储存
    [M,N]           = size(H);   % 校验矩阵维度
    tmp_ldpc_out    = dvbs2ldpc_decode_NMSA_Modify(M,N,H_SparseMat,LLR,SysPara.LDPC.H1_RW, ...
                        SysPara.LDPC.q,LDPC_iteration,WorkFlag); % LDPC 译码

    %% BCH译码
    ldpc_decode_out = tmp_ldpc_out(size(tmp_ldpc_out,1),:); % 取出decode_ldpc的最后一行
    bch_decode_out  = dvbs2x_bch_decoder(SysPara.BCH.GF_mm,SysPara.BCH.CorrectNum, SysPara.BCH.Parity, ...
                        SysPara.BCH.K, SysPara.BCH.N, ldpc_decode_out(size(ldpc_decode_out,1),:),WorkFlag); % BCH译码
 
end