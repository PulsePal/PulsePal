function ConfirmBit = SendCustomPulseTrain(TrainID, PulseTimes, Voltages)
global PulsePalSystem

if length(PulseTimes) ~= length(Voltages)
    error('There must be one voltage value (0-255) for every timestamp');
end

nStamps = length(PulseTimes);
if nStamps > 1000
    error('Error: Pulse Pal r0.4 can only store 1000 pulses per stimulus train.');
end

if TrainID == 1
    fwrite(PulsePalSystem.SerialPort, char(75));
elseif TrainID == 2
    fwrite(PulsePalSystem.SerialPort, char(76));
else
    error('The first argument must be the stimulus train ID (1 or 2)')
end

% Sanity-check PulseTimes and voltages
CandidateTimes = PulseTimes*1000000;
CandidateVoltages = Voltages;
if (sum(CandidateTimes < 0) > 0)  
    error('Error: Custom pulse times must be positive');
end
if (length(unique(CandidateTimes)) ~= length(CandidateTimes))
    error('Error: Duplicate custom pulse times detected');
end
if ~IsTimeSequence(CandidateTimes)  
    error('Error: Custom pulse times must always increase');
end
if (sum(rem(CandidateTimes,100)) > 0)  
    error('Error: Custom pulse times must be multiples of 0.0001 seconds');
end
if (CandidateTimes(length(CandidateTimes)) > 3600000000) 
    0; error('Error: Custom pulse times must be < 3600 s');
end
if (sum(abs(CandidateVoltages) > 10) > 0) 
    error('Error: Custom voltage range = -10V to +10V');
end
if (length(CandidateVoltages) ~= length(CandidateTimes)) 
    error('Error: There must be a voltage for every timestamp');
end

Output = uint32(PulseTimes*1000000);
Voltages = Voltages + 10;
Voltages = Voltages / 20;
VoltageOutput = uint8(Voltages*255);

% This section calculates whether the transmission will result in
% attempting to send a string of a multiple of 64 bytes, which will cause
% WINXP machines to crash. If so, a byte is added to the transmission and
% removed at the other end.
if nStamps < 200
    USBPacketLengthCorrectionByte = uint8((rem(nStamps, 16) == 0));
else
    nFullPackets = ceil(length(Output)/200) - 1;
    RemainderMessageLength = nStamps - (nFullPackets*200);
    if  uint8((rem(RemainderMessageLength, 16) == 0)) || (uint8((rem(nStamps, 16) == 0)))
        USBPacketLengthCorrectionByte = 1;
    else
        USBPacketLengthCorrectionByte = 0;
    end
end
fwrite(PulsePalSystem.SerialPort, USBPacketLengthCorrectionByte, 'uint8');

if USBPacketLengthCorrectionByte == 1
    fwrite(PulsePalSystem.SerialPort, nStamps+1, 'uint32');
else
    fwrite(PulsePalSystem.SerialPort, nStamps, 'uint32');
end


% Send PulseTimes
nPackets = ceil(length(Output)/200);
Ind = 1;
if nPackets > 1
    for x = 1:nPackets-1
        fwrite(PulsePalSystem.SerialPort, Output(Ind:Ind+199), 'uint32');
        Ind = Ind + 200;
    end
    if USBPacketLengthCorrectionByte == 1
        fwrite(PulsePalSystem.SerialPort, [Output(Ind:length(Output)) 5], 'uint32');
    else
        fwrite(PulsePalSystem.SerialPort, Output(Ind:length(Output)), 'uint32');
    end
else
    if USBPacketLengthCorrectionByte == 1
        fwrite(PulsePalSystem.SerialPort, [Output 5], 'uint32');
    else
        fwrite(PulsePalSystem.SerialPort, Output, 'uint32');
    end
end

% Send voltages
if nStamps > 800
    fwrite(PulsePalSystem.SerialPort, VoltageOutput(1:800), 'uint8');
    if USBPacketLengthCorrectionByte == 1
        fwrite(PulsePalSystem.SerialPort, [VoltageOutput(801:nStamps) 5], 'uint8');
    else
        fwrite(PulsePalSystem.SerialPort, VoltageOutput(801:nStamps), 'uint8');
    end
else
    if USBPacketLengthCorrectionByte == 1
        fwrite(PulsePalSystem.SerialPort, [VoltageOutput(1:nStamps) 5]);
    else
        fwrite(PulsePalSystem.SerialPort, VoltageOutput(1:nStamps));
    end
end

ConfirmBit = fread(PulsePalSystem.SerialPort, 1);