function PulsePalDisplay(varargin)
global PulsePalSystem;
fwrite(PulsePalSystem.SerialPort, char(78));
if nargin == 1
    if ischar(varargin{1})
        fwrite(PulsePalSystem.SerialPort, varargin{1});
    end
elseif nargin == 2
    if ischar(varargin{1})
        fwrite(PulsePalSystem.SerialPort, [varargin{1} char(254) varargin{2}]);
    end
end