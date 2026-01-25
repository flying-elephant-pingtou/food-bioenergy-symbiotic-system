% This code first extracts and consolidates emissions data from the sectors related to packaging materials in the satellite accounts. Then, it calculates the SFS of the packaging materials sector using the MRIO table. By integrating these datasets, it computes the carbon emissions associated with the energy consumption of packaging materials used in food processing.
%% Extract and integrate satellite account data
% ---------------Extract emission data from satellite accounts------------------------
clc; clear;tic;
data_path = 'China_provincial_CO2_emission_inventory_BY_CEADS.xlsx';
rows_to_read = [20,22,23,24,26:31,34];
initial_title = readcell(data_path,'sheet','Shanghai2019','Range','A1:A51');
industry_p = cell(1,length(rows_to_read));
for i = 1:length(rows_to_read)
    s = rows_to_read(i);
    industry_p{i} = initial_title{s};
end
province = sheetnames(data_path);
province(1) = [];
ec_CO2_p = cell(numel(province),11); %unit:Mton, 11 sectors merged into 5 sectors
for i = 1:numel(province)
    for j = 1:length(rows_to_read)
        N = province(i);
        R = rows_to_read(j);
        str1 = 'W';
        str2 = num2str(R);
        cell_address = [str1 str2 ':' str1 str2];
        ec_CO2_p{i,j} = readmatrix(data_path,'sheet',province(i),'Range',cell_address);
    end
end
% --------------------Rename province names and add a row for Tibet to match the format-------------------
province = strrep(province, 'InnerMongolia', 'Inner Mongolia');
province = strrep(province, '2019', '');
province = cellstr(province);
ec_CO2_p = cat(2,province,ec_CO2_p);
newRow = cell(1, size(ec_CO2_p, 2));
newRow{1,1} = 'Tibet';
ec_CO2_p = [ec_CO2_p; newRow];
for i = 1:size(ec_CO2_p, 1)
    for j = 1:size(ec_CO2_p, 2)
        if isempty(ec_CO2_p{i, j})
            ec_CO2_p{i, j} = 0;
        end
    end
end

%-------------Sort and organize ec_CO2 data according to the standard regional order------------------
load('processing_ww_GHG.mat', 'product_province'); % Standard province order
% Find the index of each region name in the sorted order
[~, sortedIndices] = ismember(ec_CO2_p(:, 1), product_province);

% Use sortrows to sort the cell array based on the indices
N = sortrows([sortedIndices, (1:size(ec_CO2_p, 1)).']);
sorted_ec_CO2_p = ec_CO2_p(N(:,2), :);
ec_CO2_p_industry = zeros(31,11);
for i = 1:31
    for j = 1:11
        ec_CO2_p_industry(i,j) = sorted_ec_CO2_p{i,j+1}*1000; %unit:kton
    end
end

%% Select emissions from the 42 sectors corresponding to packaging sectors (wood, paper, chemical products (plastic), non-metallic products (glass), metal products)
ec_CO2_package = zeros(31,5);
C = mat2cell(ec_CO2_p_industry,[31],[1,1,1,1,1,1,1,1,1,1,1,2]); % Split into 11 sectors
ec_CO2_package(:,1) = C{1}; ec_CO2_package(:,2) = C{2}; ec_CO2_package(:,3) = C{9};
ec_CO2_package(:,4) = C{10}; ec_CO2_package(:,5) = C{11};
PS(1,1) ={ 'ec_CO2_p_industry is the original 11 sectors involved in packaging from CEADs emission data source, ec_CO2_package is the selected ones, all units are kton'};
% In the multi-sector input-output table at the provincial level, plastic has a higher input to the food industry, while other chemical products have less input. We assume that the SFS of the plastic industry = the SFS of chemical products, so energy consumption emissions are directly selected from the plastic industry instead of being replaced by chemical products. The same assumption applies to other products.
package_category(1,1) = {'wood'};
package_category(1,2) = {'paper'};
package_category(1,3) = {'plastic'};
package_category(1,4) = {'nonmetal_including glass'};
package_category(1,5) = {'metal'};

%% Calculate the SFS of packaging
MRIO_TABLE = 'F:\OneDrive - mails.jlu.edu.cn\科研\paper-3\数据&参数\投入产出表\China_inter_provincial_IO.xlsx';
Z = readmatrix(MRIO_TABLE,'range','D8:AXE1309'); % Intermediate input matrix
X = readmatrix(MRIO_TABLE,'range','BDH8:BDH1309'); % Total output (row vector)
industry = readcell(MRIO_TABLE,'range','C8:C49'); % Industry
SFP = zeros(1302,31); % share of food processing, representing the proportion of output flowing to the food and tobacco sectors in 31 regions * 42 industries = 1302.
for i = 1:length(SFP)
    for j = 1:size(SFP,2)
        SFP(i,j) = Z(i,j*42-36) / X(i);
    end
end

%-------Extract SFS for packaging sectors (corresponding to five sectors)-----------
% 1. Define the block size and number of blocks
num_industry = 42;
num_regions = size(SFP, 1) / num_industry;
% 2. Initialize an empty matrix to store the extracted data
SFP_package = [];
% 3. Use a for loop to extract the data
for i = 1:num_regions
    % Calculate the start and end rows of the current block
    startRow = (i - 1) * num_industry + 1;
    endRow = i * num_industry;
    % Extract the 9th, 10th, 12th, 13th, and 15th rows of the current block
    rowsToExtract = [9, 10, 12, 13, 15];
    blockData = SFP(startRow:endRow, :);
    selectedRows = blockData(rowsToExtract, :);
    
    % Add the extracted data to SFP_package
    SFP_package = [SFP_package; selectedRows];
end
%% Calculate packaging emissions
num_package_industry = 5;
package_ec_CO2 = [];
for i = 1:num_regions
    % Calculate the start and end rows of the current block
    startRow = (i - 1) * num_package_industry + 1;
    endRow = i * num_package_industry;
    % Calculate emissions for one region
    a = ec_CO2_package(i,:);
    A = SFP_package(startRow:endRow, :) .* a';
    % Add the emissions for this region to package_ec_CO2
    package_ec_CO2 = [package_ec_CO2; A];
end
PS(2,1) = {'This data contains emissions from five packaging sectors (wood, paper, plastic, non-metal (glass), metal) in 31 provincial regions used in food processing, and can be refined to specify which provinces the packaging products flow to; unit is kton CO2-eq'};
save("processing_package_GHG.mat","SFP_package","package_ec_CO2","PS");
toc
