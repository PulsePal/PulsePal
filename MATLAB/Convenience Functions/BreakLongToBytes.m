function [HighestByte HighByte LowByte LowestByte] = BreakLongToBytes(LongInteger)

BinaryWord = dec2bin(LongInteger);
nSpaces = 32-length(BinaryWord);
Pad = '';
if nSpaces < 32
    for x = 1:nSpaces
        Pad = [Pad '0'];
    end
    BinaryWord = [Pad BinaryWord];
end

HighestByte = BinaryWord(1:8);
HighByte = BinaryWord(9:16);
LowByte = BinaryWord(17:24);
LowestByte = BinaryWord(25:32);
HighestByte = uint8(bin2dec(HighestByte));
HighByte = uint8(bin2dec(HighByte));
LowByte = uint8(bin2dec(LowByte));
LowestByte = uint8(bin2dec(LowestByte));