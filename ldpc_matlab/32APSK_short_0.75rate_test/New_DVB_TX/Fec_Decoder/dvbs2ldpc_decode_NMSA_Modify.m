function decode = dvbs2ldpc_decode_NMSA_Modify(M,N,H,LLR,H1_RW,q,iterNum,work)
%% dvbs2ldpc_decode_NMSA.m使用说明
% 程序功能说明：使用归一化最小和算法实现译码（适用于所有码率）
% 程序接口说明：
%           输入  M、N ：校验矩阵维度
%                 H: 校验矩阵转置的行列序号矩阵
%                 LLR：软判决得到的对数似然比
%                 H1_RW:校验矩阵H=[H1 H2]中H1的行重
%                 q：由码率决定的常量（q=（N*(1-R)/360）（N为帧长，R为码率）
%                 iterNum：译码迭代次数
%           输出  decode：译码后的输出码字
% 上层程序：dvbs2ldpc_decode.m
% 子程序：无
% 创建者：
% 创建日期：
% 修改者 : zhen wen ye
% 最后修改日期：2023.10.28
% 修改说明: 优化LDPC校验矩阵，替换linspace函数、
% 审核者：
% 版权所有：西安电子科技大学ISN国家重点实验室宽带无线传输研究中心
%% NMSA
if work ~=1
    decode = LLR;
else
    decode = zeros(iterNum,N-M); %译码输出初始化
    ite_num=iterNum ;
    code=zeros(1,N);
    if length(H1_RW)==1 %H1为行重固定的矩阵
        H1_RW_R = H1_RW*ones(1,q);
    else %H1行重不固定，即短帧标识码率为1/4，1/2,3/4,4/5,5/6时
        H1_RW_R = H1_RW;
    end
    HRW2=H1_RW_R+2;
    row2 = H(:,1); % 校验矩阵有效数据行序号
    column2 = H(:,2); % 校验矩阵有效数据列序号
    check2bit=LLR(row2);
    aff=0.875;
    pos_revise=zeros(1,M);
    k=-1;
    for idx1=0:359
        for idx2=1:q
            pos_revise(idx1*q+idx2)=k;%针对稀疏值，对重组的矩阵所寻找的最小位置进行修正
            k=k+HRW2(idx2);
        end
    end
    checkmatrix=1000*ones(max(HRW2),M);%生成一个（最大行重*校验位个数）的全1000矩阵

    for idx=1:ite_num
        %% 矩阵重组
        checkmatrix_reshape=reshape([1000 check2bit],sum(HRW2),360);%因为行重是不固定的，但是有周期性，根据周期性转换为矩阵
        for idx3=1:360
            i=1;
            % j=0;
            for idx4=1:q
                j=i+HRW2(idx4);
                checkmatrix(1:HRW2(idx4),idx4+q*(idx3-1))=checkmatrix_reshape(i:(j-1),idx3);%将数值按照行重值分配给每列，有的行重较小则该列空余位置仍为1000，不影响后面的sgn和min操作
                i=j;
            end
        end

        %% sgn操作
        checkmatrix2=sign(checkmatrix);
        checkmatrix2(checkmatrix2==0)=1;
        matrixprod=prod(checkmatrix2);
        checkmatrix3=matrixprod(column2);
        check2bit2=sign(check2bit');
        check2bit2(check2bit2==0)=1;
        sgn_valu=checkmatrix3.*check2bit2';
        %%min操作
        matrixabs=abs(checkmatrix) ;
        [minvalue,minpos]=sort(matrixabs);
        matrixabs=minvalue(1,column2);
        subminpos=minpos(1,:)+pos_revise;
        matrixabs(subminpos)=minvalue(2,:);

        %% 校验节点消息更新
        bit2check=matrixabs.*sgn_valu*aff;
        bit2check=floor(bit2check);
        bit2check(bit2check < 0) = bit2check(bit2check < 0) + 1;

        %% 针对更新值重构稀疏矩阵、计算硬判决信息
         
        data_sum = dvbs2x_ldpc_sparse_Matrix_Sum(row2,column2,bit2check,LLR);
        
        %% 硬判决
        code(data_sum>=0)=0;
        code(data_sum<0)=1;

        %% 变量节点消息更新
        check2bit=data_sum(row2)-bit2check;
        decode(idx,:)=code(1:N-M);

        %% 迭代中止判断
        if sum(mod(dvbs2x_ldpc_sparse_Matrix_Mul(H,code,M),2))==0
           decode(all(decode==0,2),:)=[]; %去除全0行
           break;
        end
    end
    disp(['LDPC译码迭代次数：' num2str(size(decode,1))]);
end

end

