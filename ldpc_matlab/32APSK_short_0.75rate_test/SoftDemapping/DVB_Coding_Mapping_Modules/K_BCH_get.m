function dataout = K_BCH_get(n_ldpc,R_num)
switch n_ldpc
    case 32400
        switch R_num
            case 1
               dataout = 5660;
            case 2
               dataout = 7740;
            case 3
               dataout= 10620;
            otherwise
                error('dvb_s2x_bch UNKNOWN CODING RATE');
        end
    case 16200
         switch R_num
            case 1
                dataout = 3072;
            case 2
                dataout = 5232;            
            case 3
                dataout = 6312;      
            case 4
                dataout = 7032;       
            case 5  %%dvb-t2(3/5)
                dataout = 9552;
            case 6
                dataout = 10632;
            case 7
                dataout = 11712;            
            case 8
                dataout = 12432;              
            case 9
               dataout = 13152;              
            case 10
               dataout = 14232;             
                %%%% DVB-S2X %%%%
            case 11
                dataout = 3792;      
            case 12
                dataout = 4152;           
            case 13
                dataout = 4872;         
            case 14
                dataout = 7392;          
            case 15
                dataout = 8472;             
            case 16
                dataout = 9192;           
            case 17
                dataout = 11352;       
                %%% VL-SNR %%%%
            case 18 % 1/5 SF2
                dataout = 2512;
            otherwise
                error('dvb_s2_bch UNKNOWN CODING RATE');
         end
      case 64800
           switch R_num
                %%%% DVB-S2 %%%%
            case 1
                dataout = 16008;               
            case 2
                dataout = 21408;                
            case 3
                dataout = 25728;                
            case 4
                dataout = 32208;                
            case 5
                dataout = 38688;              
            case 6         
                dataout = 43040;               
            case 7
                dataout = 48408;               
            case 8
                dataout = 51648;                
            case 9              
                dataout = 53840;             
            case 10                
                dataout = 57472;              
            case 11              
                dataout = 58192;         
                %%%% DVB-S2X %%%%
            case 12
                dataout = 14208;              
            case 13
                dataout = 18528;             
            case 14
                dataout = 28968;             
            case 15
                dataout= 35448;             
            case {16 , 25}
                dataout= 37248;              
            case 17
                dataout= 40128;              
            case 18
                dataout = 41208;            
            case 19
                dataout = 44808;                
            case 20
                dataout = 46608;              
            case { 21 , 31}
                dataout = 50208;               
            case 22  %% 和1/2码率的码字是一样的
                dataout = 32208;              
            case 23
                dataout= 34368;           
            case 24
                dataout = 35808;            
            case 26
                dataout = 41568;            
            case 27
                dataout = 44448;    
            case 28
                dataout = 45888;        
            case { 29 , 35 }
                dataout = 47328;              
            case 30
                dataout = 48408;           
            case 32
                dataout = 55248;      
            case 33 %% 和3/5码率的码字是一样的
                dataout = 38688;            
            case 34
                dataout = 43008;           
            otherwise
                error('dvb_s2_bch UNKNOWN CODING RATE');
           end
end


    



  