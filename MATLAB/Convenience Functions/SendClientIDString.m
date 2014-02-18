function SendClientIDString(String)
global PulsePalSystem
if length(String) ~= 6
    error('Error: The client ID string must be 6 characters in length')
end
fwrite(PulsePalSystem.SerialPort,[89 String], 'uint8');