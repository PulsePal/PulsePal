function ClosePreviousPulsePalInstances
out1 = com.mathworks.toolbox.instrument.Instrument.getNonLockedObjects;
if isempty(out1)
    return;
end
for i = 0:out1.size-1
    inputObj  = out1.elementAt(i);
    className = class(inputObj);
    try
        obj = feval(char(getMATLABClassName(inputObj)), inputObj);
    catch %#ok<CTCH>
        if strcmp(className, 'com.mathworks.toolbox.instrument.SerialComm')
            obj = serial(inputObj);
        end
    end
    Props = get(obj);
    if isfield(Props, 'Tag')
        if strcmp(Props.Tag, 'PulsePal')
            fclose(obj);
            delete(obj);
        end
    end
end
