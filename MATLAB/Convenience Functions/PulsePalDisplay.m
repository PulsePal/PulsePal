function PulsePalDisplay(varargin)
global PulsePalSystem;
Message = varargin{1};
if nargin == 2
    Message = [Message char(254) varargin{2}];
end
Message = [char(78) char(length(Message)) Message];
fwrite(PulsePalSystem.SerialPort, Message);
