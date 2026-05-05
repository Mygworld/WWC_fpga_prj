function [index_of,alpha_to]= generate_gf(GF_mm)
%% 本函数用于生成有限域GF(2^mm),BCH译码过程中的所有计算都是在有限域中进行的，常帧在GF（2^16)中运算，短帧在GF(2^14)中运算
%通过本函数可以计算出有限域的所有元素a^i的二进制数，将这些二进制数的十进制表示存在alpha_to中，
%也可以求得所有有限域元素的指数，存在index_of中。alpha_to和index_of都是一个长度为2^mm的一维数组。
%两个数组存在如下关系：index_of(alpha_to(i)) = i-1 ;
%
% 输出参数：
%     alpha_to -- 有限域元素
%     index_of -- 有限域元素的指数
% 输入参数：
%     GF_mm -- 有限域的维度/* Dimension of Galoise Field */
% 变量声明：
%     p:生成有限域的本原多项式
%     mask:寄存器
%%%%-----------------------------------------------------------------------------------------------------------------------------
% /* Generate GF(2**mm) from the primitive polynomial p(X) in p[0]..p[mm] */（由本原多项式p(x) in p(0) ~p(16)生成有限域GF（2^16））
% The lookup table looks like:  
% index -> polynomial form :  alpha_to[ ] contains j = alpha**i;  //（j=alpha^i )
% polynomial form -> index form:  index_of[j = alpha^i] = i  // index_of[j = alpha^i] = i 指数
% alpha_to[1] = 2 is the primitive element of GF(2**mm)  // alpha^1=2 是有限域GF（2^16)本原域元素，alpha就是希腊字母a
% mask 	// Register states

%函数主体
	
%% // Primitive polynomials  (本原多项式)
mm = GF_mm;
p(1:mm+1) = 0;   
p(1) = 1;
p(mm+1) = 1;%%末位为1，p(1）为高位
if(mm == 14)	
    p(2) = 1;p(4) =1; p(6) =1; 	% p(1:15)=100000000101011// p(x)=1+x+x^3+x^5+x^14
elseif(mm == 15)	
%     p(2) = 1;% p(1:16)=1000000000000011///p(x)=1+x+x^15  
    p(3) =1; p(4) =1; p(6) = 1; % p(1:16)=1000000000101101///p(x)=1+x^2+x^3+x^5+x^15 
elseif(mm == 16) 
    p(3) =1; p(4) =1; p(6) = 1; % p(1:17)=10000000000101101///p(x)=1+x^2+x^3+x^5+x^16
end
% %// Primitive polynomials  (本原多项式)
% p(1:mm+1) = 0;   
% p(1) = 1;
% p(mm+1) = 1;
% if (mm == 2)        p(2) = 1; %p(1:3)=111
% elseif (mm == 3)    p(2) = 1; %p(1:4)=1011
% elseif (mm == 4)	p(2) = 1; %p(1:5)=10011
% elseif (mm == 5)	p(3) = 1; %p(1:6)=100011
% elseif (mm == 6)	p(2) = 1; %p(1:7)=1000011
% elseif (mm == 7)	p(2) = 1; %p(1:8)=10000011
% elseif (mm == 8)	p(5) = 1; p(6) = 1;p(7)= 1; %p(1:9)=101110001
% elseif (mm == 9)	p(5) = 1; %p(1:10)=1000010001
% elseif (mm == 10)	p(4) = 1; %p(1:11)=10000001001
% elseif (mm == 11)	p(3) = 1; %p(1:12)=100000000101
% elseif (mm == 12)	p(4) = 1;p(5) =1; p(8) = 1;  %p(1:13)=1000010011001
% elseif (mm == 13)	p(2) = 1;p(3) = 1;p(4)=1; p(6) =1; p(8) =1; p(9) =1; p(11) = 1;	%// 25AF  //%p(1:14)=10010110101111
% %// else if (mm == 13)	p[1] = p[3] = p[4] = 1;
% elseif (mm == 14)	p(2) = 1;p(4) =1; p(6) =1; 	% p(1:15)=100000000101011
% % elseif (mm == 14)	p(3) = 1;p(5) =1; p(7) =1; p(8) =1; p(9) = 1;	%// 41D5
% %// else if (mm == 14)	p[1] = p[11] = p[12] = 1;
% elseif (mm == 15)	p(2) = 1;  % p(1:16)=1000000000000011
% elseif (mm == 16)	p(3) =1; p(4) =1; p(6) = 1;   % p(1:17)=10000000000101101
% elseif (mm == 17)	p(4) = 1;    % p(1:18)=100000000000001001
% elseif (mm == 18)	p(8) = 1;     % p(1:19)=1000000000010000001
% elseif (mm == 19)	p(2) =1; p(6) =1; p(7)= 1;   % p(1:20)=10000000000001100011
% elseif (mm == 20)	p(4) = 1;     % p(1:21)=100000000000000001001
% end
%% // Galois field implementation with shift registers  (用移位寄存器生成有限域)
%// Ref: L&C, Chapter 6.7, pp. 217  （参考资料）
mask = 1 ;
alpha_to = zeros(1,2^mm);   %初始化   alpha_to 存的是有限域元素a^i
index_of = zeros(1,2^mm);   %初始化   index_of 存的是a^i的指数i
alpha_to(mm+1) = 0 ;
for i = 1 : mm %(i = 0; i < mm; i++)
    alpha_to(i) = mask ;  
    index_of(alpha_to(i)) = i -1;   
    if (p(i) ~= 0)
        alpha_to(mm +1 ) = bitxor(alpha_to(mm+1),mask) ;  %bitxor--按位异或
    end
    mask = mask*2; 
end

mask = alpha_to(mm);

for i = mm+1 : 2^mm-1 %(i = mm + 1; i < nn; i++)
    if (alpha_to(i-1) >= mask)
        alpha_to(i) = bitxor(alpha_to(mm+1),(2*bitxor(alpha_to(i-1), mask))) ;
    else
        alpha_to(i) = alpha_to(i-1) *2 ;
    end
    index_of(alpha_to(i)) = i-1 ;
end
alpha_to(2^mm) = 0;
index_of(2^mm) = -1 ;%index_of(0) = -1 ;有限域元素0的指数表示成-1,将有限域元素0存在index_of(2^mm)中

end