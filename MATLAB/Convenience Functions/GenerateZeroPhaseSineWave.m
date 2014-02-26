function Wave = GenerateZeroPhaseSineWave(Factor, Amplitude)

Wave = sin(pi:Factor:pi*3)*Amplitude;
if length(Wave) > 1000
    error('Pulse Pal has insufficient memory to store one iteration of this wave.')
end