global PulsePalSystem;
PulsePalDisplay('   MATLAB Link', '   Terminated.')
pause(1);
if PulsePalSystem.SerialPort.BytesAvailable > 0
    fread(PulsePalSystem.SerialPort, PulsePalSystem.SerialPort.BytesAvailable);
end
fwrite(PulsePalSystem.SerialPort, char(81));
fclose(PulsePalSystem.SerialPort);
delete(PulsePalSystem.SerialPort);
PulsePalSystem.SerialPort = [];
clear PulsePalSystem
disp('Pulse Pal successfully disconnected.')