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
    TestSer = serial(Ports{x}, 'BaudRate', 115200, 'Timeout', 1,'OutputBufferSize', 8000, 'InputBufferSize', 8000, 'DataTerminalReady', 'off');
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
fread(PulsePalSystem.SerialPort, 1);
LastComPortUsed = Ports{Found};
save(LastPortPath, 'LastComPortUsed');
disp(['Pulse Pal connected on port ' Ports{Found}])
clear Found g x Ports serialInfo Confirm ComPortPath LastComPortUsed PulsePalPath RegisteredPorts Temp ans  pos trash LastPortPath InList FinderPath AvailablePort
PulsePalDisplay('MATLAB Connected', ' Click for menu');