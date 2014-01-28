function ConfirmByte = SetPulsePalVoltage(ChannelID, Voltage)
global PulsePalSystem
Voltage = Voltage + 10;
Voltage = Voltage / 20;
VoltageOutput = uint8(Voltage*255);
ChannelID = ChannelID - 1;
fwrite(PulsePalSystem.SerialPort, [char(79) char(ChannelID) char(VoltageOutput)]);
ConfirmByte = fread(PulsePalSystem.SerialPort,1);