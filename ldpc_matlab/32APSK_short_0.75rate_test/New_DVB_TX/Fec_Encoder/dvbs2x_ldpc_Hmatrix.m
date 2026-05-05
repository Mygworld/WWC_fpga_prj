function [H1, H2] = dvbs2x_ldpc_Hmatrix(para,q)
%% dvbs2x_ldpc_Hmatrix.m使用说明
% 程序功能说明：生成DVB-S2X标准里规定的LDPC码的校验矩阵
% 程序接口说明：
%           输入  para ： DVB-S2X标准附录B和C中LDPC码的生成参数
%                 q：由码率决定的常量（q=（N*(1-R)/360）
%           输出 H1：校验矩阵H的一部分（H=[H1 H2]）
%                H2：校验矩阵H的一部分（H=[H1 H2]）
% 上层程序：
% 子程序：无
% 创建者：安宁
% 创建日期：2015-03-20
% 最后修改日期：
% 审核者：
% 版权所有：西安电子科技大学ISN国家重点实验室宽带无线传输研究中心


M = q*360;%校验位长度
[para_rows,para_cols] = cellfun(@size,para);%读取para参数的行数和列数
para_len = para_rows.*para_cols;%每个para数据块的元素个数
H1_col = [];
H1_row = [];
st = 0;
for i = 1:length(para_rows)
%% 生成H1矩阵中‘1’列位置信息   
    H1_col_part = reshape(repmat(1+st*360:(st+para_rows(i))*360,para_cols(i),1),1,para_len(i)*360);
    st = st + para_rows(i);
    H1_col = [H1_col H1_col_part];
%% 生成H1矩阵中‘1’行位置信息
    H1_row_part =reshape( mod((repmat(para{i},1,360) +  reshape(repmat(q*(0:359),para_len(i),1),para_rows(i),para_cols(i)*360))',M)+1 , 1 ,para_len(i)*360);
    H1_row = [H1_row H1_row_part];
end
H1 = sparse(H1_row,H1_col,1);
%% 生成H2矩阵中‘1’列位置信息
H2_col = [reshape(repmat(1:M-1,2,1),1,2*(M-1)) M];
%% 生成H2矩阵中‘1’行位置信息
H2_row_d1 = [1:M-1;2:M];
H2_row = [reshape(H2_row_d1,1,2*M-2) M];
%% 生成H2矩阵
H2 = sparse(H2_row,H2_col,1);