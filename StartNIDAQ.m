function StartNIDAQ
% This function setup NI-DAQ cards wiring, and fundamental tasks
% Terminal Definition is in SetupD

%% import NI DAQmx class
import dabs.ni.daqmx.*

%% import handles and data
global Xin
NI = Xin.D.Sys.NIDAQ;

%% System
    try
        Xin.HW.NI.hSys = System(); 
        %if it doesn't work, you'll need to add ScanImage to the path   
    catch
        addpath('E:\FreiwaldSync\MarmoScope\ScanImage')
    end
%% Device and Reset
    for i = 1:length(NI.Dev_Names) 
        Xin.HW.NI.hDev{i} = Device(NI.Dev_Names{i});
        Xin.HW.NI.hDev{i}.reset();
    end
    
%% Device Timing Output Routing    
    C = NI.Config; 
%     Xin.HW.NI.hSys.connectTerms(...
%         ['/', C.deviceNames, '/',  C.OutTimebaseSourceLine],...
%         ['/', C.deviceNames, '/',  C.OutTimebaseBridgeLine]);
%     % This connection cannot be at the beginning, otherwise PCIe-6323 
%     % cannot get a configurable pathway for everything

    Xin.HW.NI.hSys.connectTerms(...
        ['/', C.deviceNames, '/',  C.OutStartSourceLine],...
        ['/', C.deviceNames, '/',  C.OutStartBridgeLine]); 
    
%% Analog Input    
% AI_Xin for Power Meter Monitor Input
    T = NI.Task_AI_Xin;
    Xin.HW.NI.T.hTask_AI_Xin = Task(T.taskName);
    Xin.HW.NI.T.hTask_AI_Xin.createAIVoltageChan(...
        T.chan(1).deviceNames,              T.chan(1).chanIDs,...
        T.chan(1).chanNames,                T.chan(1).minVal,...
        T.chan(1).maxVal,                   T.chan(1).units);   
 	Xin.HW.NI.T.hTask_AI_Xin.set(...
        'sampClkTimebaseRate',              T.base.sampClkTimebaseRate,...
        'sampClkTimebaseSrc',               T.base.sampClkTimebaseSrc);     
    Xin.HW.NI.T.hTask_AI_Xin.cfgSampClkTiming(...
        T.time.rate,                        T.time.sampleMode,...
        T.time.sampsPerChanToAcquire);
    Xin.HW.NI.T.hTask_AI_Xin.cfgDigEdgeStartTrig(...
        T.trigger.triggerSource,        	T.trigger.triggerEdge);
    if Xin.D.Sys.Light.Monitoring == 'F'
        Xin.HW.NI.T.hTask_AI_Xin.registerEveryNSamplesEvent(...
        T.everyN.callbackFunc,              T.everyN.everyNSamples,...
        T.everyN.readDataEnable,            T.everyN.readDataTypeOption);
    end
    Xin.HW.NI.T.hTask_AI_Xin.start();      
    
%% Analog Output
% AO_Xin for Sound Output
    T = NI.Task_AO_Xin;
   	Xin.HW.NI.T.hTask_AO_Xin = Task(T.taskName);
   	Xin.HW.NI.T.hTask_AO_Xin.createAOVoltageChan(...
        T.chan(1).deviceNames,              T.chan(1).chanIDs,...
        T.chan(1).chanNames,                T.chan(1).minVal,...
        T.chan(1).maxVal,                   T.chan(1).units);   
