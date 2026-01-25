% This code applies a multi-objective optimization model aimed to maximize GHG mitigations and net profits at the national scale.

%% Main 
clc; clear; tic

% ====== Loading input data ======
load('data4formulation.mat'); % Input data: 'energyConsumption','biowasteAmounts', 'techLifecycle'
numProvinces = 31; % Number of provinces
numSubsystems = 10; % Number of subsystems (Crop farming, Livestock farming, Aquaculture, Food processing, Transportation, Retail, Catering, Urban consumption, Rural consumption, Waste disposal)
numBiowaste = 3; % Types of biowaste (Straw, Manure, Food waste)
numTechnologies = {8, 2, 3}; % Number of technologies corresponding to each biowaste type
numEnergyTypes = 9; % Types of energy/resources (Coal, Gasoline, Diesel, Natural gas, Heat, Electricity, Nitrogen fertilizer, Phosphorus fertilizer, Biochar)
numImpacts = 8; % Midpoint impacts including 8 types

% Types of energy acceptable for each subsystem (1 Coal, 2 Gasoline, 3 Diesel, 4 Natural gas, 5 Heat, 6 Electricity, 7 Nitrogen fertilizer, 8 Phosphorus fertilizer, 9 Biochar)
acceptableEnergyTypes = {
    [3, 6, 7, 8, 9], 
    [1, 3, 6], 
    [2, 3, 6], 
    [1, 2, 3, 4, 5, 6], 
    [1, 2, 3, 4], 
    [1, 2, 3, 4, 6], 
    [1, 2, 3, 4, 5, 6], 
    [1, 4, 6], 
    [1, 4, 6], 
    [3, 6] 
    };
% Define priority order (1 Crop farming, 2 Livestock farming, 3 Aquaculture, 4 Food processing, 5 Transportation, 6 Retail, 7 Catering, 8 Urban consumption, 9 Rural consumption, 10 Waste disposal)
priorityOrder = {
    [1, 2, 3, 9, 5, 4, 6, 7, 8, 10], 
    [2, 1, 3, 9, 5, 4, 6, 7, 8, 10], 
    [10, 5, 4, 7, 6, 8, 9, 1, 2, 3]  
    };

% ====== Dimension of decision variables ======
nVars = sum(cellfun(@(n)n,numTechnologies)) * numProvinces;
lb = zeros(1,nVars);
ub = ones(1,nVars); 

% Generate the initial population
popSize = 1000;   % Population size
initPop = lhsdesign(popSize, nVars);    
initPop = repmat(lb, popSize, 1) + initPop .* (repmat(ub-lb, popSize, 1));

% ====== gamultiobj settings ======
options = optimoptions('gamultiobj',...
    'PopulationSize', popSize,...
    'MaxGenerations', 200,...
    'InitialPopulationMatrix', initPop,...   
    'CrossoverFraction', 0.6,...
    'MutationFcn', {@mutationgaussian, 0.8, 0.05},...
    'DistanceMeasureFcn', {@distancecrowding,'phenotype'},...
    'ParetoFraction', 0.35, ...                
    'MaxStallGenerations', 500, ...
    'FunctionTolerance', 1e-8, ...
    'Display','iter',...
    'PlotFcn',{@gaplotpareto});

% ====== running the model ======
[x,fval,exitflag,output,population,scores] = gamultiobj(@fitness_multi,nVars,[],[],[],[],lb,ub,@exceed_constraint,options);

%% save result

save('pareto_result.mat','x','fval','exitflag','output','population','scores');

%% Draw the Pareto frontier
figure;
totalReduction_real = fval(:,1) * 320;   % Emission reduction of greenhouse gases (maximum value ≈ 320)
netProfit_real      = -fval(:,2) * 17000; % Net profit (maximum value ≈ 17,000)
scatter(totalReduction_real, netProfit_real, 50, 'filled');
xlabel('GHG mitigation (Mt CO2-eq)');
ylabel('Net profit (Million CNY)');
title('Pareto frontier');
grid on;

