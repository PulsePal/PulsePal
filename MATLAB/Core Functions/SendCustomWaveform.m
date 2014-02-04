function ConfirmBit = SendCustomWaveform(TrainID, SamplingPeriod, Voltages)

% Sampling period in microseconds, defines how long each voltage will be displayed in the series.
% Voltages in volts, for each sample. The length of Voltages determines the number of samples in the waveform.

% NOTE: Be sure to adjust the pulse duration on any channels using this train to match the SamplingPeriod argument!
global PulsePalSystem;
OriginalSamplingPeriod = SamplingPeriod;
SamplingPeriod = SamplingPeriod*1000000;

if rem(SamplingPeriod, PulsePalSystem.CycleDuration) > 0
    error(['Error: sampling period must be a multiple of ' num2str(PulsePalSystem.CycleDuration) ' microseconds'])
end
Timestamps = 0:SamplingPeriod:((length(Voltages)*SamplingPeriod)-1);

nStamps = length(Timestamps);

if nStamps > 1000
    error('Error: Pulse Pal r0.4 can only hold 1000 timestamps per stimulus train.');
end

if TrainID == 1
    fwrite(PulsePalSystem.SerialPort, char(75));
elseif TrainID == 2
    fwrite(PulsePalSystem.SerialPort, char(76));
else
    error('The first argument must be the stimulus train ID (1 or 2)')
end

USBPacketLengthCorrectionByte = uint8((rem(nStamps, 16) == 0));
fwrite(PulsePalSystem.SerialPort, USBPacketLengthCorrectionByte, 'uint8');

Output = uint32(Timestamps);
Voltages = Voltages + 10;
Voltages = Voltages / 20;
VoltageOutput = uint8(Voltages*255);

if USBPacketLengthCorrectionByte == 1
    fwrite(PulsePalSystem.SerialPort, nStamps+1, 'uint32');
else
    fwrite(PulsePalSystem.SerialPort, nStamps, 'uint32');
end


% Send timestamps
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

% Change sampling period of last matrix sent on all channels that use the custom stimulus and re-send
PulsePalMatrix = PulsePalSystem.CurrentProgram;
if ~isempty(PulsePalMatrix)
    TargetChannels = find(cell2mat(PulsePalMatrix(15,2:5))' == TrainID);
    Phase1Durations = cell2mat(PulsePalMatrix(5,2:5))';
    Phase1Durations(TargetChannels) = OriginalSamplingPeriod;
    PulsePalMatrix(5,2:5) = num2cell(Phase1Durations);
    ProgramPulsePal(PulsePalMatrix);
end