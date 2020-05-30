%% Code description: 
% Solution PS1 - Business cycle facts (Brazil)
% International Economics and Finance - University of Bonn (SoSe 2020)
% Professor: KK
% Student: FZ

%% Housekeeping 
clear       % clear Workspace
close all   % close all figures
clc         % clear Command Window

%% Import WDI dataset
% Source: https://datacatalog.worldbank.org/dataset/world-development-indicators
% Option: import whole dataset (all countries) or individual country dataset?
wholedata = 1;          % if = 1: whole dataset; otherwise: country dataset
if wholedata == 1
    WDItable = readtable('WDIEXCEL.xlsx', 'Sheet', 'Data', 'TreatAsEmpty','..');
    % Restrict data to chosen country
    WDItable = WDItable(ismember(WDItable.CountryCode, 'BRA'),:);
    % Define indicators codes as row names
    WDItable.Properties.RowNames = WDItable.IndicatorCode;
    % Remove unneeded country and indicators names columns
    WDItable = removevars(WDItable, 1:4);
else
    WDItable = readtable('WDI_Brazil.xlsx', 'Sheet', 'Data', 'Range', 'D:BL',...
        'ReadRowNames', true, 'TreatAsEmpty','..');
end    

%% Restrict table to relevant indicators
% Create series with code names of relevant indicators
series = {'SP.POP.TOTL';    ... % Population, total
          'NY.GDP.MKTP.KN'; ... % GDP (constant LCU)
          'NE.CON.PRVT.KN'; ... % HHs and NPISHs Final consumption expenditure (constant LCU)
          'NE.GDI.TOTL.KN'; ... % Gross capital formation (constant LCU) 
          'NE.CON.GOVT.KN'; ... % General government final consumption expenditure (constant LCU)
          'NE.EXP.GNFS.KN'; ... % Exports of goods and services (constant LCU)
          'NE.IMP.GNFS.KN'; ... % Imports of goods and services (constant LCU)
          'BN.CAB.XOKA.GD.ZS'}; % Current account balance (% of GDP)
%{ 
Note that selected national accounts are already in constant prices instead of
current (nominal) prices which would need to be deflated by the GDP deflator
For WB methodology, see https://datahelpdesk.worldbank.org/knowledgebase/articles/114968-how-do-you-derive-your-constant-price-series-for-t
For a discussion on GDP deflation and inflation rate, see https://economistsview.typepad.com/economistsview/2008/09/the-gdp-deflato.html
%}
% Generate table with relevant indicators only
WDItable = WDItable(ismember(WDItable.Properties.RowNames, series),:);
% Rename indicators (RowNames)      
indicat ={'POP';            ... % Population, total
          'GDP';            ... % GDP (constant LCU)
          'CONS';           ... % HHs and NPISHs Final consumption expenditure (constant LCU)
          'INV';            ... % Gross capital formation (constant LCU) 
          'GOV';            ... % General government final consumption expenditure (constant LCU)
          'EXP';            ... % Exports of goods and services (constant LCU)
          'IMP';            ... % Imports of goods and services (constant LCU)
          'CAB_GDP'};           % Current account balance (% of GDP)
WDItable.Properties.RowNames(series) = indicat;
% Rename year columns
WDItable.Properties.VariableNames([1:end]) = string([1960:2019]);
% Remove years (columns) that contain missing values
WDItable = rmmissing(WDItable,2);
% Check initial and final years
firstyear = str2double(WDItable.Properties.VariableNames(1));
lastyear = str2double(WDItable.Properties.VariableNames(end));
% Option: further restrict sample years?
restrict = 0;          % if = 1: restrict sample years
if restrict == 1
    % Define sample initial and final years
    firstyear = 1975;  
    lastyear = 2018;
    % Restrict data to sample years
    WDItable = WDItable(:,string((firstyear:lastyear)));
end
% Compute trade balance and add it to the table
WDItable{'TB',:} = WDItable{'EXP',:} - WDItable{'IMP',:};
% Curreny account balance is given as % of GDP: get CAB as constant LCU
WDItable{'CAB',:} = WDItable{'CAB_GDP',:}.*WDItable{'GDP',:}/100;

%% Transform variables
% Per capita terms
% Indicators to be defined in per capita terms
PERCAP = {'GDP', 'CONS', 'INV', 'GOV', 'EXP', 'IMP', 'CAB', 'TB'};
% Names to be assigned to per capita variables (lowecase letters)
percap = lower(PERCAP); 
% Calculate per capita variables and append them to the table
WDItable{percap,:} = WDItable{PERCAP,:}./WDItable{'POP',:};

