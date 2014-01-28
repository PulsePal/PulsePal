function TriggerPulsePal(BinaryChannelIDsString)
global PulsePalSystem;


if ~isstr(BinaryChannelIDsString)
    error('Error: Format the channels to trigger as a string of 1s and 0s')
end

try    
TriggerAddress = bin2dec(BinaryChannelIDsString);
catch
    error('Error: Format the channels to trigger as a string of 1s and 0s')
end

if TriggerAddress > 15
     error('Error: There are only four output channels.')
end
TriggerAddress = uint8(TriggerAddress);
fwrite(PulsePalSystem.SerialPort, [char(77) char(TriggerAddress)]);