function Output = IsTimeSequence(Input)
% Determines whether all numbers increase in time
Output = 1;
for x = 2:length(Input)
    if Input(x) < Input(x-1)
        Output = 0;
    end
end