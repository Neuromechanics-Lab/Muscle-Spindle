function [opt_gains,terminal_cost,SSE,ybar,SSM,R_squared,exitflag,output] = spindle_findGains(gain_limits,data,flags)
% Created: 5/2013
% Modified: 11/2015, 5/2016
% Author: Kyle Blum
% Description: This function performs the fitting of kinematics/force data
% to spindle IFRs. 
% Modifications: 1) Added 2 models. The first added model is a combination
% of estimated fascicle kinematics with a tendon elasticity of 6N/mm
% (Proske and Morgan 1987). The second added model is also a combination of
% estimated fascicle kinematics, but with a highly compliant tendon (2N/mm;
% Rack and Westbury 1983). 
% 
% User-defined dependencies: 'spindle_cost.m'

%%% Set up fmincon options %%%
optimize_options = optimset('display','off','algorithm',...
    'interior-point','TolX',1e-8,'TolFun',1e-7,'MaxFunEvals',10000);  

%%% Set up parameters %%%
gains_init = gain_limits(1,:);  % Initial guess for gains
lower_bound = gain_limits(2,:); % Lower bound of gains and time delay
upper_bound = gain_limits(3,:); % Upper bound of gains and time delay



[opt_gains,test_cost,exitflag,output] = fmincon(@spindle_cost, gains_init, ...
    [], [], [], [], lower_bound, upper_bound, [], optimize_options, ...
    data,flags);

%%% Find optimal gains %%%
switch flags.model
    case 1   % Force Model
        opt_fit = kinetics(data,opt_gains,flags);
    case 2   % Kinematic Model
        opt_fit = kinematics(data,opt_gains,flags);
%     case 3   % Classic Kinematic Model
%         opt_fit = kinematics(data,opt_gains,flags);
    case 4   % Fascicle Kinematic Model
        opt_fit = kinematics(data,opt_gains,flags);
    case 5   % Fascicle Kinematic Model w/ highly compliant tendon
        opt_fit = kinematics(data,opt_gains,flags);         
    case 6   % Free regression
        opt_fit = mixedKin(data,opt_gains);
    case 3 
        opt_fit = prochazka(data,opt_gains);
end


FR_recorded = data.firing_rate;                    % Recorded firing rate
R = corrcoef(opt_fit,FR_recorded);                 % Correlation coefficients for fit
if numel(R) ==1
    R_squared = R^2;                               % Sometimes R only has 1 value...
else
    R_squared = R(2)^2;                            % R-squared for fit
end

SSE = sum((FR_recorded-opt_fit).^2);
ybar = mean(FR_recorded);
SSM = sum((FR_recorded-ybar).^2);

terminal_cost = test_cost;
