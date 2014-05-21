%{
----------------------------------------------------------------------------

This file is part of the PulsePal Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

global PulsePalSystem;
PulsePalDisplay('   MATLAB Link', '   Terminated.')
pause(1);
if PulsePalSystem.SerialPort.BytesAvailable > 0
    fread(PulsePalSystem.SerialPort, PulsePalSystem.SerialPort.BytesAvailable);
end
fwrite(PulsePalSystem.SerialPort, [PulsePalSystem.OpMenuByte 81], 'uint8');
fclose(PulsePalSystem.SerialPort);
delete(PulsePalSystem.SerialPort);
PulsePalSystem.SerialPort = [];
clear PulsePalSystem
disp('Pulse Pal successfully disconnected.')