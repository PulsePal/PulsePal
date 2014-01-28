function PulsePalErrorMsg(Message)
ErrorSound = wavread('PulsePalError.wav');
try
sound(ErrorSound, 44100);
catch
end
msgbox(Message, 'Modal');