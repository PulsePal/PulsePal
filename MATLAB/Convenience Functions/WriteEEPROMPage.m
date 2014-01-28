function Confirm = WriteEEPROMPage(Data, PageNumber)
% This function is identical to WriteEEPROMBytes except that it accepts a
% page number instead of the raw memory address. 
global PulsePalSystem;

if length(Data) > 32
    Data = Data(1:32);
    disp('Warning: Data truncated to 32 byte page')
end
Address = PageNumber*31;
DataLength = length(Data);
fwrite(PulsePalSystem.SerialPort, [char(84) char(Address) char(DataLength) uint8(Data)]);
Confirm = fread(PulsePalSystem.SerialPort, 1);