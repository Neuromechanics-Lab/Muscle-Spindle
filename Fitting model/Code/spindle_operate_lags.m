% Author: Kyle P. Blum
% Date of last edit: June, 12 2015
%
% Description: This script will take all processed data files created by
% 'spindle_parse.m' and attempt to fit kinematics and/or force data to the
% IFRs for each afferent. It appends data structure 'fit_data' to
% 'proc_data' and saves to the same filename. 
%
% User-defined dependencies: 'spindle_findGains.m'

tic
clc
clear
close all

pathname = cd(cd(['..' filesep 'Data' filesep 'proc_data_no_buffer_lags']));
afferents = {24};%,25,26,27,32,56,57,58,60,64};

for affnum = 1:length(afferents)     % For all afferents
    aff_dir = dir(pathname);  % List items in pathname
    for b = 1:length(aff_dir)  % For all items in pathname
        folder_name = aff_dir(b).name;   % Current item name
        if strfind(folder_name,num2str(afferents{affnum}))  % If current item name contains current afferent #
            sub_dir = dir([pathname filesep folder_name]); % List files in current item
            for c = 1:length(sub_dir)             % For all files in current item
                filename = sub_dir(c).name;        % Current file
                disp(filename)
                if strfind(filename,'proc.mat')
                    loadname = [pathname filesep folder_name filesep filename];   % Use this name to load
                    load(loadname)                     % Load
                    for model = 1:6          % For all different models
                        
                        flags.model = model;
                        data.filename = filename;
                        flags.aff = afferents{affnum};
                        
                        
                         %% MODEL SETUP %%
                        switch flags.model
                            case 1 % Force, dFdt, static model

                                gain_limits(1,:) = [1,1,-65,41];                    %Initial guesses for [k_F,k_dF,Static,F_offset,dF_offset]
                                gain_limits(2,:) = [0.0,0.0,-500,-500];                   %Lower bounds for [k_F,k_dF,Static,F_offset,dF_offset]
                                gain_limits(3,:) = [20,20,1000,1000];         %Upper bounds [k_F,k_dF,Static,F_offset,dF_offset]
                                
                                
                            case 2 % Kinematic Model (dV/dt,Vel,Len)
                                gain_limits(1,:) = [1,1,1,1,1,1];                       %Initial guesses for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                gain_limits(2,:) = [0,0,0,-1000,-1000,-1000];           %Lower bounds for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                gain_limits(3,:) = [10000,10000,10000,1000,1000,1000];  %Upper bounds for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                
%                             case 3 % Classic Kinematic Model (Vel,Len)
%                                 gain_limits(1,:) = [1,1,1,1];                           %Initial guesses for [k_p,k_v,p_offset,v_offset]
%                                 gain_limits(2,:) = [0,0,-1000,-1000];                   %Lower bounds for [k_p,k_v,p_offset,v_offset]
%                                 gain_limits(3,:) = [10000,10000,1000,1000];             %Upper bounds for [k_p,k_v,p_offset,v_offset]
                            
                            case 3 % Prochazka model
                                gain_limits(1,:) = [0.5*ones(1,4)];
                                gain_limits(2,:) = [zeros(1,4)];
                                gain_limits(3,:) = [1000,1,1000,1000];
                                
                            case 4 % Fascicle Estimates Model (dVF/dt, VelF, LenF)
                                gain_limits(1,:) = [1,1,1,1,1,1];                       %Initial guesses for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                gain_limits(2,:) = [0,0,0,-1000,-1000,-1000];           %Lower bounds for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                gain_limits(3,:) = [10000,10000,10000,1000,1000,1000];  %Upper bounds for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                
                            case 5 % Fascicle Estimates Model w/ highly compliant tendon (dVF_hc/dt, VelF_hc, LenF_hc)
                                gain_limits(1,:) = [1,1,1,1,1,1];                       %Initial guesses for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                gain_limits(2,:) = [0,0,0,-1000,-1000,-1000];           %Lower bounds for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                gain_limits(3,:) = [10000,10000,10000,1000,1000,1000];  %Upper bounds for [k_p,k_v,k_a,p_offset,v_offset,a_offset]
                                
                            case 6 % Free regression with all variables
                                gain_limits(1,:) = [ones(1,25)];             %Initial guesses: [kF,kdF,kp,kv,ka,kpf,kvf,kaf,kpfhc,kpvhc,kpahc,static,F_offset,p_offset,pF_offset,pFhc_offset]
                                gain_limits(2,:) = [zeros(1,12),-1000*ones(1,12),0];       %Lower Bounds
                                gain_limits(3,:) = [1e4*ones(1,12),1e3*ones(1,12),1];    %Upper bounds
                                
                            
                                   
                        end
                        
                        %%% COST FUNCTION SETUP %%%
                        
%                         flags.weights = [1; 10]; %weights for cost function
                        
                        %%% SPIKE TIMING SETUP %%%
                        for pert=1:length(proc_data)  %make downsampled data for each perturbation
                            for lag = 1:16
                                lagtime = 0:0.001:0.015;
                                
                                data.FRtimes = proc_data(pert).spiketimes(2:end) - proc_data(pert).time(1);
                                pertStart = 0.05;
