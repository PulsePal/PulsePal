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

function PulsePalDigitalWrite(MaplePin, LogicLevel)
% Writes logic 0 or 1 to an i/o pin on Maple. Pin will be automatically configured for output.
global PulsePalSystem;
if (MaplePin < 1) || (MaplePin > 45)
    error('Error: Invalid Maple pin.')
end
if ~((LogicLevel == 1) || (LogicLevel == 0))
    error('Error: Logic level must be 0 or 1')
end
fwrite(PulsePalSystem.SerialPort, [PulsePalSystem.OpMenuByte 86 MaplePin LogicLevel], 'uint8');