%     Xin.HW.NI.T.hTask_AO_Xin.createAOVoltageChan(...
%         T.chan(2).deviceNames,              T.chan(2).chanIDs,...
%         T.chan(2).chanNames,                T.chan(2).minVal,...
%         T.chan(2).maxVal,                   T.chan(2).units);   
%     
    
 	Xin.HW.NI.T.hTask_AO_Xin.set(...
        'sampClkTimebaseRate',              T.base.sampClkTimebaseRate,...
        'sampClkTimebaseSrc',               T.base.sampClkTimebaseSrc);      
    Xin.HW.NI.T.hTask_AO_Xin.cfgSampClkTiming(...
        T.time.rate,                        T.time.sampleMode,...
        T.time.sampsPerChanToAcquire);
        % the varargin:  '10MHzRefClock',    'DAQmx_Val_Rising'); does not
        % work and cannot replace the task.set('sampClkTimebaseRate'...
    Xin.HW.NI.T.hTask_AO_Xin.cfgDigEdgeStartTrig(...
        T.trigger.triggerSource,            T.trigger.triggerEdge);
%     Xin.HW.NI.T.hTask_AO_Xin.registerEveryNSamplesEvent(...
%         T.everyN.callbackFunc,              T.everyN.everyNSamples);
%     % This commend is just for demo, no real use for Xintrinsic
    Xin.HW.NI.T.hTask_AO_Xin.writeAnalogData(...
        T.write.writeData);
    Xin.HW.NI.T.hTask_AO_Xin.start();
    
    
    
    T = NI.Task_AO_Xin;
   	Xin.HW.NI.T.hTask_DO_Xin = Task('Juice Task');
    Xin.HW.NI.T.hTask_DO_Xin.createDOChan(  ...
            'Dev1',  ...
            'port0/line0',  ...
            'Juice');
    Xin.HW.NI.T.hTask_DO_Xin.set(...
        'sampClkTimebaseRate',              T.base.sampClkTimebaseRate,...
        'sampClkTimebaseSrc',               T.base.sampClkTimebaseSrc);      
    
    Xin.HW.NI.T.hTask_DO_Xin.cfgSampClkTiming(...
        T.time.rate,                        T.time.sampleMode,...
        T.time.sampsPerChanToAcquire);
    Xin.HW.NI.T.hTask_DO_Xin.cfgDigEdgeStartTrig(...
        T.trigger.triggerSource,            T.trigger.triggerEdge);

    
    %Create Digital vector with 200ms high pulses for TTL activation of syringe pump
    samples_sound = 4*length(T.write.writeData);
    T.write.writeData_Juice_TTL = zeros(samples_sound,1);
    
    samples_with_rewards = 0;
    more_reward = 1;
    samples_TTL_high = T.time.rate / 5 ; %200 ms
    while more_reward 
        this_reward = round((rand * 6 + 1)*T.time.rate); 
        samples_with_rewards = samples_with_rewards + this_reward;
        
        if samples_with_rewards + samples_TTL_high < samples_sound
            T.write.writeData_Juice_TTL( samples_with_rewards : samples_with_rewards + samples_TTL_high) = 1;
        else
            more_reward = 0;
        end
        
    end
    
    %figure; plot(T.write.writeData_Juice_TTL);
    
    Xin.HW.NI.T.hTask_DO_Xin.writeDigitalData(...
        T.write.writeData_Juice_TTL); % writeDataDigitalauto-starts the task 
    
    %Xin.HW.NI.T.hTask_DO_Xin.start(); % writeDataDigitalauto-starts the task


%% Counter Output Triggers
% Start Trigger (The start trrigger for everything else)
    T = NI.Task_CO_TrigStart;
    Xin.HW.NI.T.hTask_CO_TrigStart = Task(T.taskName);
    Xin.HW.NI.T.hTask_CO_TrigStart.createCOPulseChanTicks(...
        T.chan(1).deviceNames,              T.chan(1).chanIDs,...
        T.chan(1).chanNames,                T.chan(1).sourceTerminal,...
        T.chan(1).lowTicks,                 T.chan(1).highTicks,...
        T.chan(1).initialDelay,             T.chan(1).idleState);
    Xin.HW.NI.T.hTask_CO_TrigStart.cfgImplicitTiming(...
        T.time.sampleMode,                  T.time.sampsPerChanToAcquire);
%     Xin.HW.NI.T.hTask_CO_TrigStart.registerDoneEvent(...
%         T.done.callbackFunc);
        % The current done event callback is efficient to initialize
        % anything necessary for the first trial
    
% Frame Trigger (For controlling the main imaging camera)
    T = NI.Task_CO_TrigFrame;
    Xin.HW.NI.T.hTask_CO_TrigFrame = Task(T.taskName);
    Xin.HW.NI.T.hTask_CO_TrigFrame.createCOPulseChanTicks(...
        T.chan(1).deviceNames,              T.chan(1).chanIDs,...
        T.chan(1).chanNames,                T.chan(1).sourceTerminal,...
        T.chan(1).lowTicks,                 T.chan(1).highTicks,...
        T.chan(1).initialDelay,             T.chan(1).idleState);  
    Xin.HW.NI.T.hTask_CO_TrigFrame.createCOPulseChanTicks(...
        T.chan(2).deviceNames,              T.chan(2).chanIDs,...
        T.chan(2).chanNames,                T.chan(2).sourceTerminal,...
        T.chan(2).lowTicks,                 T.chan(2).highTicks,...
        T.chan(2).initialDelay,             T.chan(2).idleState);  
    Xin.HW.NI.T.hTask_CO_TrigFrame.cfgImplicitTiming(...
        T.time.sampleMode,                  T.time.sampsPerChanToAcquire);
    Xin.HW.NI.T.hTask_CO_TrigFrame.cfgDigEdgeStartTrig(...
        T.trigger.triggerSource,            T.trigger.triggerEdge);
    Xin.HW.NI.T.hTask_CO_TrigFrame.start();
 
%% Count Down   
    uiwait( warndlg([	'About to start imaging recording, ',...
                        'start the slave matlab code now if needed'])   );
    hWaitbar =      waitbar(0, 'The recording will be triggered'); 
    tWait =         3;
    tStart =        tic;
    tNow =          toc(tStart);
    while tNow < tWait
        tNow =          toc(tStart);
        waitbar(tNow/tWait, hWaitbar,...
            ['The recording will be triggered in ',...
            sprintf('%d seconds', ceil(tWait-tNow))] );    
        pause(0.2)
    end
    delete(hWaitbar);
    
%% Device Timing Output Routing
    % Export Timebase to bridge
%     Xin.HW.NI.hSys.connectTerms(...
%         ['/', C.deviceNames, '/',  C.OutTimebaseSourceLine],...
%         ['/', C.deviceNames, '/',  C.OutTimebaseBridgeLine]); 
    % This connection has to be at the last, otherwise PCIe-6323 cannot get
    % a configurable pathway for everything
%% Start everything by the trigger
    Xin.HW.NI.T.hTask_CO_TrigStart.start();
    
%% LOG MSG
msg = [datestr(now, 'yy/mm/dd HH:MM:SS.FFF') '\tStartNIDAQ\tNI-DAQmx tasks initialized & triggered \r\n'];
updateMsg(Xin.D.Exp.hLog, msg);
