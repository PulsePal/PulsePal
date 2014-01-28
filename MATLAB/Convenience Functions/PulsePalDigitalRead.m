function LogicLevel = PulsePalDigitalRead(MaplePin)
% Writes logic 0 or 1 to an i/o pin on Maple. Pin will be automatically configured for output.
global PulsePalSystem;
if (MaplePin < 1) || (MaplePin > 45)
    error('Error: Invalid Maple pin.')
end
fwrite(PulsePalSystem.SerialPort, [87 MaplePin], 'uint8');
LogicLevel = fread(PulsePalSystem.SerialPort, 1);

