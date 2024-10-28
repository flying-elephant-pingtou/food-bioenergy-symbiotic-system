% This code applies a genetic algorithm model with the optimization objectives of maximizing greenhouse gas emissions reduction and localizing product supply. It determines the optimal allocation of biowaste-to-energy conversion technologies and the final destination of products to the food subsystems.
%% Initialize parameters & run GA model
clc;clear;tic
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
global provinceEnergyDemand
global generation
global maxGenerations
load('data4formulation.mat'); % Input data: 'energyConsumption','biowasteAmounts', 'techLifecycle'
numProvinces = 31; % Number of provinces
numSubsystems = 10; % Number of subsystems (Crop farming, Livestock farming, Aquaculture, Food processing, Transportation, Retail, Catering, Urban consumption, Rural consumption, Waste disposal)
numBiowaste = 3; % Types of biowaste (Straw, Manure, Food waste)
numTechnologies = {8, 2, 3}; % Number of technologies corresponding to each biowaste type
numEnergyTypes = 9; % Types of energy/resources (Coal, Gasoline, Diesel, Natural gas, Heat, Electricity, Nitrogen fertilizer, Phosphorus fertilizer, Biochar)
numImpacts = 8; % Midpoint impacts including 8 types

populationSize = 80; % Population size
crossoverRate = 0.9; % Crossover rate
mutationRate = 0.2; % Mutation rate
maxGenerations = 2000; % Maximum number of iterations/generation
tournamentSize = 40; % Tournament selection size

% Types of energy acceptable for each subsystem (1 Coal, 2 Gasoline, 3 Diesel, 4 Natural gas, 5 Heat, 6 Electricity, 7 Nitrogen fertilizer, 8 Phosphorus fertilizer, 9 Biochar)
acceptableEnergyTypes = {
    [3, 6, 7, 8, 9], % Crop farming
    [1, 3, 6], % Livestock farming
    [2, 3, 6], % Aquaculture
    [1, 2, 3, 4, 5, 6], % Food processing
    [1, 2, 3, 4], % Transportation
    [1, 2, 3, 4, 6], % Retail
    [1, 2, 3, 4, 5, 6], % Catering
    [1, 4, 6], % Urban consumption
    [1, 4, 6], % Rural consumption
    [3, 6] % Waste disposal
    };

% Define priority order (1 Crop farming, 2 Livestock farming, 3 Aquaculture, 4 Food processing, 5 Transportation, 6 Retail, 7 Catering, 8 Urban consumption, 9 Rural consumption, 10 Waste disposal)
priorityOrder = {
    [1, 2, 3, 9, 5, 4, 6, 7, 8, 10], % When the energy produced from straw exceeds the needs of the crop farming subsystem, it is preferentially allocated to livestock farming, aquaculture, rural consumption, transportation, food processing...
    [2, 1, 3, 9, 5, 4, 6, 7, 8, 10], % When the energy produced from manure exceeds the needs of the livestock farming subsystem, it is preferentially allocated to crop farming, aquaculture, rural consumption, transportation, food processing...
    [10, 5, 4, 7, 6, 8, 9, 1, 2, 3]  % When the energy produced from food waste exceeds the needs of the waste disposal subsystem, it is preferentially allocated to...
    };

% Initialize population
population = cell(populationSize, 1);
for i = 1:populationSize
    individual = cell(numProvinces, 1);
    for j = 1:numProvinces
        individual{j} = cell(numBiowaste, 1);
        for k = 1:numBiowaste
            % The amount of each biowaste is allocated to different technologies, initialized randomly
            totalAmount = biowasteAmounts(j, k);
            individual{j}{k} = rand(1, numTechnologies{k}); % Generate a random row with numTechnologies{k} columns, each value between 0 and 1
            individual{j}{k} = individual{j}{k} / sum(individual{j}{k}) * totalAmount; % The amount of each biowaste is randomly allocated to technologies, ensuring the total allocation remains constant
        end
    end
    population{i} = individual;
end

% Main loop
fitness = zeros(populationSize, 1);
for generation = 1:maxGenerations
    % Calculate the fitness of each individual
    for i = 1:populationSize
        [fitness(i),totalReduction, ~, ~, ~, ~, ~] = calculateFitness(population{i});
    end
    
    % Tournament selection operation
    newPopulation = tournamentSelection(population, fitness, tournamentSize);
    
    % Crossover and mutation operations
    for i = 1:2:populationSize
        parent1 = newPopulation{i};
        parent2 = newPopulation{i+1};
        [child1, child2] = crossover(parent1, parent2, crossoverRate);
        newPopulation{i} = mutation(child1, mutationRate, numTechnologies, biowasteAmounts);
        newPopulation{i+1} = mutation(child2, mutationRate, numTechnologies, biowasteAmounts);
    end
    
    population = newPopulation;
    bestFitness = min(fitness);
    bestReduction = min(totalReduction);
    disp(['Generation ' num2str(generation) ': Best Fitness = ' num2str(bestFitness) 'Best Reduction = ' num2str(bestReduction)]);
end

% Output the best solution
[~, bestIndex] = min(fitness);
bestSolution = population{bestIndex};
[~, totalReduction, energyProduction, provinceEnergyLeft, provinceImpacts, bioenergyImpacts, exceedEnergy] = calculateFitness(bestSolution);
disp('Best Solution:');
disp(bestSolution);

