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
function PulsePal(varargin)

if nargin == 1
    TargetPort = varargin{1};
end
ClosePreviousPulsePalInstances;

try
    evalin('base', 'PulsePalSystem;');
    disp('Pulse Pal is already open.');
catch
    warning off
    global PulsePalSystem;
    if ~verLessThan('matlab', '7.6.0')
        evalin('base','global PulsePalSystem;');
        evalin('base','PulsePalSystem = PulsePalObject;');
    else
        PulsePalSystem = struct;
        PulsePalSystem.GUIHandles = struct;
        PulsePalSystem.Graphics = struct;
        PulsePalSystem.LastProgramSent = [];
        PulsePalSystem.PulsePalPath = [];
        PulsePalSystem.SerialPort = [];
        PulsePalSystem.PulsePalPath = which('PulsePal');
        PulsePalSystem.PulsePalPath = PulsePalSystem.PulsePalPath(1:(length(PulsePalSystem.PulsePalPath)-10));
        PulsePalSystem.OS = system_dependent('getos');
    end
end

try
    if nargin == 1
        InitPulsePalHardware(TargetPort);
    else
        InitPulsePalHardware;
    end
catch
    evalin('base','delete(PulsePalSystem)')
    evalin('base','clear PulsePalSystem') 
    rethrow(lasterror)
    msgbox('Error: Unable to connect to Pulse Pal.', 'Modal')
    
end