%                                 pertEnd = proc_data(pert).time(end)/2 + 0.5;
                                data.firing_rate = proc_data(pert).firing_rate;   
                               
                                %Remove buffer data
                                try
                                    data.firing_rate(data.FRtimes <= pertStart || data.FRtimes >= pertEnd) = [];
                                    data.FRtimes(data.FRtimes <= pertStart || data.FRtimes >= pertEnd) = [];
                                catch
                                    data.firing_rate(data.FRtimes <= pertStart) = [];
                                    data.FRtimes(data.FRtimes <= pertStart) = [];
                                end
                                %%% Kinematics and Kinetics Data at Spiketimes %%%
                                
                                data.time_end = proc_data(pert).time(end)-proc_data(pert).time(1);            % End time of pert relative to beginning of pert
                                
                                F = proc_data(pert).Force;
                                dF = proc_data(pert).dFdt;
                                L = proc_data(pert).Length;
                                V = proc_data(pert).Velocity;
                                dV = proc_data(pert).dVdt;
                                LF = proc_data(pert).LengthF;
                                VF = proc_data(pert).VelocityF;
                                dVF = proc_data(pert).dVFdt;
                                LF_hc = proc_data(pert).LengthF_hc;
                                VF_hc = proc_data(pert).VelocityF_hc;
                                dVF_hc = proc_data(pert).dVFdt_hc;
                                
                                 % For dynamic afferents, get rid of tiny
                                 % >0 bumps during plateau. 
                                 if afferents{affnum} == 25 || afferents{affnum} == 26 || afferents{affnum} == 58 || afferents{affnum} == 60
                                    %Need to get rid of short, >0 bumbps in dF/dt
                                    %without filtering signal
                                    posdF = [0;dF>0;0]; %index where dF>0
                                    posneg = find(diff(posdF)==-1); %Find where dF changes from positive to negative value
                                    negpos = find(diff(posdF)==1); % Find where dF changes from negative to positive value
                                    ind = posneg-negpos < 80;  % Find sections of dF > 0 that are shorter than 80 samples (40ms)
                                    posneg = posneg(ind);       % Remove sections of dF > 0 that are longer than 80 samples
                                    negpos = negpos(ind);       % "
                                    for k = 1:numel(posneg) % "
                                        dF(negpos(k):posneg(k)) = 0; % "
                                    end % "
                                    F(dF>0) = 0; %Assume dFdt dominates signal where it is nonzeros
                                 end
                                 
                                 
                                
                                try
                                    data.Length = L(round((data.FRtimes-lagtime(lag))*2000)+1);                % Length
                                    data.Velocity = V(round((data.FRtimes-lagtime(lag))*2000)+1);                            % Velocity w/o offest at times of spikes
                                    data.dVdt = dV(round((data.FRtimes-lagtime(lag))*2000)+1);                    % Accel. calculated w/ difference approximation
                                    data.LengthF = LF(round((data.FRtimes-lagtime(lag))*2000)+1);
                                    data.LengthF_hc = LF_hc(round((data.FRtimes-lagtime(lag))*2000)+1);
                                    data.VelocityF = VF(round((data.FRtimes-lagtime(lag))*2000)+1);
                                    data.VelocityF_hc = VF_hc(round((data.FRtimes-lagtime(lag))*2000)+1);
                                    data.dVFdt = dV(round((data.FRtimes-lagtime(lag))*2000)+1);
                                    data.dVFdt_hc = dV_hc(round((data.FRtimes-lagtime(lag))*2000)+1);
                                    
                                    %%% Force Data at Spiketimes %%%
                                    data.Force = F(round((data.FRtimes-lagtime(lag))*2000)+1);                  % Model 1&2 Force at times of spikes
                                    data.dFdt = dF(round((data.FRtimes-lagtime(lag))*2000)+1);                    % Filtered dFdt at times of spikes
                                catch
                                    try
                                        data.Length = L(floor((data.FRtimes-lagtime(lag))*2000)+1);                % Length
                                        data.Velocity = V(floor((data.FRtimes-lagtime(lag))*2000)+1);                            % Velocity w/o offest at times of spikes
                                        data.dVdt = dV(floor((data.FRtimes-lagtime(lag))*2000)+1);                    % Accel. calculated w/ difference approximation
                                        data.LengthF = LF(floor((data.FRtimes-lagtime(lag))*2000)+1);
                                        data.LengthF_hc = LF_hc(floor((data.FRtimes-lagtime(lag))*2000)+1);
                                        data.VelocityF = VF(floor((data.FRtimes-lagtime(lag))*2000)+1);
                                        data.VelocityF_hc = VF_hc(floor((data.FRtimes-lagtime(lag))*2000)+1);
                                        data.dVFdt = dV(floor((data.FRtimes-lagtime(lag))*2000)+1);
                                        data.dVFdt_hc = dV_hc(floor((data.FRtimes-lagtime(lag))*2000)+1);
                                        
                                        %%% Force Data at Spiketimes %%%
                                        data.Force = F(floor((data.FRtimes-lagtime(lag))*2000)+1);                  % Model 1&2 Force at times of spikes
                                        data.dFdt = dF(floor((data.FRtimes-lagtime(lag))*2000)+1);                    % Filtered dFdt at times of spikes
                                    catch
                                        try
                                            data.Length = L(ceil((data.FRtimes-lagtime(lag))*2000)+1);                % Length
                                            data.Velocity = V(ceil((data.FRtimes-lagtime(lag))*2000)+1);                            % Velocity w/o offest at times of spikes
                                            data.dVdt = dV(ceil((data.FRtimes-lagtime(lag))*2000)+1);                    % Accel. calculated w/ difference approximation
                                            data.LengthF = LF(ceil((data.FRtimes-lagtime(lag))*2000)+1);
                                            data.LengthF_hc = LF_hc(ceil((data.FRtimes-lagtime(lag))*2000)+1);
                                            data.VelocityF = VF(ceil((data.FRtimes-lagtime(lag))*2000)+1);
                                            data.VelocityF_hc = VF_hc(ceil((data.FRtimes-lagtime(lag))*2000)+1);
                                            data.dVFdt = dV(ceil((data.FRtimes-lagtime(lag))*2000)+1);
                                            data.dVFdt_hc = dVF_hc(ceil((data.FRtimes-lagtime(lag))*2000)+1);
                                            
                                            %%% Force Data at Spiketimes %%%
                                            data.Force = F(ceil((data.FRtimes-lagtime(lag))*2000)+1);                  % Model 1&2 Force at times of spikes
                                            data.dFdt = dF(ceil((data.FRtimes-lagtime(lag))*2000)+1);                    % Filtered dFdt at times of spikes
                                        catch
                                            data.Length = L(ceil((data.FRtimes-lagtime(lag))*2000));                % Length
                                            data.Velocity = V(ceil((data.FRtimes-lagtime(lag))*2000));                            % Velocity w/o offest at times of spikes
                                            data.dVdt = dV(ceil((data.FRtimes-lagtime(lag))*2000));                    % Accel. calculated w/ difference approximation
                                            data.LengthF = LF(ceil((data.FRtimes-lagtime(lag))*2000));
                                            data.LengthF_hc = LF_hc(ceil((data.FRtimes-lagtime(lag))*2000));
                                            data.VelocityF = VF(ceil((data.FRtimes-lagtime(lag))*2000));
                                            data.VelocityF_hc = VF_hc(ceil((data.FRtimes-lagtime(lag))*2000));
                                            data.dVFdt = dV(ceil((data.FRtimes-lagtime(lag))*2000));
                                            data.dVFdt_hc = dVF_hc(ceil((data.FRtimes-lagtime(lag))*2000));
                                            
                                            %%% Force Data at Spiketimes %%%
                                            data.Force = F(ceil((data.FRtimes-lagtime(lag))*2000));                  % Model 1&2 Force at times of spikes
                                            data.dFdt = dF(ceil((data.FRtimes-lagtime(lag))*2000));
                                        end
                                    end
                                end
                                

                                
                                [opt_gains(pert,lag,:),terminal_cost(pert,lag),SSE(pert,lag),ybar(pert,lag),SSM(pert,lag),R_squared(pert,lag),exitflag(pert,lag),output(pert,lag)] = spindle_findGains(gain_limits,data,flags);
                                
                                FR(pert).times = data.FRtimes;        % Times at which we have a firing rate value
                                FR(pert).values = data.firing_rate;     % Recorded firing rate
                                fit_data(flags.model).fitting_data(pert,lag) = data;               % Data used for fitting
                                
                            end
                        end
                        
                        %%% ADD TO 'fit_data' STRUCTURE (items with fixed lengths outside loop) %%%
                        fit_data(flags.model).FR = FR';                                    % Firing Rate data with values and times
                        fit_data(flags.model).opt_gains = opt_gains;                       % Optimal gains from spindle_findGains
                        fit_data(flags.model).terminal_cost = terminal_cost';              % Final cost value from spindle_findGains
                        fit_data(flags.model).SSE = SSE';                                  % Sum of squared errors from regression
                        fit_data(flags.model).ybar = ybar';                                % Mean of measured firing rate
                        fit_data(flags.model).exitflag = exitflag';                        % Exit flag from fmincon
                        fit_data(flags.model).opt_output = output';                        % information about iterations from fmincon
                        fit_data(flags.model).date = date;                                 % date code was run
                        fit_data(flags.model).R_squared = R_squared';                      % R_squared for fit
                        
                        save(loadname,'fit_data','-append')
                        
                        clear FR opt_gains terminal_cost exitflag output date R_squared gain_limits
                        
                        
                      
                    end
                    clear proc_data
                end
            end
        end
    end
end
clear
toc

