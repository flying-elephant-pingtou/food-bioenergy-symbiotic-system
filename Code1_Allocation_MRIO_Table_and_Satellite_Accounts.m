%In this code, we carry out two key tasks: (1) we disaggregate the 'Accommodation and Catering' sector in the selected multi-regional input-output (MRIO) table into two independent sectors—'Accommodation' and 'Catering'—using the 2017 input-output table for China, which comprises 149 sectors; (2) utilizing the disaggregated input-output table, we refine the energy satellite accounts to isolate the energy consumption data for the ‘Wholesale and Retail’ and ‘Catering’ sectors, ensuring greater specificity in the analysis.
%% Merge the 2017 China 149-sector table into 43 sectors (splitting accommodation and catering from 42 sectors)
clc;clear;tic
IO_path = 'D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\数据&参数\投入产出表\中国\CHINA_IO_2017.xlsx';
% Sector names
SECTOR_149 = readcell(IO_path,'sheet','2017年全国投入产出表','range','B7:B155');
SECTOR_43 = readcell(IO_path,'sheet','合并部门','range','D2:D44');
% Intermediate input matrix (149 sectors)
Z_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','D7:EV155');
% Final use and imports (149 sectors)
FU101_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','EX7:EX155');% Rural household consumption expenditure (code: FU101)
FU102_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','EY7:EY155');% Urban household consumption expenditure (code: FU102)
FU103_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','FA7:FA155');% Government consumption expenditure (code: FU103)
FU201_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','FC7:FC155');% Total fixed capital formation (code: FU201)
FU202_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','FD7:FD155');% Inventory changes (code: FU202)
EX_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','FF7:FF155');% Exports (code: EX)
IM_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','FH7:FH155');% Imports (code: IM)
% Total output (149 sectors)
X_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','FI7:FI155');
% Value added (149 sectors)
VA_149 = readmatrix(IO_path,'sheet','2017年全国投入产出表','range','D157:EV160');

% Allocate space for the target sector IO table
Z_43_149 = zeros(43,149); Z_43 = zeros(43,43);
FU101_43 = zeros(43,1); FU102_43 = zeros(43,1); FU103_43 = zeros(43,1); FU201_43 = zeros(43,1); FU202_43 = zeros(43,1); 
EX_43 = zeros(43,1); IM_43 = zeros(43,1);
X_43 = zeros(43,1);
VA_43 = zeros(4,43);