toc

%% Function definition
% ========Objective function==========
function f = fitness_multi(x)
    global numProvinces numBiowaste numTechnologies biowasteAmounts
    % Vector decoding
    individual = decodeIndividual(x,numProvinces,numBiowaste,numTechnologies,biowasteAmounts);
    % Calculate emission mitigation and net profits
    [~, totalReduction, ~, ~, ~, ~, ~, netProfit,~] = calculateFitness_multi(individual);
    % gamultiobj Default Minimization → Take a negative number
    f = [totalReduction/320, -netProfit/17000];
end

% ===========Objective and Constraint Calculation Function=========
function [fitness, totalReduction, energyProduction, provinceEnergyLeft, provinceImpacts, bioenergyImpacts, national_totalEnergy, netProfit, provinceEnergyDemand] = calculateFitness_multi(individual)
global energyConsumption;
global biowasteAmounts;
global techLifecycle;
global numProvinces;
global numSubsystems;
global numBiowaste;
global numEnergyTypes;
global acceptableEnergyTypes;
global priorityOrder;
global numTechnologies
global numImpacts

totalReduction = 0;  % Initialize total GHG mitigation reduction
fitness = 0; 
provinceImpacts = zeros(numBiowaste,numImpacts,numProvinces);
bioenergyImpacts = zeros(numBiowaste,numImpacts,numProvinces);
netProfit = 0; % Initialize total net profit

% Initialize the record variables
energyProduction = cell(numProvinces,1); 
provinceEnergyLeft = zeros(numSubsystems,numEnergyTypes,numProvinces); 
exceedEnergy = zeros(numEnergyTypes,numProvinces); 
national_totalEnergy = zeros(9,1);

for i = 1:numProvinces
    provinceEnergyDemand = squeeze(energyConsumption(:, :, i)); % Energy demand of all subsystems in the province, subsystems * energy types
    energyProduction{i} = cell(numBiowaste,1); % Province-biowaste
    provinceExceedEnergy = zeros(numEnergyTypes, 1); % Initialize excess energy for the current province
    for j = 1:numBiowaste
        techAmounts = individual{i}{j}; % Get the amount of biowaste allocated to each technology
        energyProduction{i}{j} = cell(numTechnologies{j},1);% biowaste-technology
        for t = 1:length(techAmounts)
            biowasteAmount = techAmounts(t);
            lifecycleData = techLifecycle{j, t};
            energyOutputs = lifecycleData.energyOutputs;
            
            % ====== GHG mitigation ======
            reduction = lifecycleData.total_impacts(1) * biowasteAmount; 
            totalReduction = totalReduction + reduction;
            
            % ====== Environmental ======
            provinceImpacts_1 = lifecycleData.total_impacts .* biowasteAmount; 
            provinceImpacts(j,:,i) = provinceImpacts(j,:,i) + provinceImpacts_1'; 
            bioenergyImpacts_1 = lifecycleData.bioenergyImpacts .* biowasteAmount; 
            bioenergyImpacts(j,:,i) = bioenergyImpacts(j,:,i) + bioenergyImpacts_1'; 
            
            % ====== Net profit ======
            profit = lifecycleData.net_profit * biowasteAmount; 
            netProfit = netProfit + profit;
            
            % ====== Calculate energy output and demand satisfaction ======
            energyProduction{i}{j}{t} = zeros(length(energyOutputs),numSubsystems);
            
            for k = 1:length(energyOutputs)
                energyType = energyOutputs(k).type; % Energy product type
                energyAmount = energyOutputs(k).amount * biowasteAmount; % Energy product amount
                % Find the index of the last subsystem that contains this energy type
                lastSubsystemIndex = findLastSubsystem(energyType, acceptableEnergyTypes);
                national_totalEnergy(energyType) = national_totalEnergy(energyType) + energyAmount; 
                
                % Allocate energy products based on priority order
                switch j
                    case 1, order = priorityOrder{1};
                    case 2, order = priorityOrder{2};
                    case 3, order = priorityOrder{3};
                end
                for idx = 1:length(order)  % Start allocating energy products
                    prioritySubSystem = order(idx); % Select subsystem
                    if energyAmount > 0
                        if ismember(energyType, acceptableEnergyTypes{prioritySubSystem})
                            subSystemEnergyNeed = provinceEnergyDemand(prioritySubSystem, energyType);
                            
                            if energyAmount >= subSystemEnergyNeed
                                energyAmount = energyAmount - subSystemEnergyNeed;
                                energyProduction{i}{j}{t}(k,prioritySubSystem) = subSystemEnergyNeed;
                                provinceEnergyDemand(prioritySubSystem, energyType) = 0;
                            else
                                provinceEnergyDemand(prioritySubSystem, energyType) = subSystemEnergyNeed - energyAmount;
                                energyProduction{i}{j}{t}(k,prioritySubSystem) = energyAmount;
                                energyAmount = 0;
                            end
                        end
                    end
                    if prioritySubSystem == lastSubsystemIndex && energyAmount > 0  % Check if this is the last iteration and if there is any remaining energy product
                        provinceExceedEnergy(energyType) = provinceExceedEnergy(energyType) + energyAmount;
                    end
                end
            end
        end
    end
    exceedEnergy(:, i) = provinceExceedEnergy;
    provinceEnergyLeft(:, :, i) = provinceEnergyDemand;
