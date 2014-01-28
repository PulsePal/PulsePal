function PulsePalDigitalWrite(MaplePin, LogicLevel)
% Writes logic 0 or 1 to an i/o pin on Maple. Pin will be automatically configured for output.
global PulsePalSystem;
if (MaplePin < 1) || (MaplePin > 45)
    error('Error: Invalid Maple pin.')
end
if ~((LogicLevel == 1) || (LogicLevel == 0))
    error('Error: Logic level must be 0 or 1')
end
fwrite(PulsePalSystem.SerialPort, [86 MaplePin LogicLevel], 'uint8');

