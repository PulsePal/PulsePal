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

function Ports = ParseCOMString_LINUX(string)
string = strtrim(string);
PortStringPositions = strfind(string, '/dev');
nPorts = length(PortStringPositions);
CandidatePorts = cell(1,nPorts);
nGoodPorts = 0;
for x = 1:nPorts
    if PortStringPositions(x)+11 < length(string)
        CandidatePort = string(PortStringPositions(x):PortStringPositions(x)+11);
        if sum(uint8(CandidatePort)>32) == 12
            nGoodPorts = nGoodPorts + 1;
            CandidatePorts{nGoodPorts} = CandidatePort;
        end
    end
end
Ports = CandidatePorts(1:nGoodPorts);