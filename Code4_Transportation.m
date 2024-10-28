% This code first calculates the sectoral SFS for the transportation sector. It then integrates these with the sector's carbon emission satellite accounts (excluding electricity and thermal emissions) to estimate the GHG emissions attributable to the transportation subsystem within the food system.
%% Compute SFS_trans Matrix (MRIO Table with Accommodation and Catering Separated)
clc; clear; tic;
load('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_wholesale_retail&catering\MRIO_CHINA2017_32.mat');
SFS_trans = zeros(31, 992); % Flow of transportation industry, transportation service industry * 31 regions = 31, 31 regions * industry = 1302
for i = 1:size(SFS_trans,1)
    for j = 1:size(SFS_trans,2)
          SFS_trans(i,j) = MRIO_Z_32(i*32-3,j) / MRIO_X_32(i*32-3);
    end
end
PS = ['SFS_trans is a 31*992 matrix representing the input coefficients from the transportation service industry of 31 regions to 31 regions and 32 industries (a total of 31*32 = 992 columns)'];
save("SFS_trans_by_MRIO2017", "SFS_trans", "PS");
toc

%% Extract Energy Consumption Data for Transportation Service Industry (GHG emissions calculated based on original energy data)
clc; clear; tic;
% Extract original energy consumption data for 2019 from various provinces, units are 10,000 tons, 100 million cubic meters, 10 million megajoules, 100 million kilowatt-hours
original_energy_consumption = readmatrix('胡廷钰_运输数据（2023.10.12提供）.xlsx', 'sheet', '2019', 'range', 'B2:AG32');
% Extract data for coal (1), gasoline (2), kerosene (3), diesel (4), fuel oil (5), liquefied petroleum gas (6), natural gas (7), heat (8), and electricity (9), with energy type numbers 1-9 for easier identification
trans_energy_consumption = original_energy_consumption(:, [1, 15, 16, 17, 18, 25, 28, 30, 31]);
trans_energy_consumption(:,7) = 10 * trans_energy_consumption(:,7); % Convert natural gas unit to 10 million cubic meters (10^7)
% Convert energy consumption to standard coal for subsequent emissions calculation
trans_energy_consumption_tce = zeros(31, 9);
original_tce_conversion = readmatrix('胡廷钰_运输数据（2023.10.12提供）.xlsx', 'sheet', '2019', 'range', 'C34:AG34');
tce_conversion = original_tce_conversion(:, [1, 14, 15, 16, 17, 24, 27, 29, 30]);
trans_energy_consumption_tce = trans_energy_consumption .* tce_conversion;

%% Calculate Production & Consumption Emissions (Note: Total emissions from the transportation service industry in each province)
load('EF_energy_production&consumption.mat'); % Read emission factors for energy production and consumption
trans_energy_production_CO2 = zeros(31, 9); trans_energy_production_CH4 = zeros(31, 9);
trans_energy_consumption_CO2 = zeros(31, 9); trans_energy_consumption_CH4 = zeros(31, 9);
% Calculate CO2 and CH4 emissions from production, units in Mton
trans_energy_production_CO2(:,1:7) = trans_energy_consumption(:,1:7) * 10000 * 1000 ...
    .* cell2mat(EF_energy_production_fossil(2,2:8)) / 1000 / 1000000; % Energy 1-7 Fossil
trans_energy_production_CO2(:,8) = trans_energy_consumption(:,8) * 10000 ...
    .* EF_energy_production_heat / 1000000; % Energy 8 Heat
trans_energy_production_CO2(:,9) = trans_energy_consumption(:,9) * 100000000 * 1000 / 1000000 ...
    .* cell2mat(EF_energy_production_elec_2019(2:32,2)) / 1000000; % Energy 9 Electricity

trans_energy_production_CH4(:,1:7) = trans_energy_consumption(:,1:7) * 10000 * 1000 ...
    .* cell2mat(EF_energy_production_fossil(6,2:8)) / 1000 / 1000000; % Energy 1-7 Fossil

% Calculate CO2 and CH4 emissions from consumption, units in Mton
trans_energy_consumption_CO2(:,1:7) = trans_energy_consumption(:,1:7) * 10000 * 1000 ...
    .* cell2mat(EF_energy_consumption_fossil(2,2:8)) / 1000 / 1000 / 1000000; % Energy 1-7 Fossil
trans_energy_consumption_CH4(:,1:7) = trans_energy_consumption(:,1:7) * 10000 * 1000 ...
    .* cell2mat(EF_energy_consumption_fossil(6,2:8)) / 1000 / 1000 / 1000000; % Energy 1-7 Fossil

PS = ["Coal (1), gasoline (2), kerosene (3), diesel (4), fuel oil (5), liquefied petroleum gas (6), natural gas (7), heat (8), and electricity (9)"; "Units in Mton"];
% Combine emissions from energy types 1-7, excluding heat and electricity
trans_energy_production_CO2 = sum(trans_energy_production_CO2(:,[1:7]),2);
trans_energy_consumption_CO2 = sum(trans_energy_consumption_CO2(:,[1:7]),2);
trans_energy_production_CH4 = sum(trans_energy_production_CH4(:,[1:7]),2);
trans_energy_consumption_CH4 = sum(trans_energy_consumption_CH4(:,[1:7]),2);

save("transportation_all.mat", "trans_energy_production_CO2", "trans_energy_production_CH4", ...
    "trans_energy_consumption_CO2", "trans_energy_consumption_CH4", "PS");
toc

%% Calculate transportation_GHG (Using self-calculated energy emissions data and SFS_trans from MRIO)
clc; clear; tic;
load("transportation_all.mat"); load('SFS_trans_by_MRIO2017.mat');
transportation_all_CO2 = trans_energy_production_CO2 + trans_energy_consumption_CO2;
transportation_all_CH4 = trans_energy_production_CH4 + trans_energy_consumption_CH4;
% Extract SFS_trans for ‘Agriculture, Forestry, Animal Husbandry, and Fishing Products and Services’, ‘Food and Tobacco’, and ‘Catering’
SFS_trans_agri = zeros(31, 31); SFS_trans_food_cigg = zeros(31, 31); SFS_trans_catering = zeros(31, 31);
for i = 1:size(SFS_trans,1)
    SFS_trans_agri(:,i) = SFS_trans(:,(i-1)*32+1);
    SFS_trans_food_cigg(:,i) = SFS_trans(:,(i-1)*32+6);
    SFS_trans_catering(:,i) = SFS_trans(:,(i-1)*32+31);
end
transportation_agri_CO2 = SFS_trans_agri .* transportation_all_CO2;
transportation_food_cigg_CO2 = SFS_trans_food_cigg .* transportation_all_CO2;
transportation_catering_CO2 = SFS_trans_catering .* transportation_all_CO2;
transportation_agri_CH4 = SFS_trans_agri .* transportation_all_CH4;
transportation_food_cigg_CH4 = SFS_trans_food_cigg .* transportation_all_CH4;
transportation_catering_CH4 = SFS_trans_catering .* transportation_all_CH4;

toc
