function LLR = dvbs2x_ldpc_sparse_Matrix_Sum(row,col,val,LLR)
%% sparse_Matrix_Sum.m
%
% Note:
%      替换sparse函数并进行求和得到硬判决信息，
%     
%
% Input：
%   row ——  行序号
%   col ——  列序号
%   val —— 对应数据的值
%   LLR —— 软判决得到的对数似然比
%
% Output：
%   LLR —— 输出硬判信息
%
%
% Author: zhen wen ye
%
% Date: 2023.10.28
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log: v1.1 添加函数输入输出接口说明，去除冗余程序步骤
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SparesMat = [row col val']; % 将行列序号以及对应位置的数据组成矩阵
[~,indexI] = sort(row); %  行序号位置从小到大排序
SparesMatSort = SparesMat(indexI,:); % 从第一开始每行数据的位置
%
indexCol = 1; % 行号初始化为1
temp = 0; % 行数据求和初始化
for idx = 1:size(SparesMatSort,1) 
    if SparesMatSort(idx,1) == indexCol % 行号相等判断条件
        temp = temp + SparesMatSort(idx,3);  % 行数据求和
    else
        LLR(indexCol) = LLR(indexCol) + temp;  %该行数据求和完毕后与LLR相加
        indexCol = indexCol + 1; % 行号加1
        temp = SparesMatSort(idx,3); % 改行重新进行求和
    end
end
LLR(indexCol) = LLR(indexCol) + temp;  % 各行与LLR求和完毕

end