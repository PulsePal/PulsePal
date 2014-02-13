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