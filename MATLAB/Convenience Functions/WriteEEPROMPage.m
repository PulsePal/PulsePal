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