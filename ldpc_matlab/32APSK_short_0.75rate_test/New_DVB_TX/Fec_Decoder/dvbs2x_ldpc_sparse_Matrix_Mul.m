function val = dvbs2x_ldpc_sparse_Matrix_Mul(H,code,M)
%% sparse_Matrix_Mul.m
%
% Note:
%      优化校验矩阵维度，并与硬判决0、1数据相乘
%     
%
% Input：
%   H —— 校验矩阵有效数据行列序号组成的矩阵
%   code ——  硬判决后的数据码字
%   M —— 校验矩阵的行数
%
% Output：
%   val —— 输出相乘后的数据
%
%
% Author: zhen wen ye
%
% Date: 2023.10.31
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Log:
% 2023.10.28 褚磊
% v1.1 添加函数输入输出接口说明，去除冗余程序步骤
% 2023.10.31 褚磊     
% v1.2 修改从第二行数据开始直接跳出循环的BUG
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
val = zeros(1,M); % 输出初始化
idx2 = 0; % 加法计数初始化
for idx_raw = 1:M % 行序号
    temp = 0;
    for idx = idx2+1:size(H,1) % 更新循环位置
        if H(idx,2) == idx_raw
            temp = temp + code(H(idx,1)); %校验矩阵与code相乘求和，由于校验矩阵有效数据为1，固省略乘法
            idx2 = idx2+1; % 加法计数
        else
            break;
        end   
    end
    val(idx_raw) = temp; % 输出当前行与code相乘结束后的值
end

end