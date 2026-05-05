function DecMessage = dvbs2x_bch_decoder(GF_mm,correctNum,parity_R, message_K,codeword_N, inDecData,work)

%% // generate the Galois Field GF(2**mm)//生成有限域GF(2^mm) %%
if work ~=1
    DecMessage = inDecData;
else
    [index_of,alpha_to] = generate_gf(GF_mm) ;

%% 进行译码 %%
    [~,~,~,DecData] = bch_decoder(codeword_N,correctNum,inDecData,alpha_to,index_of,GF_mm) ;
        
%% 由解码数据得到译出的信息位数据 %%
    DecMessage = zeros(1,message_K);%%%初始化
    for i = 1:message_K
        DecMessage(i) = DecData(i + parity_R);
    end
    DecMessage = fliplr(DecMessage); %%%%倒序排列后得到译出的正确的信息位数据

end

end