% "to-gdp-ratio" variables
% Indicators to be defined in "to-gdp-ratio" 
gdpratio = {'gov', 'cab', 'tb'};
% Names to be assigned to "to-gdp-ratio" variables (*_gdp)
gdprationames = strcat(gdpratio, {'_'}, 'gdp');
% Calculate "to-gdp-ratio" variables and append them to the table
WDItable{gdprationames,:} = WDItable{gdpratio,:}./WDItable{'gdp',:};

% Log transformation
% Indicators to be defined in natural log
logindicat = {'gdp','cons','inv','gov','exp','imp'};
% Names to be assigned to log variables (log_*}
lognames = strcat('log', {'_'}, logindicat);
% Calculate log variables and append them to the table
WDItable{lognames,:} = log(WDItable{logindicat,:});

% Scaling by trend GDP per capita
%{ 
Indicators cab and tb have negative values: not possible to take log
Therefore, they are first divided by the trend GDP per capita 
so that later then can be quadratically detrended
%}
% Calculate trend of GDP per capita
detrend_gdp = detrend(WDItable{'gdp',:},2);
trend_gdp = WDItable{'gdp',:} - detrend_gdp;
% Scale cab and tb by secular component of GDP per capita and add to table
WDItable{{'tb_scaled','cab_scaled'},:} = WDItable{{'tb','cab'},:}./trend_gdp;

%% Quadratic detrending
% Indicators to be detrended
detrendvars = [lognames, 'cab_scaled', 'tb_scaled', gdprationames];
% Detrend variables
WDIcycles = rowfun(@(varargin)detrend([varargin{:}],2), WDItable(detrendvars,:));
WDIcycles = splitvars(WDIcycles);

%% Compute and store summary statistics for each of the detrended variables
% Compute standard deviations and multiply them by 100;
storestats = rowfun(@(varargin)std([varargin{:}]), WDIcycles, 'OutputVariableNames', 'stddev');
storestats{:,'stddev'} = storestats{:,'stddev'}*100;
% Compute standard deviations relative to std of log GDP per capita
storestats{:,'stddev_rel'} = storestats{:,'stddev'}./storestats{'log_gdp','stddev'};
% Initialize matrices of correlation with GDP per capita and serial correlations (AR1)
nvars = length(detrendvars);
mat_corr = cell(1,nvars);
mat_serialcorr = cell(1,nvars);
mat_corr(:,:) = {zeros(2,2)};           % 2x2 matrices
mat_seriacorr(:,:) = {zeros(2,2)};      % 2x2 matrices
% Compute correlations and store values
for var = 1:nvars
    mat_corr{var} = corrcoef(WDIcycles{var,:}, WDIcycles{'log_gdp',:});
    mat_serialcorr{var} = corrcoef(WDIcycles{var,1:end-1}, WDIcycles{var,2:end});
    storestats{var,'corr_gdp'} = mat_corr{:,var}(1,2);
    storestats{var,'serial_corr'} = mat_serialcorr{:,var}(1,2);
end

%% Export summary statistics table to LaTeX
% Round numbers
storestats = varfun(@(var) round(var, 2), storestats);
% Rename statistics
storestats.Properties.VariableNames = {'Standard Deviation', ...
    'Relative Standard Deviation', 'Correlation with y', ...
    'Serial Correlation'};
% Rename indicators
storestats.Properties.RowNames = {'y', 'c', 'i', 'g', 'x', 'm', ...
    'ca', 'tb', 'g/y', 'ca/y', 'tb/y'};
% Export table to LaTeX - function "table2latex.m" needed in current folder
table2latex(storestats, 'WDIstats');
% Display final table
storestats

%% Plots of trend and cycle of log GDP per capita 
% Calculate trend of log GDP per capita
cycle_log_gdp = detrend(WDItable{'log_gdp',:},2);
trend_log_gdp = WDItable{'log_gdp',:} - cycle_log_gdp;
% Plot log GDP per capita and its trend and cycle
tiledlayout(2,1)
nexttile
plot(firstyear:lastyear, WDItable{'log_gdp',:}, 'k', 'LineWidth', 2)
hold on
plot(firstyear:lastyear, trend_log_gdp,'--k', 'LineWidth', 2)
legend('y_t','y_t^s', 'Location', 'northwest')
xlabel('Year');
nexttile
plot(firstyear:lastyear, cycle_log_gdp*100,'k', 'LineWidth', 2)
legend('y_t^c', 'Location', 'northwest')
xlabel('Year')
ylabel('Percent deviation from trend')
print('trendcycle','-dpng','-r900')


