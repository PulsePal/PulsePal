// PulsePalTest.cpp 
// Test-program that calls updated Pulse Pal API functions
// Josh Sanders, January 30 2013

#include "stdafx.h"
#include "PulsePal.h"
#include <vector>

int _tmain(int argc, _TCHAR* argv[])
{
	PulsePal PulsePalObject;
	PulsePalObject.initialize();

	// Get handshake byte and return firmware version
	uint32_t FV = PulsePalObject.getFirmwareVersion(); 
	std::cout << "Current firmware version:" << std::endl;
	std::cout << FV << std::endl;

	// Set parameters for channels 1 and 3
	PulsePalObject.setPhase1Voltage(1, 5); PulsePalObject.setPhase1Voltage(2, 5); // Set voltage to 5V on output channels 1 and 2
	PulsePalObject.setPhase1Duration(1, .001); PulsePalObject.setPhase1Duration(2, .001); // Set duration to 1ms
	PulsePalObject.setInterPulseInterval(1, .1); PulsePalObject.setInterPulseInterval(2, .1); // Set interval to 100ms
	PulsePalObject.setPulseTrainDuration(1, 5); PulsePalObject.setPulseTrainDuration(2, 5); // Set train duration to 5s

	// Examples of software-triggering
	//PulsePalObject.triggerChannel(1); PulsePalObject.triggerChannel(3); // Previous channel-wise trigger function
	PulsePalObject.triggerChannels(1, 1, 0, 0); // Function allowing simultaneous triggering. Arguments are 1 (stimulate) or 0 (not) for channels 1, 2, 3, 4.
	Sleep(1000);
	PulsePalObject.abortPulseTrains(); // Aborts the 5-second pulse trains after 1 second.

	// Accessory functions
	PulsePalObject.setFixedVoltage(3, 10); // Sets the voltage on output channel 3 to 10V
	PulsePalObject.updateDisplay("Press", "Return. . ."); // Write text strings to screen

	// Example of programming a custom pulse train on output channel 2
	float customVoltages[4] = { 10, 2.5, -2.5, -10 };
	float customPulseTimes[4] = { 0, 0.001, 0.002, 0.005};
	uint8_t nPulses = 4;
	PulsePalObject.programCustomTrain(1, nPulses, customPulseTimes, customVoltages); // Program custom pulse train 1
	PulsePalObject.setCustomTrainID(2, 1); // Set output channel 2 to use custom train 1
	PulsePalObject.setCustomTrainLoop(2, 0); // Set output channel 2 to loop its custom pulse train until pulseTrainDuration seconds.
	PulsePalObject.setPulseTrainDuration(2, 2); // Set output channel 2 to play (the loop) for 2 seconds

	// Set output channel 1 to play synchronized pulses (for easy o-scope triggering - pulses aligned to train onsets on Ch2)
	float customVoltages2[2] = { 5, 5 };
	float customPulseTimes2[2] = { 0, 0.005 };
	nPulses = 2;
	PulsePalObject.programCustomTrain(2, nPulses, customPulseTimes2, customVoltages2);
	PulsePalObject.setCustomTrainID(1, 2); // Set output channel 1 to use custom train 2
	PulsePalObject.setCustomTrainLoop(1, 1); // Also loop this one
	PulsePalObject.setPulseTrainDuration(1, 2);

	// An alternate method for programming, using the Pulse Pal object's parameter fields (sends all parameters to Pulse Pal at once)
	PulsePalObject.currentOutputParams[1].phase1Voltage = 5; // set output channel 1 phase voltage to 5V
	PulsePalObject.currentOutputParams[3].phase1Duration = .001; // set output channel 3 phase duration to 1ms
	PulsePalObject.currentOutputParams[1].interPulseInterval = .2; // set output channel 1 pulse interval to 200ms
	PulsePalObject.currentOutputParams[1].pulseTrainDuration = 2; // set output channel 1 train to 2 sec
	PulsePalObject.programAllParams();

	// Set hardware-trigger link (trigger channels to output channels)
	PulsePalObject.setTrigger1Link(1, 1); // Link output channel 1 to trigger channel 1
	PulsePalObject.setTrigger1Link(2, 1); // Link output channel 2 to trigger channel 1
	PulsePalObject.setTrigger1Link(3, 0); // Un-Link output channel 3 to trigger channel 1
	PulsePalObject.setTrigger2Link(4, 0); // Un-link output channel 4 from trigger channel 2

	// Set hardware-trigger mode
	PulsePalObject.setTriggerMode(1, 0); // Set trigger channel 1 to normal mode
	PulsePalObject.setTriggerMode(1, 1); // Set trigger channel 1 to ttl-toggle mode
	PulsePalObject.setTriggerMode(2, 2); // Set trigger channel 2 to pulse-gated mode

	
	cin.get();
	return 0;
}