% Sector ID
ID_IO = readmatrix(IO_path,'sheet','合并部门','range','B2:B150');
% Use the unique function to find unique values in the array and their indices
[unique_ID, ~, indices] = unique(ID_IO);
% Merge rows
for i = 1:length(unique_ID)
    locations = find(indices == i);
    Z_43_149(i,:) = sum (Z_149(locations',:),1);
    FU101_43(i,:) = sum (FU101_149(locations',:),1); FU102_43(i,:) = sum (FU102_149(locations',:),1);
    FU103_43(i,:) = sum (FU103_149(locations',:),1); FU201_43(i,:) = sum (FU201_149(locations',:),1);
    FU202_43(i,:) = sum (FU202_149(locations',:),1); EX_43(i,:) = sum (EX_149(locations',:),1);
    IM_43(i,:) = sum (IM_149(locations',:),1);  
    X_43(i,:) = sum (X_149(locations',:),1);
    clear locations;
end
% Merge columns
for i = 1:length(unique_ID)
    locations = find(indices == i);
    Z_43(:,i) = sum (Z_43_149(:,locations'),2);
    VA_43(:,i) = sum (VA_149(:,locations'),2);
end
save('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_wholesale_retail&catering\IO_CHINA2017_43.mat',...
    'Z_43','FU101_43','FU102_43','FU103_43','FU201_43','FU202_43','EX_43','IM_43','X_43','VA_43','SECTOR_43');
toc
%% Split 'Accommodation and Catering' in the 2017 MRIO table into 'Accommodation' and 'Catering' industries for a region with 43 sectors (based on the 2017 China table)
clc;clear;tic
load('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_wholesale_retail&catering\IO_CHINA2017_43.mat');
% Calculate the allocation ratios for accommodation and catering
% Output allocation ratio for accommodation and catering (rows)
ratio_output([1,2],[1:29,31:42]) = Z_43([30,31],[1:29,32:43]) ./ sum(Z_43([30,31],[1:29,32:43]),1);
ratio_output([1,2],30) = sum(Z_43([30,31],[30,31]),2) ./ sum(sum(Z_43([30,31],[30,31]),2),1);
% Input allocation ratio for accommodation and catering (columns)
ratio_input([1:29,31:42],[1,2]) = Z_43([1:29,32:43],[30,31]) ./ sum(Z_43([1:29,32:43],[30,31]),2);
ratio_input(30,[1,2]) = sum(Z_43([30,31],[30,31]),1) ./ sum(sum(Z_43([30,31],[30,31]),1),2);
ratio_input(isnan(ratio_input)) = 0.5; % Replace missing allocation ratios (indicating zero value for accommodation and catering in that position) with 0.5. It would be better to replace with the total input ratio for accommodation and catering, but this simplification is used due to its negligible impact.
% Total output allocation ratio 
ratio_X([1,2],1) = X_43([30,31]) ./ sum(X_43([30,31]),1);
% Allocation ratios for final use, exports, imports, and value added
ratio_101([1,2],1) = FU101_43([30,31],1) ./ sum(FU101_43([30,31],1),1); % Rural household consumption allocation ratio
ratio_102([1,2],1) = FU102_43([30,31],1) ./ sum(FU102_43([30,31],1),1); % Urban household consumption allocation ratio
ratio_103 = ratio_X; % Use output ratio to replace government consumption allocation ratio
ratio_201 = ratio_X; % Use output ratio to replace fixed capital formation allocation ratio
ratio_202 = ratio_X; % Use output ratio to replace inventory increase allocation ratio
ratio_EX([1,2],1) = EX_43([30,31],1) ./ sum(EX_43([30,31],1),1); % Export allocation ratio
ratio_IM([1,2],1) = IM_43([30,31],1) ./ sum(IM_43([30,31],1),1); % Import allocation ratio
ratio_VA([1:4],[1,2]) = VA_43([1:4],[30,31]) ./ sum(VA_43([1:4],[30,31]),2); % Value added allocation ratio

% Extract MRIO data
IO_path = 'D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\数据&参数\投入产出表\China_inter_provincial_IO.xlsx';
% Intermediate input matrix
MRIO_Z_42 = readmatrix(IO_path,'sheet','MRIO2017','range','D8:AXE1309');
% Final use (columns: from rural household consumption to exports, rows: from Beijing to Xinjiang)
MRIO_FU_42 = readmatrix(IO_path,'sheet','MRIO2017','range','AXG8:BDF1309');
% Imports (intermediate input part) and imports (final use part)
MRIO_IM_4Z_42 = readmatrix(IO_path,'sheet','MRIO2017','range','D1310:AXE1351'); %(IM for Z)
MRIO_IM_4FU_42 = readmatrix(IO_path,'sheet','MRIO2017','range','AXG1310:BDF1351'); %(IM for FU)
% Value added
MRIO_VA_42 = readmatrix(IO_path,'sheet','MRIO2017','range','D1353:AXE1356');
% Total output (excluding imports)
MRIO_X_42 = readmatrix(IO_path,'sheet','MRIO2017','range','BDH8:BDH1309');

% Split MRIO
% Allocate space for various parts of the 43-sector MRIO table
MRIO_Z_43_mid = zeros(1333,1302); MRIO_Z_43 = zeros(1333,1333); MRIO_FU_43 = zeros(1333,156); 
MRIO_IM_4Z_43 = zeros(43,1333); MRIO_IM_4FU_43 = zeros(43,156);
MRIO_VA_43 = zeros(4,1333); MRIO_X_43 = zeros(1333,1);
% Start splitting 'Accommodation and Catering' sector
% Intermediate input Z
% First, split 'Accommodation and Catering' sector along the row direction (output)
for i = 1:31 % 31 regions
    MRIO_Z_43_mid([(i-1)*43+1:(i-1)*43+29,(i-1)*43+32:(i-1)*43+43],:) =  MRIO_Z_42([(i-1)*42+1:(i-1)*42+29,(i-1)*42+31:(i-1)*42+42],:);
    MRIO_Z_43_mid([(i-1)*43+30,(i-1)*43+31],:) =  bsxfun(@times, MRIO_Z_42((i-1)*42+30,:), repmat(ratio_output,1,31));
end
% Since the row direction now has 43 rows, expand ratio_input to 43 rows to form a temporary allocation ratio.
ratio_input_temp([1:29,32:43],:) = ratio_input([1:29,31:42],:); 
ratio_input_temp([30,31],:) = repmat(ratio_input(30,:),2,1); 
% Finally, split 'Accommodation and Catering' sector along the column direction (input)
for i = 1:31 % 31 regions
    MRIO_Z_43(:,[(i-1)*43+1:(i-1)*43+29,(i-1)*43+32:(i-1)*43+43]) =  MRIO_Z_43_mid(:,[(i-1)*42+1:(i-1)*42+29,(i-1)*42+31:(i-1)*42+42]);
    MRIO_Z_43(:,[(i-1)*43+30,(i-1)*43+31]) = bsxfun(@times, MRIO_Z_43_mid(:,(i-1)*42+30), repmat(ratio_input_temp,31,1));
end
% Final use (including exports)
ratio_FU = horzcat(repmat(horzcat(ratio_101,ratio_102,ratio_103,ratio_201,ratio_202),1,31),ratio_EX); % Combine final use allocation ratios
for i = 1:31 % 31 regions
    MRIO_FU_43([(i-1)*43+1:(i-1)*43+29,(i-1)*43+32:(i-1)*43+43],:) = MRIO_FU_42([(i-1)*42+1:(i-1)*42+29,(i-1)*42+31:(i-1)*42+42],:);
    MRIO_FU_43([(i-1)*43+30,(i-1)*43+31],:) = bsxfun(@times, MRIO_FU_42((i-1)*42+30,:), ratio_FU) ;
end
% Total output
for i = 1:31 % 31 regions
    MRIO_X_43([(i-1)*43+1:(i-1)*43+29,(i-1)*43+32:(i-1)*43+43]) = MRIO_X_42([(i-1)*42+1:(i-1)*42+29,(i-1)*42+31:(i-1)*42+42]);
    MRIO_X_43([(i-1)*43+30,(i-1)*43+31]) = bsxfun(@times, MRIO_X_42((i-1)*42+30), ratio_X);
end
% Value added
for i = 1:31 % 31 regions
    MRIO_VA_43(:,[(i-1)*43+1:(i-1)*43+29,(i-1)*43+32:(i-1)*43+43]) = MRIO_VA_42(:,[(i-1)*42+1:(i-1)*42+29,(i-1)*42+31:(i-1)*42+42]);
    MRIO_VA_43(:,[(i-1)*43+30,(i-1)*43+31]) = bsxfun(@times, MRIO_VA_42(:,(i-1)*42+30), ratio_VA);
end
% Imports (intermediate input part) and imports (final use part)
MRIO_IM_4Z_43_mid([1:29,32:43],:) = MRIO_IM_4Z_42([1:29,31:42],:);
MRIO_IM_4Z_43_mid([30,31],:) = bsxfun(@times, MRIO_IM_4Z_42(30,:), repmat(ratio_output,1,31));
for i = 1:31 % 31 regions
    MRIO_IM_4Z_43(:,[(i-1)*43+1:(i-1)*43+29,(i-1)*43+32:(i-1)*43+43]) =  MRIO_IM_4Z_43_mid(:,[(i-1)*42+1:(i-1)*42+29,(i-1)*42+31:(i-1)*42+42]);
    MRIO_IM_4Z_43(:,[(i-1)*43+30,(i-1)*43+31]) = bsxfun(@times, MRIO_IM_4Z_43_mid(:,(i-1)*42+30), ratio_input_temp);
end
for i = 1:31 % 31 regions
    MRIO_IM_4FU_43([1:29,32:43],:) = MRIO_IM_4FU_42([1:29,31:42],:);
    MRIO_IM_4FU_43([30,31],:) = bsxfun(@times, MRIO_IM_4FU_42(30,:), ratio_FU) ;
end

save('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_wholesale_retail&catering\MRIO_CHINA2017_43.mat',...
    'MRIO_Z_43','MRIO_FU_43','MRIO_X_43','MRIO_IM_4FU_43','MRIO_IM_4Z_43','MRIO_VA_43','SECTOR_43');
toc

%% Merge the MRIO_43 sectors into 32 sectors (combining the catering sector into the service sector)
clc; clear; tic;
load('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_wholesale_retail&catering\MRIO_CHINA2017_43.mat');
SECTOR_32 (1:31,:) = SECTOR_43(1:31); SECTOR_32 (32,:) = {'Other Services'};
% Preallocate space for the 32-sector MRIO table parts
MRIO_Z_32_mid = zeros(992,1333); MRIO_Z_32 = zeros(992,992); MRIO_FU_32 = zeros(992,156); 
MRIO_IM_4Z_32 = zeros(32,992); MRIO_IM_4FU_32 = zeros(32,156);
MRIO_VA_32 = zeros(4,992); MRIO_X_32 = zeros(992,1);
% Start merging
% Intermediate Input Z
for i = 1:31 % 31 regions
    MRIO_Z_32_mid([(i-1)*32+1:(i-1)*32+31],:) = MRIO_Z_43([(i-1)*43+1:(i-1)*43+31],:);
    MRIO_Z_32_mid((i-1)*32+32,:)= sum(MRIO_Z_43([(i-1)*43+32:(i-1)*43+43],:),1);
end
for i = 1:31 % 31 regions
    MRIO_Z_32(:,[(i-1)*32+1:(i-1)*32+31]) = MRIO_Z_32_mid(:,[(i-1)*43+1:(i-1)*43+31]);
    MRIO_Z_32(:,(i-1)*32+32)= sum(MRIO_Z_32_mid(:,[(i-1)*43+32:(i-1)*43+43]),2);
end
% Final Use, Total Output, and Value Added
for i = 1:31 % 31 regions
    MRIO_FU_32([(i-1)*32+1:(i-1)*32+31],:) =  MRIO_FU_43([(i-1)*43+1:(i-1)*43+31],:); % Final Use FU
    MRIO_FU_32((i-1)*32+32,:) = sum(MRIO_FU_43([(i-1)*43+32:(i-1)*43+43],:),1);
    
    MRIO_X_32([(i-1)*32+1:(i-1)*32+31],:) =  MRIO_X_43([(i-1)*43+1:(i-1)*43+31],:); % Total Output X
    MRIO_X_32((i-1)*32+32,:) = sum(MRIO_X_43([(i-1)*43+32:(i-1)*43+43],:),1);
    
    MRIO_VA_32(:,[(i-1)*32+1:(i-1)*32+31]) = MRIO_VA_43(:,[(i-1)*43+1:(i-1)*43+31]);
    MRIO_VA_32(:,(i-1)*32+32)= sum(MRIO_VA_43(:,[(i-1)*43+32:(i-1)*43+43]),2);
end
% Imports
MRIO_IM_4Z_32_mid([1:31],:) = MRIO_IM_4Z_43([1:31],:); 
MRIO_IM_4Z_32_mid(32,:) = sum(MRIO_IM_4Z_43([32:43],:),1);
for i = 1:31 % 31 regions
    MRIO_IM_4Z_32(:,[(i-1)*32+1:(i-1)*32+31]) = MRIO_IM_4Z_32_mid(:,[(i-1)*43+1:(i-1)*43+31]);
    MRIO_IM_4Z_32(:,(i-1)*32+32) = sum(MRIO_IM_4Z_32_mid(:,[(i-1)*43+32:(i-1)*43+43]),2);
end

MRIO_IM_4FU_32([1:31],:) = MRIO_IM_4FU_43([1:31],:);
MRIO_IM_4FU_32(32,:) = sum(MRIO_IM_4FU_43([32:43],:),1);

save('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_wholesale_retail&catering\MRIO_CHINA2017_32.mat',...
    'MRIO_Z_32','MRIO_FU_32','MRIO_X_32','MRIO_IM_4FU_32','MRIO_IM_4Z_32','MRIO_VA_32','SECTOR_32');
toc

%% Extract energy consumption data for wholesale and retail, and catering sectors
clear; clc; tic;
data_path = 'D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\Energy_consumption_China.xlsx';
industry = transpose(readcell(data_path, 'sheet', 'Shanghai2019', 'Range', 'A46:A46'));
energy_type = readcell(data_path, 'sheet', 'Shanghai2019', 'Range', 'B1:U1');
province = sheetnames(data_path);
province(1) = []; % Remove the first sheet name if not relevant
wholesale_retail_catering_energy = cell(numel(province),1); 
for i = 1:numel(province)
    N = province(i);
    wholesale_retail_catering_energy{i} = readmatrix(data_path, 'sheet', N, 'Range', 'B47:U47'); % Energy data for wholesale, retail, and catering
end
clear N; clear i;
wholesale_retail_catering_energy = cat(3, wholesale_retail_catering_energy{:});
original_size = size(wholesale_retail_catering_energy); % Get all dimensions: rows, columns, layers
wholesale_retail_catering_energy = sum(wholesale_retail_catering_energy, 1);
wholesale_retail_catering_energy = num2cell(transpose(reshape(wholesale_retail_catering_energy, [original_size(2), original_size(3)])));
province = strrep(province, 'InnerMongolia', 'Inner Mongolia');
province = strrep(province, '2019', '');
province = cellstr(province);
wholesale_retail_catering_energy = cat(2, province, wholesale_retail_catering_energy);
wholesale_retail_catering_energy{31,1} = 'Tibet';
for i = 1:20
    wholesale_retail_catering_energy{31,i+1} = 0;
end
% Sort the energy consumption data according to the standard regional order
load('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_processing\processing_ww_GHG.mat', 'product_province');

% Find the indices of each region name in the sorted order
[~, sortedIndices] = ismember(wholesale_retail_catering_energy(:, 1), product_province);
% Sort the cell array according to the indices
N = sortrows([sortedIndices, (1:size(wholesale_retail_catering_energy, 1)).']);
wholesale_retail_catering_energy_consumption = wholesale_retail_catering_energy(N(:,2), :); % Total energy consumption for wholesale, retail, and catering (by energy type)

% Split the energy data into 'wholesale retail', 'accommodation', and 'catering'
load('D:\OneDrive - mails.jlu.edu.cn\科研\paper-3\code\food_wholesale_retail&catering\MRIO_CHINA2017_32.mat');
% Split the original energy inventory into 'wholesale retail' (column 28), 'accommodation' (column 30), and 'catering' (column 31)
% by energy type (fossil energy, natural gas, electricity)
num_target_sector = 3; % Target split sectors: wholesale retail (28), accommodation (30), catering (31)
num_IO_sector = length(SECTOR_32);
total_fossil = zeros(31, 31*num_target_sector); 
total_natrual_gas = zeros(31, 31*num_target_sector);
total_elec_heat = zeros(31, 31*num_target_sector);
for i = 1:31
    for j = 1:31
        total_fossil(i,[(j-1)*num_target_sector+1:(j-1)*num_target_sector+3]) = ...
            MRIO_Z_32((i-1)*num_IO_sector+11,[(j-1)*num_IO_sector+28,(j-1)*num_IO_sector+30,(j-1)*num_IO_sector+31]); % Major fossil fuels
        total_natrual_gas(i,[(j-1)*num_target_sector+1:(j-1)*num_target_sector+3]) = ...
            MRIO_Z_32((i-1)*num_IO_sector+25,[(j-1)*num_IO_sector+28,(j-1)*num_IO_sector+30,(j-1)*num_IO_sector+31]); % Natural gas
        total_elec_heat(i,[(j-1)*num_target_sector+1:(j-1)*num_target_sector+3]) = ...
            MRIO_Z_32((i-1)*num_IO_sector+24,[(j-1)*num_IO_sector+28,(j-1)*num_IO_sector+30,(j-1)*num_IO_sector+31]); % Electricity and heat
    end
end
total_fossil = sum(total_fossil, 1); ratio_fossil = zeros(31, num_target_sector);
total_natrual_gas = sum(total_natrual_gas, 1); ratio_natrual_gas = zeros(31, num_target_sector);
total_elec_heat = sum(total_elec_heat, 1); ratio_elec_heat = zeros(31, num_target_sector);
for i = 1:31
    for j = 1:num_target_sector
        ratio_fossil(i, j) = total_fossil(1, (i-1)*num_target_sector + j) / sum(total_fossil(1, [(i-1)*num_target_sector+1:i*num_target_sector]), 2);
        ratio_natrual_gas(i, j) = total_natrual_gas(1, (i-1)*num_target_sector + j) / sum(total_natrual_gas(1, [(i-1)*num_target_sector+1:i*num_target_sector]), 2);
        ratio_elec_heat(i, j) = total_elec_heat(1, (i-1)*num_target_sector + j) / sum(total_elec_heat(1, [(i-1)*num_target_sector+1:i*num_target_sector]), 2);
    end
end
% Xinjiang's natural gas ratio is all 0 because the input-output table shows no local supply to Xinjiang’s accommodation and catering sectors; all supply is imported. Therefore, use the values from Ningxia (row 30) to replace Xinjiang.
ratio_natrual_gas(31, :) = ratio_natrual_gas(30, :);

% Calculate using total energy consumption and proportions
total_ratio_wholesale_retail = zeros(31, 20); total_ratio_catering = zeros(31, 20);

total_ratio_wholesale_retail(:, [1:13, 15, 16, 20]) = repmat(ratio_fossil(:, 1), 1, 16); 
total_ratio_wholesale_retail(:, [14, 17]) = repmat(ratio_natrual_gas(:, 1), 1, 2);
total_ratio_wholesale_retail(:, [18, 19]) = repmat(ratio_elec_heat(:, 1), 1, 2);

total_ratio_catering(:, [1:13, 15, 16, 20]) = repmat(ratio_fossil(:, 3), 1, 16); 
total_ratio_catering(:, [14, 17]) = repmat(ratio_natrual_gas(:, 3), 1, 2);
total_ratio_catering(:, [18, 19]) = repmat(ratio_elec_heat(:, 3), 1, 2);

wholesale_retail_catering_energy_consumption(:, 1) = [];
energy_consumption_wholesale_retail = cell2mat(wholesale_retail_catering_energy_consumption) .* total_ratio_wholesale_retail;
energy_consumption_catering = cell2mat(wholesale_retail_catering_energy_consumption) .* total_ratio_catering;

toc