save('formulation_result.mat','totalReduction','bestSolution','energyProduction','provinceEnergyLeft','provinceImpacts','bioenergyImpacts','exceedEnergy');
toc

%% Define functions
% Fitness function
function [fitness, totalReduction, energyProduction, provinceEnergyLeft, provinceImpacts, bioenergyImpacts, exceedEnergy] = calculateFitness(individual)
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
global provinceEnergyDemand
global generation
global maxGenerations
totalReduction = 0;  % Initialize total greenhouse gas emission reduction
fitness = 0; % Initialize fitness value
penalty = 0; % Initialize penalty coefficient
provinceImpacts = zeros(numBiowaste,numImpacts,numProvinces);
bioenergyImpacts = zeros(numBiowaste,numImpacts,numProvinces);
% Initialize recording variables
energyProduction = cell(numProvinces,1); % Bioenergy production per province (province-biowaste type-selected technology-product-destination subsystem)
provinceEnergyLeft = zeros(numSubsystems,numEnergyTypes,numProvinces); % Remaining energy demand of each subsystem per province after bioenergy substitution of fossil energy
exceedEnergy = zeros(numEnergyTypes,numProvinces); % Excess energy production exceeding all local subsystems
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
            
            reduction = lifecycleData.total_impacts(1) * biowasteAmount; % Greenhouse gas emission reduction
            totalReduction = totalReduction + reduction;
            provinceImpacts_1 = lifecycleData.total_impacts .* biowasteAmount; 
            provinceImpacts(j,:,i) = provinceImpacts(j,:,i) + provinceImpacts_1';
            bioenergyImpacts_1 = lifecycleData.bioenergyImpacts .* biowasteAmount; 
            bioenergyImpacts(j,:,i) = bioenergyImpacts(j,:,i) + bioenergyImpacts_1'; 
            
            energyProduction{i}{j}{t} = zeros(length(energyOutputs),numSubsystems);
            
            % Calculate energy output and demand satisfaction
            
            for k = 1:length(energyOutputs) % Energy products
                energyType = energyOutputs(k).type; % Energy product type
                energyAmount = energyOutputs(k).amount * biowasteAmount; % Energy product amount
                % Find the index of the last subsystem that contains this energy type
                lastSubsystemIndex = findLastSubsystem(energyType, acceptableEnergyTypes);
                
                % Allocate energy products based on priority order
                switch j
                    case 1 % Straw
                        order = priorityOrder{1};
                    case 2 % Manure
                        order = priorityOrder{2};
                    case 3 % Food waste
                        order = priorityOrder{3};
                end
                for idx = 1:length(order) % Start allocating energy products
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
                    if prioritySubSystem == lastSubsystemIndex && energyAmount > 0 % Check if this is the last iteration and if there is any remaining energy product
                            penalty = penalty + 5;
                        provinceExceedEnergy(energyType) = provinceExceedEnergy(energyType) + energyAmount;
                    end
                end
            end
        end
    end
    % Update exceedEnergy
    exceedEnergy(:, i) = provinceExceedEnergy;
    % Update provinceEnergyLeft
    provinceEnergyLeft(:, :, i) = provinceEnergyDemand;
end
% Calculate fitness value: The goal is to maximize greenhouse gas emission reduction and localize energy production as much as possible

weightPenalty = exp(-generation / maxGenerations); % Dynamically reduce the influence of penalty coefficient
weightReduction = 1 - weightPenalty; % Dynamically increase the influence of totalReduction

fitness = weightPenalty * penalty * sum(exceedEnergy, 'all')/10000000 + weightReduction * totalReduction;
end


% Tournament selection function
function selected = tournamentSelection(population, fitness, tournamentSize)
populationSize = length(population);
selected = cell(populationSize, 1);

for i = 1:populationSize
    % Randomly select tournamentSize individuals for the tournament
    tournamentIndices = randperm(populationSize, tournamentSize);
    tournamentFitness = fitness(tournamentIndices);
    
    % Select the individual with the best fitness
    [~, bestIndex] = min(tournamentFitness);
    selected{i} = population{tournamentIndices(bestIndex)};
end
end

% Crossover operation
function [child1, child2] = crossover(parent1, parent2, crossoverRate)
numProvinces = length(parent1);
if rand < crossoverRate
    crossoverPoint = randi([1 numProvinces-1]);
    child1 = [parent1(1:crossoverPoint); parent2(crossoverPoint+1:end)];
    child2 = [parent2(1:crossoverPoint); parent1(crossoverPoint+1:end)];
else
    child1 = parent1;
    child2 = parent2;
end
end

% Mutation operation
function mutated = mutation(individual, mutationRate, numTechnologies, biowasteAmounts)
for i = 1:length(individual)
    if rand < mutationRate
        for j = 1:length(individual{i})
            % Random mutation
            if rand < mutationRate
                totalAmount = biowasteAmounts(i, j);
                individual{i}{j} = rand(1, numTechnologies{j});
                individual{i}{j} = individual{i}{j} / sum(individual{i}{j}) * totalAmount;
            end
        end
    end
end
mutated = individual;
end

% Find the index of the last subsystem that contains a specific energy type
function lastSubsystemIndex = findLastSubsystem(energyType, acceptableEnergyTypes)
lastSubsystemIndex = -1; % Initialize to an invalid index
for i = 1:length(acceptableEnergyTypes)
    if ismember(energyType, acceptableEnergyTypes{i})
        lastSubsystemIndex = i; % Update to the current subsystem's index
    end
end
end

