function words = ParseCOMString_UNIX(string)
string = strtrim(string);
string = lower(string);
nSpaces = sum(string == char(9)) + sum(string == char(10));
if nSpaces > 0
    Spaces = find((string == char(9)) + (string == char(10)));
    Pos = 1;
    words = cell(1,nSpaces);
    for x = 1:nSpaces
        words{x} = string(Pos:Spaces(x) - 1);
        Pos = Pos + length(words{x}) + 1;
    end
    words{x+1} = string(Pos:length(string));
else
    words{1} = string;
end

% Eliminate bluetooth ports
nGoodPortsFound = 0;
TempList = cell(1,1);
for x = 1:length(words)
    Portstring = words{x};
    ValidPort = 1;
    for y = 1:(length(Portstring) - 4)
        if sum(Portstring(y:y+3) == 'blue') == 4
            ValidPort = 0;
        end
    end
    if ValidPort == 1
        nGoodPortsFound = nGoodPortsFound + 1;
        TempList{nGoodPortsFound} = Portstring;
    end
end
words = TempList;