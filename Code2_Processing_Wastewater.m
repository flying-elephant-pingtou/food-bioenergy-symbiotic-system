% This code calculates the emissions of CH4, N2O, and CO2 from wastewater treatment & discharge caused by food processing, covering 31 provincial-level administrative regions, 22 food categories, and 7 types of animal slaughter.
%% Read food production data
clear;clc;tic;
load('food_product.mat'); % Read food production data, in units of 10,000 tons, 10 million liters, 100 million units.
product_category = fieldnames(final_product_a);
fp = cell2mat(struct2cell(final_product_a)'); % fp stands for final product
amount_animal = readmatrix('EF_wastewater.xlsx','sheet','animal_slaughter','range','B37:H67'); % Animal numbers, unit: 10,000 heads
name_animal_slaughter = readcell('EF_wastewater.xlsx','sheet','animal_slaughter','range','B36:H36'); % Animal slaughter names
fp = [fp,amount_animal];
product_category = cat(1,product_category,name_animal_slaughter');
%% Calculation - GHG emissions from wastewater treatment process for each province and each food category
% --------------------------------------Read activity data-------------------------------------------------
CE_COD_generate = readmatrix('EF_wastewater.xlsx','sheet','COD_generate','Range','B2:AD10');   % Read COD generation coefficients for each food processing type, unit: g/ton_product/kiloliter
CE_TN_generate = readmatrix('EF_wastewater.xlsx','sheet','TN_generate','Range','B2:AD10');
COD_generate = zeros(31,29);  % Define COD generation matrix (preallocate space), 31 provincial regions, 22 food categories + 7 types of animal slaughter.
TN_generate = zeros(31,29);  % Define TN generation matrix (preallocate space), 31 provincial regions, 22 food categories + 7 types of animal slaughter.
%---------------------------------------Read relevant coefficients-------------------------------------------------
CE_treatment_GHG = readcell('EF_wastewater.xlsx','sheet','treatment_GHG','Range','A1:G9'); % Read GHG generation coefficients and electricity consumption coefficients for the wastewater treatment process
VVS_sludge = readmatrix('EF_wastewater.xlsx','sheet','treatment_GHG','Range','G14:G14'); % Organic content in sludge (kg-VSS/kg-dry sludge)
COD_VVS = readmatrix('EF_wastewater.xlsx','sheet','treatment_GHG','Range','G16:G16'); % COD content in sludge (kgCOD/kg VSS)
CE_COD_remove_rate = readcell('EF_wastewater.xlsx','sheet','COD_remove_rate'); 
CE_TN_remove_rate = readcell('EF_wastewater.xlsx','sheet','TN_remove_rate'); 
k = readcell('EF_wastewater.xlsx','sheet','k'); % Read actual operating rate of wastewater treatment equipment
CE_ww_generate = readmatrix('EF_wastewater.xlsx','sheet','wastewater_generate','Range','B11:AD11'); % Unit: ton/ton_product
CE_wwd_generate = readcell('EF_wastewater.xlsx','sheet','discharge_GHG','Range','A1:D2');
load('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_transportation\EF_energy_production&consumption.mat',...
    'EF_energy_production_elec_2019'); % Grid emission parameters
%----------------------------------------------------------------------------------------------------
processing_wwt_CH4 = zeros(31,29); % Define CH4 generation matrix from wastewater treatment (preallocate space), wwt = wastewater treatment
processing_wwt_CO2 = zeros(31,29); % Define CO2 generation matrix from wastewater treatment (preallocate space)
processing_wwt_N2O = zeros(31,29); % Define N2O generation matrix from wastewater treatment (preallocate space)
ww_treatment_elec_consumption = zeros(31,29); % Define electricity consumption from wastewater treatment (preallocate space)

COD_removed = zeros(31,29); % Define COD removal matrix for treatment_GHG calculation
COD_remainder = zeros(31,29); % Define COD remainder matrix for subsequent discharge_GHG calculation
sludge_generate = zeros(31,29); % Define sludge generation matrix
sludge_COD = zeros(31,29); % Define COD matrix in sludge

TN_removed = zeros(31,29); % Define COD removal matrix for treatment_GHG calculation
TN_remainder = zeros(31,29); % Define COD remainder matrix for subsequent discharge_GHG calculation
%-------------------------------------------------------------------------------------------------------
MC_simulations = 1000; % Perform 1000 Monte Carlo simulations

MC_wwt_CH4 = cell(MC_simulations,1); % Preallocate space for wwt_CH4
MC_wwt_CO2 = cell(MC_simulations,1); % Preallocate space for wwt_CO2
MC_wwt_N2O = cell(MC_simulations,1); % Preallocate space for wwt_N2O

MC_COD_generate = cell(MC_simulations,1);  % COD generation
MC_COD_remainder = cell(MC_simulations,1);  % COD remainder after removal
MC_TN_remainder = cell(MC_simulations,1);  % TN remainder after removal
MC_sludge_generate = cell(MC_simulations,1);  % Sludge generation
MC_sludge_COD = cell(MC_simulations,1);  % Sludge COD
MC_ww_treatment_elec_consumption = cell(MC_simulations,1);  % Preallocate space

for u = 1:MC_simulations    % Perform 1000 simulations for uncertainty analysis
    for i = 1:31          % i represents regions
        for j = 1:29      % j represents food categories
            %-------------Pick out the COD generation coefficient vector corresponding to food category j--------------
            m = 1;
            while ~isnan(CE_COD_generate(m,j)) == 1
                N(m,1) = CE_COD_generate(m,j);   % Temporarily store COD generation coefficient of food category j in vector N.
                if m == 9
                    break
                end
                m = m+1;
            end
            %-------------Pick out the TN generation coefficient vector corresponding to food category j--------------
             p = 1;
            while ~isnan(CE_TN_generate(p,j)) == 1
                M(p,1) = CE_TN_generate(p,j);   % Temporarily store TN generation coefficient of food category j in vector M.
                if p == 9
                    break
                end
                p = p+1;
            end
            %--------------------------------------------------------------
            COD_generate(i,j) = fp(i,j)*10000*randsrc(1,1,N')/1000000/1000; % Unit:kton
            TN_generate(i,j) = fp(i,j)*10000*randsrc(1,1,M')/1000000/1000; % Unit:kton
            clear N; clear M
        end
    end
clear m; clear p;
% Checked, final result is normal
% ---------------------------------------------------Calculate GHG generation-------------------------------------
for i = 1:31
    for j = 1:29
        m = 2;
        while ~ismissing(CE_COD_remove_rate{m,2*j-1})
            N(m-1,1) = CE_COD_remove_rate{m,2*j-1};   % Temporarily store COD removal rate of food category j in vector N.
            M(m-1,1) = CE_TN_remove_rate{m,2*j-1};    % Temporarily store TN removal rate of food category j in vector M.
            SN(m-1,1) = CE_COD_remove_rate{m,2*j};    % Temporarily store corresponding treatment technology type of food category j in vector SN.
            if m == 21
                break
            end
            m = m+1;
        end
        r = randi(length(N),1);
        q = randi(length(M),1);
        COD_removed(i,j) = COD_generate(i,j)*N(r)*k{4,j}; % Unit:kton, assume 100% wastewater treatment equipment operating rate (k)
        COD_remainder(i,j) = COD_generate(i,j) - COD_removed(i,j);   % Unit:kton
        TN_remainder(i,j) = TN_generate(i,j) - TN_generate(i,j)*M(q)*k{4,j};   % Unit:kton
        if SN(r) == 0 % Here and later, when calculating GHG emissions, uncertainty (e.g., rand) is considered, the uncertainty range is derived from literature W1
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{2,7};  % Unit:kton sludge
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{2,3} * (0.57 + rand); % Unit:kton;
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{2,5} * (0.3 + rand); % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{2,4} * (0.17+(2.58-0.17)*rand); % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{2,6}/1000;%Mwh
        elseif SN(r) == 1           
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{3,7};  % Unit:kton sludge
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{3,3}; % Unit:kton
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{3,5} * (0.96+(0-0.96)*rand); % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{3,4} * (0.17+(2.58-0.17)*rand); % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{3,6}/1000;%Mwh
        elseif SN(r) == 2     
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{4,7};  % Unit:kton sludge
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{4,3} * (0.7+(1.39-0.7)*rand); % Unit:kton
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{4,5} * (0.7+(1.3-0.7)*rand); % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{4,4}; % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{4,6}/1000;%Mwh
        elseif SN(r) == 3
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{5,7};  % Unit:kton sludge
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) =(COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{5,3}; % Unit:kton
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{5,5} * (1+(2.2-1)*rand); % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{5,4} * (0.01+(2.19-0.01)*rand); % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{5,6}/1000;%Mwh        
        elseif SN(r) == 4
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{6,7};  % Unit:kton sludge   
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{6,3} * (0.32+(4.51-0.32)*rand); % Unit:kton
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{6,5} * (0.14+(1.86-0.14)*rand); % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{6,4} * (0.87+(1.15-0.87)*rand); % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{6,6}/1000;%Mwh
        elseif SN(r) == 5
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{7,7};  % Unit:kton sludge 
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{7,3} * (0.14+(1.28-0.14)*rand); % Unit:kton
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{7,5} * (0.18+(1.82-0.18)*rand); % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{7,4} * (0.6+(1.5-0.6)*rand); % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{7,6}/1000;%Mwh
        elseif SN(r) == 6
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{8,7};  % Unit:kton sludge   
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{8,3} * (0.07+(4.24-0.07)*rand); % Unit:kton
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{8,5} * (0.43+(1.54-0.43)*rand); % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{8,4} * (0.03+(5.56-0.03)*rand); % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{8,6}/1000;%Mwh
        elseif SN(r) == 7
            sludge_generate(i,j) = COD_removed(i,j) * CE_treatment_GHG{9,7};  % Unit:kton sludge    
            sludge_COD(i,j) = sludge_generate(i,j)* VVS_sludge * COD_VVS; % Unit:kton COD
            processing_wwt_CH4(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{9,3}; % Unit:kton
            processing_wwt_CO2(i,j) = (COD_removed(i,j)-sludge_COD(i,j)) * CE_treatment_GHG{9,5}; % Unit:kton
            processing_wwt_N2O(i,j) = TN_generate(i,j) * CE_treatment_GHG{9,4}; % Unit:kton
            ww_treatment_elec_consumption(i,j) = fp(i,j) *10000 * CE_ww_generate(1,j) * CE_treatment_GHG{9,6}/1000;%Mwh
        end
        clear r; clear q; clear N; clear M;clear SN;              
    end
end
MC_COD_generate{u} = COD_generate;
MC_COD_remainder{u} = COD_remainder;
MC_TN_remainder{u} = TN_remainder;
MC_wwt_CH4{u} = processing_wwt_CH4;
MC_wwt_CO2{u} = processing_wwt_CO2;
MC_wwt_N2O{u} = processing_wwt_N2O;
MC_ww_treatment_elec_consumption{u} = ww_treatment_elec_consumption;
MC_sludge_generate{u} = sludge_generate;
MC_sludge_COD{u} = sludge_COD;
end

%% Calculation - GHG emissions from wastewater discharge process for each province and each food category
MC_COD_generate = cat(3, MC_COD_generate{:});% The most complete result matrix, a 31*29*1000 three-dimensional matrix, containing 31 regions, 22 food categories, and 1000 repeated uncertainty results
MC_COD_generate_mean = mean(MC_COD_generate, 3);
MC_COD_remainder = cat(3, MC_COD_remainder{:});
MC_COD_remainder_mean = mean(MC_COD_remainder, 3);
MC_TN_remainder = cat(3, MC_TN_remainder{:});
MC_TN_remainder_mean = mean(MC_TN_remainder, 3);
MC_sludge_generate = cat(3, MC_sludge_generate{:});
MC_sludge_generate_mean = mean(MC_sludge_generate,3);
MC_sludge_COD = cat(3, MC_sludge_COD{:});
MC_sludge_COD_mean = mean(MC_sludge_COD,3);
%------------------------------------------------------------------------------------------------------------------
concentration_COD_remainder = zeros(31,29);
concentration_TN_remainder = zeros(31,29);
ww = zeros(31,29); % unit: L
for i = 1:31 % Calculate COD concentration in discharge water, unit: mg/L
    for j = 1:29
        ww(i,j) = (fp(i,j)*10000 * CE_ww_generate(1,j)*1000);
        concentration_COD_remainder(i,j) = MC_COD_remainder_mean(i,j)*1000*1000*1000*1000 / (fp(i,j)*10000 * CE_ww_generate(1,j)*1000);
        concentration_TN_remainder(i,j) = MC_TN_remainder_mean(i,j)*1000*1000*1000*1000 / (fp(i,j)*10000 * CE_ww_generate(1,j)*1000);
    end
end
A_removed = sum(COD_removed,'all');
A1_remainder = sum(COD_remainder,'all');
%-------------------------------------------------------------------------------------------------------------
processing_wwd_CH4 = zeros(31,29); % Define CH4 generation matrix from wastewater discharge (preallocate space), 31 provincial regions, 22 food categories, wwd = wastewater discharge
processing_wwd_CO2 = zeros(31,29); % Define CO2 generation matrix from wastewater discharge (preallocate space)
processing_wwd_N2O = zeros(31,29); % Define N2O generation matrix from wastewater discharge (preallocate space)
MC_wwd_CH4 = cell(MC_simulations,1); % Preallocate space for wwd_CH4
MC_wwd_CO2 = cell(MC_simulations,1); % Preallocate space for wwd_CO2
MC_wwd_N2O = cell(MC_simulations,1); % Preallocate space for wwd_N2O
for u = 1:MC_simulations
    for i = 1:31
        for j = 1:29
            processing_wwd_CH4(i,j) = MC_COD_remainder(i,j,u) * CE_wwd_generate{2,2} * (0.35+(1.52-0.35)*rand);  % Unit:kton
            processing_wwd_CO2(i,j) = MC_COD_remainder(i,j,u) * CE_wwd_generate{2,4} * (0.88+(1.2-0.88)*rand);  % Unit:kton
            processing_wwd_N2O(i,j) = MC_TN_remainder(i,j,u) * CE_wwd_generate{2,3} * (0.1+(14.94-0.1)*rand);  % Unit:kton
        end
    end
    MC_wwd_CH4{u} = processing_wwd_CH4;
    MC_wwd_CO2{u} = processing_wwd_CO2;
    MC_wwd_N2O{u} = processing_wwd_N2O;
end

%% Data processing & saving
MC_ww_treatment_elec_consumption = cat(3, MC_ww_treatment_elec_consumption{:});
MC_ww_treatment_elec_consumption_mean = mean(MC_ww_treatment_elec_consumption,3);
ww_treatment_elec_CO2 = MC_ww_treatment_elec_consumption_mean .* cell2mat(EF_energy_production_elec_2019(2:32,2))/1000; % Electricity emissions from wastewater treatment

save("processing_MC_ww_GHG.mat","MC_wwt_CH4","MC_wwt_CO2","MC_wwt_N2O","MC_wwd_CH4","MC_wwd_CO2","MC_wwd_N2O","MC_ww_treatment_elec_consumption","product_category","product_province");
MC_wwt_CH4 = cat(3, MC_wwt_CH4{:});% The most complete result matrix, a 31*29*1000 three-dimensional matrix, containing 31 regions, 29 food categories, and 1000 repeated uncertainty results
MC_wwt_CO2 = cat(3, MC_wwt_CO2{:});
MC_wwt_N2O = cat(3, MC_wwt_N2O{:});
MC_wwd_CH4 = cat(3, MC_wwd_CH4{:});
MC_wwd_CO2 = cat(3, MC_wwd_CO2{:});
MC_wwd_N2O = cat(3, MC_wwd_N2O{:});

MC_wwt_CH4_mean = mean(MC_wwt_CH4, 3); 
MC_wwt_CO2_mean = mean(MC_wwt_CO2, 3);
MC_wwt_N2O_mean = mean(MC_wwt_N2O, 3);
MC_wwd_CH4_mean = mean(MC_wwd_CH4, 3);
MC_wwd_CO2_mean = mean(MC_wwd_CO2, 3);
MC_wwd_N2O_mean = mean(MC_wwd_N2O, 3);

save("processing_ww_GHG.mat","MC_wwt_CH4_mean","MC_wwt_CO2_mean","MC_wwt_N2O_mean","MC_wwd_CH4_mean","MC_wwd_CO2_mean","MC_wwd_N2O_mean","ww_treatment_elec_CO2","product_category","product_province");
toc
