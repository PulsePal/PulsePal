clc
try
    evalin('base', 'PulsePalSystem;');
    disp('Pulse Pal is already open.');
catch
    warning off
    global PulsePalSystem
    if ~verLessThan('matlab', '7.6.0')
        evalin('base','PulsePalSystem = PulsePalObject;');
    else
        PulsePalSystem = struct;
        PulsePalSystem.GUIHandles = struct;
        PulsePalSystem.Graphics = struct;
        PulsePalSystem.LastProgramSent = [];
        PulsePalSystem.PulsePalPath = [];
        PulsePalSystem.SerialPort = [];
        PulsePalSystem.PulsePalPath = which('PulsePal');
        PulsePalSystem.PulsePalPath = PulsePalSystem.PulsePalPath(1:(length(PulsePalSystem.PulsePalPath)-10));
    end
end

try
    evalin('base','InitPulsePalHardware;')
catch
    evalin('base','delete(PulsePalSystem)')
    evalin('base','clear PulsePalSystem') 
    msgbox('Error: Unable to connect to Pulse Pal.', 'Modal')
end
