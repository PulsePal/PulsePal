function LeafLabsPorts = FindLeafLabsPorts
[Status RawString] = system('wmic path Win32_SerialPort Where "Caption LIKE ''%Maple%''" Get DeviceID'); % Search for Maple serial USB port
PortLocations = strfind(RawString, 'COM');
LeafLabsPorts = cell(1,100);
nPorts = length(PortLocations);
for x = 1:nPorts
    Clip = RawString(PortLocations(x):PortLocations(x)+6);
    LeafLabsPorts{x} = Clip(1:find(Clip == 32,1, 'first')-1);
end
LeafLabsPorts = LeafLabsPorts(1:nPorts);