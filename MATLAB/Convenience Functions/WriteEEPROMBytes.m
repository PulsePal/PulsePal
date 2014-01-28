function Confirm = WriteEEPROMBytes(StartAddress, Data)
% This function writes raw bytes to Pulse Pal's EEPROM chip.
% The bytes are organized in 32-byte "pages" that can be
% written in a single write operation. Be sure not to overwrite a page
% boundary!
global PulsePalSystem;

if length(Data) > 32
    Data = Data(1:32);
    disp('Warning: Data truncated to 32 byte page')
end

% Check to make sure data won't over-write a page boundary based on length,
% address and page-size=32

DataLength = length(Data);
fwrite(PulsePalSystem.SerialPort, [char(84) char(StartAddress) char(DataLength) uint8(Data)]);
Confirm = fread(PulsePalSystem.SerialPort, 1);