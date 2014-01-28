function AbortPulsePal
global PulsePalSystem;
fwrite(PulsePalSystem.SerialPort,  char(80));
PulsePalDisplay('   PULSE TRAIN', '     ABORTED')
pause(1);
PulsePalDisplay('MATLAB Connected', ' Click for menu');