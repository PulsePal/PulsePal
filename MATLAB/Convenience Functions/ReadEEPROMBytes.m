function Data = ReadEEPROMBytes(RawStartAddress, nBytes)
% This function reads bytes from Pulse Pal's EEPROM chip.
global PulsePalSystem;

fwrite(PulsePalSystem.SerialPort, [char(85) char(RawStartAddress) char(nBytes)]);

Data = fread(PulsePalSystem.SerialPort, nBytes);