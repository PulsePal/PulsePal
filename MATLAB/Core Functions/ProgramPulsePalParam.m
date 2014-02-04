function ConfirmBit = ProgramPulsePalParam(Channel, ParamCode, ParamValue)

% Channel = Number of output channel to program (1-4)
% ParamCode = Parameter code for transmission from the following list:

% 1 = IsBiphasic (8 bit unsigned int, 0-1)
% 2 = Phase1Voltage (8 bit unsigned int, 0-255 = -10V-10V) NOTE: Use
%     voltage when calling this function. Conversion to bytes will be
%     performed.
% 3 = Phase2Voltage (8 bit unsigned int, 0-255 = -10V-10V)
% 4 = Phase1Duration (32 bit unsigned int, 50us-3600s) NOTE: Call this function with all times in seconds
% 5 = InterPhaseInterval (32 bit unsigned int, 50us-3600s)
% 6 = Phase2Duration (32 bit unsigned int, 50us-3600s)
% 7 = InterPulseInterval (32 bit unsigned int, 50us-3600s)
% 8 = BurstDuration (32 bit unsigned int, 0us-3600s)
% 9 = BurstInterval (32 bit unsigned int, 0us-3600s)
% 10 = PulseTrainDuration (32 bit unsigned int, 50us-3600s)
% 11 = PulseTrainDelay (32 bit unsigned int, 50us-3600s)
% 12 = LinkedToTriggerCH1 (8 bit unsigned int, 0-1)
% 13 = LinkedToTriggerCH2 (8 bit unsigned int, 0-1)
% 14 = CustomTrainID (8 bit unsigned int, 0-2)
% 15 = CustomTrainTarget (8 bit unsigned int, 0 = pulses, 1 = bursts)
% 16 = CustomTrainLoop (8 bit unsigned int, 0 = no, 1 = yes)
% 128 = TriggerMode (1 = normal, 2 = toggle, 3 = gated, FOR TRIGGER CHANNELS ONLY

% For the ParamCode argument, use the number of the parameter (1-16, faster) or optionally, the string
% (slower but more readable code)

% convert string param code to integer
if ischar(ParamCode)
    ParamCode = strncmpi(ParamCode, {'isbiphasic' 'phase1voltage' 'phase2voltage' 'phase1duration' 'interphaseinterval' 'phase2duration'...
        'interpulseinterval' 'burstduration' 'burstinterval' 'pulsetrainduration' 'pulsetraindelay'...
        'linkedtotriggerCH1' 'linkedtotriggerCH2' 'customtrainid' 'customtraintarget' 'customtrainloop'}, 7);
    if sum(ParamCode) == 0
        error('Error: invalid parameter code.')
    end
    ParamCode = find(ParamCode);
elseif ~((ParamCode > 0) && (ParamCode < 17))
    error('Error: invalid parameter code.')
end

% Assert that trigger channel is 1 or 2
if ParamCode >= 128
    if Channel > 2
        error('Error: Pulse Pal has only two trigger channels.')
    end
end

% Import virtual serial port object into this workspace from base
global PulsePalSystem;
OriginalValue = ParamValue;
% Determine whether data is time data
if (ParamCode < 12) && (ParamCode > 3)
    isTimeData = 1;
else
    isTimeData = 0;
end

% Extract voltages for phases 1 and 2
if (ParamCode == 2) || (ParamCode == 3)
    ParamValue = uint8(ceil(((ParamValue+10)/20)*255));
end

% Sanity-check time data
if isTimeData
    ParamValue = ParamValue*1000000;
    if rem(ParamValue, PulsePalSystem.CycleDuration) > 0
        errordlg(['Non-zero time values for Pulse Pal rev0.4 must be multiples of ' num2str(PulsePalSystem.CycleDuration) ' microseconds.'], 'Error');
    end
end

% Instruct PulsePal to recieve a new single parameter (op code 79) and specify parameter and target channel
fwrite(PulsePalSystem.SerialPort, [char(74) char(ParamCode) char(Channel)]);

% Send data
if isTimeData
    fwrite(PulsePalSystem.SerialPort, ParamValue, 'uint32');
else
    fwrite(PulsePalSystem.SerialPort, ParamValue, 'uint8');
end
ConfirmBit = fread(PulsePalSystem.SerialPort, 1);
if ConfirmBit == 1
    PulsePalSystem.CurrentProgram{ParamCode+1,Channel+1} = OriginalValue;
end