end
end

% Find the index of the last subsystem that contains a specific energy type
function lastSubsystemIndex = findLastSubsystem(energyType, acceptableEnergyTypes)
lastSubsystemIndex = -1; 
for i = 1:length(acceptableEnergyTypes)
    if ismember(energyType, acceptableEnergyTypes{i})
        lastSubsystemIndex = i; 
    end
end
end


% ======Constraint function========
function [c,ceq] = exceed_constraint(x)
global numProvinces numBiowaste numTechnologies biowasteAmounts energyConsumption

% 1. Decoding individual
individual = decodeIndividual(x,numProvinces,numBiowaste,numTechnologies,biowasteAmounts);

% 2. Call the Objective and Constraint Calculation Function to obtain the energy output and demand
[~, ~, ~, provinceEnergyLeft,~, ~, national_totalEnergy, ~, ~] = calculateFitness_multi(individual);

% Initialization
ceq = [];

% === Total national energy output ===
totalProduction = sum (national_totalEnergy(1:6),'all' );

% === National total demand & residual demand ===
q = sum(energyConsumption,3); p = sum(provinceEnergyLeft,3);
totalDemand = sum(q(:,[1:6]),'all');
totalDemandLeft = sum(p(:,[1:6]),'all');
satisfied = totalDemand - totalDemandLeft;

% === Surplus quantity ===
overflow = totalProduction - satisfied;

% === Surplus quantity (Avoid division by zero) ===
if totalProduction > 0
    overflowRate = overflow / totalProduction;
else
    overflowRate = 0;
end

% === National constrain: overflowRate <= 30% -------------- overflowRate - 0.3 <= 0
c = overflowRate - 0.3;

end


% ======Decoding function===========
function individual = decodeIndividual(x,numProvinces,numBiowaste,numTechnologies,biowasteAmounts)
    individual = cell(numProvinces,1);
    idx = 1;
    for i=1:numProvinces
        individual{i} = cell(numBiowaste,1);
        for j=1:numBiowaste
            nTech = numTechnologies{j};
            vals = x(idx:idx+nTech-1);
            idx = idx+nTech;
            % Scale down proportionally，make sure the sum = biowasteAmounts(i,j)
            if sum(vals)==0
                scaled = zeros(1,nTech);
            else
                scaled = vals/sum(vals) * biowasteAmounts(i,j);
            end
            individual{i}{j} = scaled;
        end
    end
end

