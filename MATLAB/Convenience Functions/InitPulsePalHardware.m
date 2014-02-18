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

function InitPulsePalHardware

global PulsePalSystem
ClosePreviousPulsePalInstances;
disp('Searching for Pulse Pal. Please wait.')

% Make list of all ports
if ispc
    Ports = FindLeafLabsPorts;
else
    [trash, RawSerialPortList] = system('ls /dev/tty.*');
    Ports = ParseCOMString_UNIX(RawSerialPortList);
end
if isempty(Ports)
    try
        fclose(instrfind)
    catch
        error('Could not find a valid Pulse Pal.');
    end
    clear instrfind
end

% Make it search on the last successful port first
LastPortPath = fullfile(PulsePalSystem.PulsePalPath, 'LastCOMPort.mat');
if (exist(LastPortPath) == 2)
    load(LastPortPath);
    pos = strmatch(LastComPortUsed, Ports, 'exact'); 
    if ~isempty(pos)
        Temp = Ports;
        Ports{1} = LastComPortUsed;
        Ports(2:length(Temp)) = Temp(find(1:length(Temp) ~= pos));
    end
end

if isempty(Ports)
    error('Could not find a valid Pulse Pal.');
end
if isempty(Ports{1})
    error('Could not find a valid Pulse Pal.');
end

Found = 0;
x = 0;
while (Found == 0) && (x < length(Ports))
    x = x + 1;
    disp(['Trying port ' Ports{x}])
    TestSer = serial(Ports{x}, 'BaudRate', 115200, 'Timeout', 1,'OutputBufferSize', 8000, 'InputBufferSize', 8000, 'DataTerminalReady', 'off', 'tag', 'PulsePal');
    AvailablePort = 1;
    try
        fopen(TestSer);
    catch
        AvailablePort = 0;
    end
    if AvailablePort == 1
        pause(.5);
        fwrite(TestSer, char(72));
        tic
        while TestSer.BytesAvailable == 0
            fwrite(TestSer, char(72));
            if toc > 1
                break
            end
        end
        g = 0;
        try
            g = fread(TestSer, 1);
        catch
            % ok
        end
        if g == 75
            Found = x;
        end
        fclose(TestSer);
        delete(TestSer)
    end
    clear TestSer
end
if Found ~= 0
    PulsePalSystem.SerialPort = serial(Ports{Found}, 'BaudRate', 115200, 'Timeout', 1, 'OutputBufferSize', 8000, 'InputBufferSize', 8000, 'DataTerminalReady', 'off', 'tag', 'PulsePal');
else
    error('Error: could not find your Pulse Pal device. Please make sure it is connected and drivers are installed.');
end
fopen(PulsePalSystem.SerialPort);
pause(.1);
tic
while PulsePalSystem.SerialPort.BytesAvailable == 0
        fwrite(PulsePalSystem.SerialPort, char(72));
        pause(.1);
        if toc > 1
            break;
        end
end
HandShakeOkByte = fread(PulsePalSystem.SerialPort, 1);
if HandShakeOkByte == 75
    PulsePalSystem.FirmwareVersion = fread(PulsePalSystem.SerialPort, 1, 'uint32');
    switch PulsePalSystem.FirmwareVersion
        case 2
            PulsePalSystem.CycleDuration = 100; % Loops every 100us
        case 3
            PulsePalSystem.CycleDuration = 100; % Loops every 100us
        case 4
            PulsePalSystem.CycleDuration = 100; % Loops every 100us
    end
else
    disp('Error: Pulse Pal returned an incorrect handshake signature.')
end
LastComPortUsed = Ports{Found};
save(LastPortPath, 'LastComPortUsed');
SendClientIDString('MATLAB');
disp(['Pulse Pal connected on port ' Ports{Found}])