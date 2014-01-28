function ConfirmBit = SetContinuousLoop(Channel, State)

% Import virtual serial port object into this workspace from base
global PulsePalSystem;

if ischar(Channel)
    error('Error: expected channel format is an integer 1-4')
end
if (Channel > 4) || (Channel < 1)
    error('Error: expected channel format is an integer 1-4')
end
if (State == 0) || (State == 1)
    fwrite(PulsePalSystem.SerialPort, [82 (Channel-1) State], 'uint8');
else
    error('Error: Channel state must be 0 (for normal playback) or 1 (for continuous looping)')
end
ConfirmBit = fread(PulsePalSystem.SerialPort, 1);