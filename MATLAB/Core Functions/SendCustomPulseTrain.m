%{
----------------------------------------------------------------------------

This file is part of the PulsePal Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

function ConfirmBit = SendCustomPulseTrain(TrainID, PulseTimes, Voltages)
global PulsePalSystem

if length(PulseTimes) ~= length(Voltages)
    error('There must be one voltage value (0-255) for every timestamp');
end

nPulses = length(PulseTimes);
if nPulses > 1000
    error('Error: Pulse Pal r0.4 can only store 1000 pulses per stimulus train.');
end

% Sanity-check PulseTimes and voltages
CandidateTimes = uint32(PulseTimes*1000000);
CandidateVoltages = Voltages;
if (sum(CandidateTimes < 0) > 0)  
    error('Error: Custom pulse times must be positive');
end
if ~IsTimeSequence(CandidateTimes)  
    error('Error: Custom pulse times must always increase');
end
if (sum(rem(CandidateTimes,1) > 0))  
    errordlg(['Non-zero time values for Pulse Pal rev0.4 must be multiples of ' num2str(PulsePalSystem.CycleDuration) ' microseconds.'], 'Error');
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
Output = uint32(PulseTimes*10000); % Convert to multiple of 100us
if (length(unique(Output)) ~= length(Output))
    error('Error: Duplicate custom pulse times detected');
end
Voltages = Voltages + 10;
Voltages = Voltages / 20;
VoltageOutput = uint8(Voltages*255);


if ~((TrainID == 1) || (TrainID == 2))
    error('The first argument must be the stimulus train ID (1 or 2)')
end

if TrainID == 1
    OpCode = 75;
else 
    OpCode = 76;
end


if strcmp(PulsePalSystem.OS, 'Microsoft Windows XP') 
    % This section calculates whether the transmission will result in
    % attempting to send a string of a multiple of 64 bytes, which will cause
    % WINXP machines to crash. If so, a byte is added to the transmission and
    % removed at the other end.
if nPulses < 200
    USBPacketLengthCorrectionByte = uint8((rem(nPulses, 16) == 0));
else
    nFullPackets = ceil(length(Output)/200) - 1;
    RemainderMessageLength = nPulses - (nFullPackets*200);
    if  uint8((rem(RemainderMessageLength, 16) == 0)) || (uint8((rem(nPulses, 16) == 0)))
        USBPacketLengthCorrectionByte = 1;
    else
        USBPacketLengthCorrectionByte = 0;
    end
end
    if USBPacketLengthCorrectionByte == 1
        nPulsesByte = uint32(nPulses+1);
    else
        nPulsesByte = uint32(nPulses);
    end
    ByteString = [OpCode USBPacketLengthCorrectionByte typecast(nPulsesByte, 'uint8')]; 
    fwrite(PulsePalSystem.SerialPort, ByteString, 'uint8');
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
    if nPulses > 800
        fwrite(PulsePalSystem.SerialPort, VoltageOutput(1:800), 'uint8');
        if USBPacketLengthCorrectionByte == 1
            fwrite(PulsePalSystem.SerialPort, [VoltageOutput(801:nPulses) 5], 'uint8');
        else
            fwrite(PulsePalSystem.SerialPort, VoltageOutput(801:nPulses), 'uint8');
        end
    else
        if USBPacketLengthCorrectionByte == 1
            fwrite(PulsePalSystem.SerialPort, [VoltageOutput(1:nPulses) 5]);
        else
            fwrite(PulsePalSystem.SerialPort, VoltageOutput(1:nPulses));
        end
    end
    
else % This is the normal transmission scheme, as a single bytestring
    nPulsesByte = uint32(nPulses);
    ByteString = [OpCode 0 typecast(nPulsesByte, 'uint8') typecast(Output, 'uint8') VoltageOutput];
    fwrite(PulsePalSystem.SerialPort, ByteString, 'uint8');
end

ConfirmBit = fread(PulsePalSystem.SerialPort, 1);