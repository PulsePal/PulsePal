// PULSE PAL v0.4 firmware 
// Josh Sanders, March 2012
#include <LiquidCrystal.h>
#include <stdio.h>
#include <gpio.h>
// Define a macro for compressing sequential bytes read from the serial port into long ints
#define makeLong(msb, byte2, byte3, lsb) ((msb << 24) | (byte2 << 16) | (byte3 << 8) | (lsb))
#define LED_PIN_PORT GPIOA
#define INPUT_PIN_PORT GPIOC
// EEPROM constants
#define PAGE_SIZE 32
#define SPI_MODE 0
#define CS 37 // chip select pin
// EEPROM opcodes
#define WREN 6
#define WRDI 4
#define RDSR 5
#define WRSR 1
#define READ 3
#define WRITE 2

// Trigger line level configuration (0 = default high, trigger low (versions with optocoupler). 1 = default low, trigger high.)
#define TriggerLevel 0

// initialize LCD library with the numbers of the interface pins
// Pins matched with hello world LCD sketch
//LiquidCrystal lcd(12, 13, 28, 29, 30, 31);
LiquidCrystal lcd(14, 20, 9, 8, 7, 6);
// Variables that define system parameters
//byte OutputLines[4] = {16,17,18,19}; // Output lines
//byte OutputLineBits[4] = {6, 5, 4, 3}; // for faster write times, "Bits" address the pins directly - low level ARM commands.
byte InputLines[2] = {15,16};
byte InputLineBits[2] = {0,1};
byte OutputLEDLines[4] = {3,2,1,0}; // Output lines
byte OutputLEDLineBits[4] = {1, 0, 2, 3 }; // for faster write times, "Bits" address the pins directly - low level ARM commands.
byte InputLEDLines[2] = {35, 36};
byte InputLEDLineBits[2] = {6,7}; 
byte ClickerXLine = 19;
byte ClickerYLine = 18;
byte ClickerButtonLine = 17;
byte ClickerButtonBit = 2;
//int ClickerButtonSupplyPin = 6;
//int HbridgeEnableLine = 12; // tie to vcc in future editions
byte LEDLine = 22;
byte DACLoadPin=4;
byte DACLatchPin=5;
byte USBPacketCorrectionByte = 0; // If messages sent over USB in Windows XP are 64 bytes, the system crashes - so this variable keeps track of whether to chop off a junk byte at the end of the message. Used for custom stimuli.
HardwareSPI spi(1);
HardwareSPI EEPROM(2);

// Variables related to EEPROM
byte PageBytes[32] = {0}; // Stores page to be written
int EEPROM_address = 0;
byte EEPROM_OutputValue = 0;
byte nBytesToWrite = 0;
byte nBytesToRead = 0;
byte BrokenBytes[4] = {0};

// Variables that define pulse trains currently loaded on the 4 output channels
unsigned long Phase1Duration[4] = {0};
unsigned long InterPhaseInterval[4] = {0};
unsigned long Phase2Duration[4] = {0};
unsigned long InterPulseInterval[4] = {0};
unsigned long BurstDuration[4] = {0};
unsigned long BurstInterval[4] = {0};
unsigned long StimulusTrainDuration[4] = {0};
unsigned long StimulusTrainDelay[4] = {0};
int FollowsCustomStimID[4] = {0}; // If 0, uses above params. If 1 or 2, triggering plays back timestamps in CustomTrain1 or CustomTrain2 with pulsewidth defined as usual
int CustomStimTarget[4] = {0}; // If 0, custom stim timestamps are start-times of pulses. If 1, custom stim timestamps are start-times of bursts.
int CustomStimLoop[4] = {0}; // if 0, custom stim plays once. If 1, custom stim loops until StimulusTrainDuration.
int ConnectedToApp = 0; // 0 for none, 1 for MATLAB client, 2 for Labview client, 3 for Python client

// Variables used in programming
int TriggerAddress[2] = {0}; // This specifies in binary, which channels get triggered by inputs 1 and 2.
int TriggerMode[2] = {0}; // if 0, "Normal mode", triggers on low to high transitions and ignores triggers until end of stimulus train. if 1, "Toggle mode", triggers on low to high and shuts off stimulus
//train on next high to low. If 2, "Button mode", triggers on low to high and shuts off on high to low.
int ReTriggerMode[2] = {0}; // 0=default. If 1, if an input line is still high when the pulse train ends, the pulse train is re-triggered.
unsigned long TriggerButtonDebounce[2] = {0}; // In button mode, number of microseconds the line must be low before stopping the pulse train.
int CustomStimTimestampIndex[4] = {0}; // Keeps track of the pulse number being played in custom stim condition
unsigned long CustomStimNpulses[2] = {0}; // Number of pulses in the stimulus
byte Phase1Voltage[4] = {0};
byte Phase2Voltage[4] = {0};
int ClickerX = 0; // Value of analog reads from X line of joystick input device
int ClickerY = 0; // Value of analog reads from Y line of joystick input device
boolean ClickerButtonState = 0; // Value of digital reads from button line of joystick input device
boolean LastClickerButtonState = 1;
int LastClickerYState = 0; // 0 for neutral, 1 for up, 2 for down.
int LastClickerXState = 0; // 0 for neutral, 1 for left, 2 for right.
int inMenu = 0; // Menu id: 0 for top, 1 for channel menu, 2 for action menu
int SelectedChannel = 0;
int SelectedAction = 1;
int SelectedStimMode = 1;
boolean NeedUpdate = 0; // If a new menu item is selected, the screen must be updated

// Variables used in stimulus playback
byte inByte; byte inByte2; byte inByte3; byte inByte4; byte CommandByte;
byte LogicLevel = 0;
unsigned long SystemTime = 0;
unsigned long BurstTimestamps[4] = {0};
unsigned long PrePulseTrainTimestamps[4] = {0};
unsigned long PulseTrainTimestamps[4] = {0};
unsigned long NextPulseTransitionTime[4] = {0}; // Stores next pulse-high or pulse-low timestamp for each channel
unsigned long NextBurstTransitionTime[4] = {0}; // Stores next burst-on or burst-off timestamp for each channel
unsigned long StimulusTrainEndTime[4] = {0}; // Stores time the stimulus train is supposed to end
unsigned long CustomTrain1[1001] = {0};
unsigned long CustomTrain2[1001] = {0};
byte CustomVoltage1[1001] = {0};
byte CustomVoltage2[1001] = {0};
unsigned long LastLoopTime = 0;
byte FirstLoop = 1; // This determines whether this is the first loop execution of the stimulus train.
int PulseStatus[4] = {0}; // This is 0 if not delivering a pulse, 1 if delivering.
boolean BurstStatus[4] = {0}; // This is "true" during bursts and false during inter-burst intervals.
boolean StimulusStatus[4] = {0}; // This is "true" for a channel when the stimulus train is actively being delivered
boolean PreStimulusStatus[4] = {0}; // This is "true" for a channel during the pre-stimulus delay
boolean InputValues[2] = {0}; // The values read directly from the two inputs (for analog, digital equiv. after thresholding)
boolean InputValuesLastCycle[2] = {0}; // The values on the last cycle. Used to detect low to high transitions.
boolean LineTriggerEvent[2] = {0}; // 0 if no line trigger event detected, 1 if present.
unsigned long InputLineDebounceTimestamp[2] = {0}; // Last time the line went from high to low
boolean UsesBursts[4] = {0};
boolean IsBiphasic[4] = {0};
boolean ContinuousLoopMode[4] = {0}; // If true, the channel loops its programmed stimulus train continuously
int AnalogValues[2] = {0};
int SensorValue = 0;
boolean Stimulating = 0; // true if ANY channel is stimulating. Used to shut down analog reads on joystick, USB com, etc. for increased precision.
int nStimulatingChannels = 0; // number of actively stimulating channels
boolean ChangeFlag = 0; // true if any DAC line changed its value, requiring an update
boolean DACFlags[4] = {0}; // true if an individual DAC needs to be updated
byte DACValues[4] = {0};
byte DefaultInputLevel = 0; // 0 for PulsePal 0.3, 1 for 0.2 and 0.1. Logic is inverted by optoisolator
byte DACBuffer0[2] = {0}; // Buffers already containing address for faster SPIwriting
byte DACBuffer1[2] = {1};
byte DACBuffer2[2] = {2};
byte DACBuffer3[2] = {3};

// Other variables
char Value2Display[18] = {' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', '\0'};
int lastDebounceTime = 0; // to debounce the joystick button
boolean lastButtonState = 0;
boolean ChoiceMade = 0; // determines whether user has chosen a value from a list
unsigned int UserValue = 0; // The current value displayed on a list of values (written to LCD when choosing parameters) 

void setup() {
  // Enable EEPROM
  pinMode(CS, OUTPUT);
  digitalWrite(CS, HIGH); // disable writes
  EEPROM.begin(SPI_9MHZ, MSBFIRST, SPI_MODE);
  // set up the LCD
  lcd.begin(16, 2);
  lcd.clear();
  lcd.home();
  lcd.noDisplay() ;
  delay(100);
  lcd.display() ;
  
  // Pin modes
  pinMode(InputLines[0], INPUT);
  pinMode(InputLines[1], INPUT);
  pinMode(ClickerButtonLine, INPUT_PULLUP);
  pinMode(ClickerXLine, INPUT_ANALOG);
  pinMode(ClickerYLine, INPUT_ANALOG);
  
    for (int x = 0; x < 4; x++) {
    //pinMode(OutputLines[x], OUTPUT);
    pinMode(OutputLEDLines[x], OUTPUT);
    //digitalWrite(OutputLines[x], HIGH);
    //digitalWrite(OutputLines[x], LOW);
  }
    spi.begin(SPI_18MHZ, MSBFIRST, 0);
    pinMode(DACLoadPin, OUTPUT);
    pinMode(DACLatchPin, OUTPUT);
    pinMode(InputLEDLines[0], OUTPUT);
    pinMode(InputLEDLines[1], OUTPUT);
    // Set DAC to 0V on all channels
    digitalWrite(DACLoadPin,HIGH);
    digitalWrite(DACLatchPin, HIGH);
    for (int x = 0; x < 4; x++) {
      spi.write(x);
      spi.write(128);
      digitalWrite(DACLoadPin, LOW);
      digitalWrite(DACLoadPin, HIGH);
      DACValues[x] = 128;
    }
    //---end Set DAC
  
    digitalWrite(DACLatchPin,LOW);
    digitalWrite(DACLatchPin, HIGH);
//    pinMode(LEDLine, OUTPUT);
//    digitalWrite(LEDLine, HIGH); //   
//    delay(1000);
//    digitalWrite(LEDLine, LOW); //   
    RestoreParametersFromEEPROM();
    RestoreCustomStimuli();
    write2Screen(" PULSE PAL v0.4"," Click for menu");
    SystemTime = micros();
    LastLoopTime = SystemTime;
    DefaultInputLevel = 1 - TriggerLevel;
}

void loop() {
  if (Stimulating == 0) {
  SystemTime = micros();
  LastLoopTime = SystemTime;
  UpdateSettingsMenu(inByte);
   } else {
     // Make sure loop runs once every 50us
    while ((SystemTime-LastLoopTime) < 50) {
       SystemTime = micros();
     }
    LastLoopTime = SystemTime;
      // Write to DACs
    dacWrite(DACValues);
     ClickerButtonState = digitalRead(ClickerButtonLine);
     if (ClickerButtonState == LOW){    // A button click ends ongoing stimulation on all channels.
       for (int x = 0; x < 4; x++) {
          StimulusStatus[x] = 0;
          PulseStatus[x] = 0;
          CustomStimTimestampIndex[x] = 0;
          BurstStatus[x] = 0;
          DACValues[x] = 128; 
          gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
        }
        dacWrite(DACValues);
        write2Screen("   PULSE TRAIN","     ABORTED");
        delay(1000);
        if (inMenu == 0) {
          switch (ConnectedToApp) {
             case 0: {write2Screen(" PULSE PAL v0.4"," Click for menu");} break;
             case 1: {write2Screen("MATLAB Connected"," Click for menu");} break;
          }
        } else {
          inMenu = 1;
          RefreshChannelMenu(SelectedChannel);
        }
       }
 }
  if (SerialUSB.available() > 0) {
    CommandByte = SerialUSB.read();
    switch (CommandByte) {
      // Device ID Response
      case 72: {SerialUSB.write(75); ConnectedToApp = 1;} break;

      // Program the module - total program (faster than item-wise)
      case 73: {
        digitalWrite(LEDLine, HIGH); //
        for (int x = 0; x < 4; x++) {
          Phase1Duration[x] = SerialReadLong();
          InterPhaseInterval[x] = SerialReadLong();
          Phase2Duration[x] = SerialReadLong();
          InterPulseInterval[x] = SerialReadLong();
          BurstDuration[x] = SerialReadLong();
          BurstInterval[x] = SerialReadLong();
          StimulusTrainDuration[x] = SerialReadLong();
          StimulusTrainDelay[x] = SerialReadLong();
        }
        for (int x = 0; x < 4; x++) {
          while (SerialUSB.available() == 0) {} IsBiphasic[x] = SerialUSB.read();
          while (SerialUSB.available() == 0) {} Phase1Voltage[x] = SerialUSB.read();
          while (SerialUSB.available() == 0) {} Phase2Voltage[x] = SerialUSB.read();
          while (SerialUSB.available() == 0) {} FollowsCustomStimID[x] = SerialUSB.read();
          while (SerialUSB.available() == 0) {} CustomStimTarget[x] = SerialUSB.read();
          while (SerialUSB.available() == 0) {} CustomStimLoop[x] = SerialUSB.read();
        }
       while (SerialUSB.available() == 0) {} TriggerAddress[0] = SerialUSB.read(); 
       while (SerialUSB.available() == 0) {} TriggerAddress[1] = SerialUSB.read(); 
       while (SerialUSB.available() == 0) {} TriggerMode[0] = SerialUSB.read(); 
       while (SerialUSB.available() == 0) {} TriggerMode[1] = SerialUSB.read();
       SerialUSB.write(1); // Send confirm byte
       digitalWrite(LEDLine, LOW);
       for (int x = 0; x < 4; x++) {
         if ((BurstDuration[x] == 0) || (BurstInterval[x] == 0)) {UsesBursts[x] = false;} else {UsesBursts[x] = true;}
         if (CustomStimTarget[x] == 1) {UsesBursts[x] = true;}
         if ((FollowsCustomStimID[x] > 0) && (CustomStimTarget[x] == 0)) {UsesBursts[x] = false;}
       }
      } break;
      
      // Program the module - one parameter
      case 74: {
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        while (SerialUSB.available() == 0) {} 
        inByte3 = SerialUSB.read(); // inByte3 = channel (1-4)
        switch (inByte2) { 
           case 1: {while (SerialUSB.available() == 0) {} IsBiphasic[inByte3] = SerialUSB.read();} break;
           case 2: {while (SerialUSB.available() == 0) {} Phase1Voltage[inByte3] = SerialUSB.read();} break;
           case 3: {while (SerialUSB.available() == 0) {} Phase2Voltage[inByte3] = SerialUSB.read();} break;
           case 4: {Phase1Duration[inByte3] = SerialReadLong();} break;
           case 5: {InterPhaseInterval[inByte3] = SerialReadLong();} break;
           case 6: {Phase2Duration[inByte3] = SerialReadLong();} break;
           case 7: {InterPulseInterval[inByte3] = SerialReadLong();} break;
           case 8: {BurstDuration[inByte3] = SerialReadLong();} break;
           case 9: {BurstInterval[inByte3] = SerialReadLong();} break;
           case 10: {StimulusTrainDuration[inByte3] = SerialReadLong();} break;
           case 11: {StimulusTrainDelay[inByte3] = SerialReadLong();} break;
           case 12: {while (SerialUSB.available() == 0) {} inByte4 = SerialUSB.read(); bitWrite(TriggerAddress[0], inByte3, inByte4);} break;
           case 13: {while (SerialUSB.available() == 0) {} inByte4 = SerialUSB.read(); bitWrite(TriggerAddress[1], inByte3, inByte4);} break;
           case 14: {while (SerialUSB.available() == 0) {} FollowsCustomStimID[inByte3] = SerialUSB.read();} break;
           case 15: {while (SerialUSB.available() == 0) {} CustomStimTarget[inByte3] = SerialUSB.read();} break;
           case 16: {while (SerialUSB.available() == 0) {} CustomStimLoop[inByte3] = SerialUSB.read();} break;
           case 128: {while (SerialUSB.available() == 0) {} TriggerMode[inByte3] = SerialUSB.read();} break;
        }
        if (inByte2 < 14) {
          if ((BurstDuration[inByte3] == 0) || (BurstInterval[inByte3] == 0)) {UsesBursts[inByte3] = false;} else {UsesBursts[inByte3] = true;}
          if (CustomStimTarget[inByte3] == 1) {UsesBursts[inByte3] = true;}
          if ((FollowsCustomStimID[inByte3] > 0) && (CustomStimTarget[inByte3] == 0)) {UsesBursts[inByte3] = false;}
        }
        SerialUSB.write(1); // Send confirm byte
      } break;

      // Program custom stimulus 1
      case 75: {
        digitalWrite(LEDLine, HIGH); //
        while (SerialUSB.available() == 0) {}
        USBPacketCorrectionByte = SerialUSB.read();
        CustomStimNpulses[0] = SerialReadLong();
        for (int x = 0; x < CustomStimNpulses[0]; x++) {
          CustomTrain1[x] = SerialReadLong();
        }
        for (int x = 0; x < CustomStimNpulses[0]; x++) {
          while (SerialUSB.available() == 0) {} 
          CustomVoltage1[x] = SerialUSB.read();
        }
        if (USBPacketCorrectionByte == 1) {
          USBPacketCorrectionByte = 0;
          CustomStimNpulses[0] = CustomStimNpulses[0]  - 1;
        }
        SerialUSB.write(1); // Send confirm byte
        digitalWrite(LEDLine, LOW); //
      } break;
      // Program custom stimulus 2
      case 76: {
        digitalWrite(LEDLine, HIGH); //
        while (SerialUSB.available() == 0) {}
        USBPacketCorrectionByte = SerialUSB.read();
        CustomStimNpulses[1] = SerialReadLong();
        for (int x = 0; x < CustomStimNpulses[1]; x++) {
          CustomTrain2[x] = SerialReadLong();
        }
        for (int x = 0; x < CustomStimNpulses[1]; x++) {
          while (SerialUSB.available() == 0) {} 
          CustomVoltage2[x] = SerialUSB.read();
        }
        if (USBPacketCorrectionByte == 1) {
          USBPacketCorrectionByte = 0;
          CustomStimNpulses[1] = CustomStimNpulses[1]  - 1;
        }
        SerialUSB.write(1); // Send confirm byte
        digitalWrite(LEDLine, LOW); //
      } break;      
      // Soft-trigger the module
      case 77: {
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        for (int x = 0; x < 4; x++) {
          PreStimulusStatus[x] = bitRead(inByte2, x);
          if (PreStimulusStatus[x] == 1) {
            if ((FollowsCustomStimID[x] > 0) && (CustomStimTarget[x] == 1)) {BurstStatus[x] = 0;} else {
                 BurstStatus[x] = 1; 
            }
          PrePulseTrainTimestamps[x] = SystemTime;
          FirstLoop = 1;
          }
        }
      } break;
      case 78: { 
        while (SerialUSB.available() == 0) {}
        delay(100);
        lcd.clear();
        // wait a bit for the entire message to arrive
         lcd.home(); 
        // read all the available characters
        while (SerialUSB.available() > 0) {
            // display each character to the LCD
            inByte = SerialUSB.read();
            if (inByte != 254) {
            lcd.write(inByte);
            } else {
              lcd.setCursor(0, 1);
            }
        }
      } break;
      case 79: {
        // Write specific voltage to output channel (not a pulse train) 
        while (SerialUSB.available() == 0) {}
        inByte = SerialUSB.read();
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        DACValues[inByte] = inByte2;
        dacWrite(DACValues);
        SerialUSB.write(1); // Send confirm byte
      } break;
      case 80: { // Soft-abort ongoing stimulation without disconnecting from client
       for (int x = 0; x < 4; x++) {
        StimulusStatus[x] = 0;
        PulseStatus[x] = 0;
        CustomStimTimestampIndex[x] = 0;
        BurstStatus[x] = 0;
        DACValues[x] = 128; 
        gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
      }
      dacWrite(DACValues);
     } break;
     case 81: { // Disconnect from client and store params to EEPROM
        ConnectedToApp = 0;
        inMenu = 0;
        for (int x = 0; x < 4; x++) {
          StimulusStatus[x] = 0;
          PulseStatus[x] = 0;
          CustomStimTimestampIndex[x] = 0;
          BurstStatus[x] = 0;
          DACValues[x] = 128; 
          gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
        }
        dacWrite(DACValues);
        // Store last program to EEPROM
        write2Screen("Saving Settings",".");
        EEPROM_address = 0;
        for (int x = 0; x < 4; x++) {
          PrepareOutputChannelMemoryPage1(x);
          WriteEEPROMPage(PageBytes, 32, EEPROM_address);
          EEPROM_address = EEPROM_address + 32;
          PrepareOutputChannelMemoryPage2(x);
          WriteEEPROMPage(PageBytes, 32, EEPROM_address);
          EEPROM_address = EEPROM_address + 32;
        }
        write2Screen("Saving Settings",". .");
        // Store custom stimuli to EEPROM
        StoreCustomStimuli(); // UNCOMMENT WHEN FIXED - this overwrites stuff it shouldnt and doesn't write where it should
        write2Screen(" PULSE PAL v0.4"," Click for menu");
       } break;
       // Set free-run mode
      case 82:{
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        while (SerialUSB.available() == 0) {}
        inByte3 = SerialUSB.read();
        ContinuousLoopMode[inByte2] = inByte3;
        SerialUSB.write(1);
      } break;
      case 83: { // Clear stored parameters from EEPROM
       WipeEEPROM();
       if (inMenu == 0) {
      switch (ConnectedToApp) {
         case 0: {write2Screen(" PULSE PAL v0.4"," Click for menu");} break;
         case 1: {write2Screen("MATLAB Connected"," Click for menu");} break;
      }
      } else {
        inMenu = 1;
        RefreshChannelMenu(SelectedChannel);
      }
     } break;
     case 84: {
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        EEPROM_address = inByte2;
        while (SerialUSB.available() == 0) {}
        nBytesToWrite = SerialUSB.read();
        for (int i = 0; i < nBytesToWrite; i++) {
        while (SerialUSB.available() == 0) {}
        PageBytes[i] =  SerialUSB.read();
        }
        WriteEEPROMPage(PageBytes, nBytesToWrite, EEPROM_address);
        SerialUSB.write(1);
      } break; 
    case 85: {
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        EEPROM_address = inByte2;
        while (SerialUSB.available() == 0) {}
        nBytesToRead = SerialUSB.read();
        for (int i = 0; i < nBytesToRead; i++) {
         EEPROM_OutputValue = ReadEEPROM(EEPROM_address+i);
         SerialUSB.write(EEPROM_OutputValue);
        }
      } break;
      
      case 86: { // Override IO Lines
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        while (SerialUSB.available() == 0) {}
        inByte3 = SerialUSB.read();
        pinMode(inByte2, OUTPUT); digitalWrite(inByte2, inByte3);
      } break; 
      
      case 87: { // Direct Read IO Lines
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        pinMode(inByte2, INPUT);
        delayMicroseconds(10);
        LogicLevel = digitalRead(inByte2);
        SerialUSB.write(LogicLevel);
      } break; 
      case 88: { // Direct Read IO Lines as analog
        while (SerialUSB.available() == 0) {}
        inByte2 = SerialUSB.read();
        pinMode(inByte2, INPUT_ANALOG);
        delay(10);
        SensorValue = analogRead(inByte2);
        SerialUSB.println(SensorValue);
        pinMode(inByte2, OUTPUT);
      } break;
    }
}

    // Read values of trigger pins
    for (int x = 0; x < 2; x++) {
         //InputValues[x] = gpio_read_bit(INPUT_PIN_PORT, InputLineBits[x]);
         InputValues[x] = digitalRead(InputLines[x]);
         if (InputValues[x] == TriggerLevel) {
           gpio_write_bit(INPUT_PIN_PORT, InputLEDLineBits[x], HIGH);
         } else {
           gpio_write_bit(INPUT_PIN_PORT, InputLEDLineBits[x], LOW);
         }
         if (ReTriggerMode[x] == 0) {
         // update LineTriggerEvent with logic representing logic transition
           if ((InputValues[x] == TriggerLevel) && (InputValuesLastCycle[x] == DefaultInputLevel)) {
             LineTriggerEvent[x] = 1;
           }
           InputValuesLastCycle[x] = InputValues[x];
         } else {
           if (TriggerLevel == 1) {
             LineTriggerEvent[x] = InputValues[x];
           } else {
             LineTriggerEvent[x] = 1 - InputValues[x];
           }
         } 

    }
       
    for (int x = 0; x < 4; x++) {
       // Adjust StimulusStatus to reflect new changes
       if ((StimulusStatus[x] == 0) && (PreStimulusStatus[x] == 0) && bitRead(TriggerAddress[0], x) && LineTriggerEvent[0] == 1) {
         PreStimulusStatus[x] = 1; BurstStatus[x] = 1; PrePulseTrainTimestamps[x] = SystemTime; NextBurstTransitionTime[x] = (SystemTime + StimulusTrainDelay[x] + 1000); FirstLoop = 1; PulseStatus[x] = 0; 
       }
       if ((StimulusStatus[x] == 0) && (PreStimulusStatus[x] == 0) && bitRead(TriggerAddress[1], x) && LineTriggerEvent[1] == 1) {
         PreStimulusStatus[x] = 1; BurstStatus[x] = 1; PrePulseTrainTimestamps[x] = SystemTime; NextBurstTransitionTime[x] = (SystemTime + StimulusTrainDelay[x] + 1000); FirstLoop = 1; PulseStatus[x] = 0;
       }
       // If Toggle mode is active, shut down any governed channels that are already active
       if (((StimulusStatus[x] == 1) || (PreStimulusStatus[x] == 1))) {
        if (bitRead(TriggerAddress[0], x) && (LineTriggerEvent[0] == 1) && (PrePulseTrainTimestamps[x] != SystemTime) && (ReTriggerMode[0] == 0)) {
           if (TriggerMode[0] == 1) {
             PreStimulusStatus[x] = 0;
             StimulusStatus[x] = 0;
             CustomStimTimestampIndex[x] = 0;
             PulseStatus[x] = 0;
             DACValues[x] = 128;
             gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
           }
         }
         if (bitRead(TriggerAddress[1], x) && (LineTriggerEvent[1] == 1) && (PrePulseTrainTimestamps[x] != SystemTime) && (ReTriggerMode[1] == 0)) {
           if (TriggerMode[1] == 1) {
             PreStimulusStatus[x] = 0;
             StimulusStatus[x] = 0;
             CustomStimTimestampIndex[x] = 0;
             PulseStatus[x] = 0;
             DACValues[x] = 128;
             gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
           }
         } 
       }
    }
    LineTriggerEvent[0] = 0; LineTriggerEvent[1] = 0;
     Stimulating = 0; // null condition, will be overridden in loop if any channels are still stimulating.
     ChangeFlag = false;
    // Check clock and adjust line levels for new time as per programming
    for (int x = 0; x < 4; x++) {
      if (PreStimulusStatus[x] == 1) {
        if (SystemTime >= (PrePulseTrainTimestamps[x] + StimulusTrainDelay[x])) {
          PreStimulusStatus[x] = 0;
          StimulusStatus[x] = 1;
          PulseStatus[x] = 0;
          PulseTrainTimestamps[x] = SystemTime;
          StimulusTrainEndTime[x] = SystemTime + StimulusTrainDuration[x];
          if (CustomStimTarget[x] == 1)  {
            if (FollowsCustomStimID[x] == 1) {
              NextBurstTransitionTime[x] = SystemTime + CustomTrain1[0];
            } else {
              NextBurstTransitionTime[x] = SystemTime + CustomTrain2[0];
            }
            BurstStatus[x] = 0;
          } else {
          NextBurstTransitionTime[x] = SystemTime+BurstDuration[x];
          }
          if (FollowsCustomStimID[x] == 0) {
            NextPulseTransitionTime[x] = SystemTime;
            DACValues[x] = Phase1Voltage[x];
          } else if (FollowsCustomStimID[x] == 1) {
            NextPulseTransitionTime[x] = SystemTime + CustomTrain1[0]; 
          } else {
            NextPulseTransitionTime[x] = SystemTime + CustomTrain2[0];
          }
        }
      }
      if (StimulusStatus[x] == 1) { // if this output line has been triggered and is delivering a stimulus
      Stimulating = 1;
        if (BurstStatus[x] == 1) { // if this output line is currently delivering a burst
          switch (PulseStatus[x]) { // depending on the phase of the pulse
          
           case 0: { // if this is the inter-pulse interval
            // determine if the next pulse should start now
            if ((FollowsCustomStimID[x] == 0) || ((FollowsCustomStimID[x] > 0) && (CustomStimTarget[x] == 1))) {
              if (SystemTime >= NextPulseTransitionTime[x]) {
                NextPulseTransitionTime[x] = SystemTime + (Phase1Duration[x] - (SystemTime - NextPulseTransitionTime[x]));
                if ((NextPulseTransitionTime[x] - SystemTime) <= (StimulusTrainEndTime[x] - SystemTime)) { // so that it doesn't start a pulse it can't finish due to pulse train end
                  if (!((UsesBursts[x] == 1) && (NextPulseTransitionTime[x] >= NextBurstTransitionTime[x]))){ // so that it doesn't start a pulse it can't finish due to burst end
                    PulseStatus[x] = 1;
                    gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], HIGH);
                    if ((FollowsCustomStimID[x] > 0) && (CustomStimTarget[x] == 1)) {
                      DACValues[x] = CustomVoltage1[CustomStimTimestampIndex[x]];
                    } else {
                      DACValues[x] = Phase1Voltage[x]; 
                    }
                  }
                }
              }
            } else if (FollowsCustomStimID[x] == 1) {
               if (SystemTime >= NextPulseTransitionTime[x]) {
                 int SkipNextPulse = 0;
                 if ((CustomStimLoop[x] == 1) && (CustomStimTimestampIndex[x] == CustomStimNpulses[0])) {
                        CustomStimTimestampIndex[x] = 0;
                        PulseTrainTimestamps[x] = SystemTime-25; // ensures that despite 4us jitter, the next multiple of 50us timestamp will be read properly. 
                 }
                 if (CustomStimTimestampIndex[x] < CustomStimNpulses[0]) {
                   if ((CustomTrain1[CustomStimTimestampIndex[x]+1] - CustomTrain1[CustomStimTimestampIndex[x]]) > Phase1Duration[x]) {
                     NextPulseTransitionTime[x] = SystemTime + (Phase1Duration[x] - (SystemTime - NextPulseTransitionTime[x]));
                   } else {
                     NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain1[CustomStimTimestampIndex[x]+1];  
                     SkipNextPulse = 1;
                   }
                 }
                 if (SkipNextPulse == 0) {
                    PulseStatus[x] = 1;
                 }
                 DACValues[x] = CustomVoltage1[CustomStimTimestampIndex[x]];
                 gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], HIGH);
                   if (IsBiphasic[x] == 0) {
                      CustomStimTimestampIndex[x] = CustomStimTimestampIndex[x] + 1;
                   }
                 if (CustomStimTimestampIndex[x] > (CustomStimNpulses[0])){
                   CustomStimTimestampIndex[x] = 0;
                   if (CustomStimLoop[x] == 0) {
                     StimulusStatus[x] = 0;
                     PulseStatus[x] = 0;
                     DACValues[x] = 128;
                     gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                   }
                 }
               } 
            } else if (FollowsCustomStimID[x] == 2) {
               if (SystemTime >= NextPulseTransitionTime[x]) {
                 int SkipNextPulse = 0;
                 if ((CustomStimLoop[x] == 1) && (CustomStimTimestampIndex[x] == CustomStimNpulses[1])) {
                        CustomStimTimestampIndex[x] = 0;
                        PulseTrainTimestamps[x] = SystemTime-25; // ensures that despite 4us jitter, the next multiple of 50us timestamp will be read properly. 
                 }
                 if (CustomStimTimestampIndex[x] < CustomStimNpulses[1]) {
                   if ((CustomTrain2[CustomStimTimestampIndex[x]+1] - CustomTrain2[CustomStimTimestampIndex[x]]) > Phase1Duration[x]) {
                     NextPulseTransitionTime[x] = SystemTime + (Phase1Duration[x] - (SystemTime - NextPulseTransitionTime[x]));
                   } else {
                     NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain2[CustomStimTimestampIndex[x]+1];  
                     SkipNextPulse = 1;
                   }
                 }
                 if (SkipNextPulse == 0) {
                 PulseStatus[x] = 1;
                 }
                 gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], HIGH);
                  DACValues[x] = CustomVoltage2[CustomStimTimestampIndex[x]];
                   if (IsBiphasic[x] == 0) {
                      CustomStimTimestampIndex[x] = CustomStimTimestampIndex[x] + 1;
                   }
                 if (CustomStimTimestampIndex[x] > (CustomStimNpulses[1])){
                   CustomStimTimestampIndex[x] = 0;
                   if (CustomStimLoop[x] == 0) {
                     StimulusStatus[x] = 0;
                     PulseStatus[x] = 0;
                     DACValues[x] = 128;
                     gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                   }
                 }
               }
              }
            } break;
            
            case 1: { // if this is the first phase of the pulse
             // determine if this phase should end now
             if (SystemTime > NextPulseTransitionTime[x]) {
                if (IsBiphasic[x] == 0) {
                  if (FollowsCustomStimID[x] == 0) {
                      NextPulseTransitionTime[x] = SystemTime + (InterPulseInterval[x] - (SystemTime - NextPulseTransitionTime[x]));
                  } else if (FollowsCustomStimID[x] == 1) {
                    if (CustomStimTarget[x] == 0) {
                      NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain1[CustomStimTimestampIndex[x]];
                    } else {
                      NextPulseTransitionTime[x] = SystemTime + (InterPulseInterval[x] - (SystemTime - NextPulseTransitionTime[x]));
                    }
                  } else {
                    if (CustomStimTarget[x] == 0) {
                        NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain2[CustomStimTimestampIndex[x]];
                    } else {
                        NextPulseTransitionTime[x] = SystemTime + (InterPulseInterval[x] - (SystemTime - NextPulseTransitionTime[x]));
                    }
                  }
                  if (!((FollowsCustomStimID[x] == 0) && (InterPulseInterval[x] == 0))) { 
                    PulseStatus[x] = 0;
                    gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                    DACValues[x] = 128; 
                  } else {
                   PulseStatus[x] = 1;
                   NextPulseTransitionTime[x] = (NextPulseTransitionTime[x] - InterPulseInterval[x]) + (Phase1Duration[x]);
                   DACValues[x] = Phase1Voltage[x]; 
                  }
                } else {
                  if (InterPhaseInterval[x] == 0) {
                    NextPulseTransitionTime[x] = SystemTime + (Phase2Duration[x] - (SystemTime - NextPulseTransitionTime[x]));
                    PulseStatus[x] = 3;
                    if (FollowsCustomStimID[x] == 0) {
                    DACValues[x] = Phase2Voltage[x]; 
                    } else {
                   if (FollowsCustomStimID[x] == 1) {
                     if (CustomVoltage1[CustomStimTimestampIndex[x]] < 128) {
                       DACValues[x] = 128 + (128 - CustomVoltage1[CustomStimTimestampIndex[x]]); 
                     } else {
                       DACValues[x] = 128 - (CustomVoltage1[CustomStimTimestampIndex[x]] - 128);
                     }
                   } else {
                     if (CustomVoltage1[CustomStimTimestampIndex[x]] < 128) {
                       DACValues[x] = 128 + (128 - CustomVoltage2[CustomStimTimestampIndex[x]]); 
                     } else {
                       DACValues[x] = 128 - (CustomVoltage2[CustomStimTimestampIndex[x]]-128);
                     } 
                   }
                   if (CustomStimTarget[x] == 0) {
                       CustomStimTimestampIndex[x] = CustomStimTimestampIndex[x] + 1;
                   }
                    } 
                  } else {
                    NextPulseTransitionTime[x] = SystemTime + (InterPhaseInterval[x] - (SystemTime - NextPulseTransitionTime[x]));
                    PulseStatus[x] = 2;
                    DACValues[x] = 128; 
                  }
                }
              }
            } break;
            case 2: {
               if (SystemTime > NextPulseTransitionTime[x]) {
                 NextPulseTransitionTime[x] = SystemTime + (Phase2Duration[x] - (SystemTime - NextPulseTransitionTime[x]));
                 PulseStatus[x] = 3;
                 if (FollowsCustomStimID[x] == 0) {
                 DACValues[x] = Phase2Voltage[x]; 
                 } else {
                   if (FollowsCustomStimID[x] == 1) {
                     if (CustomVoltage1[CustomStimTimestampIndex[x]] < 128) {
                       DACValues[x] = 128 + (128 - CustomVoltage1[CustomStimTimestampIndex[x]]); 
                     } else {
                       DACValues[x] = 128 - (CustomVoltage1[CustomStimTimestampIndex[x]] - 128);
                     }
                   } else {
                     if (CustomVoltage1[CustomStimTimestampIndex[x]] < 128) {
                       DACValues[x] = 128 + (128 - CustomVoltage2[CustomStimTimestampIndex[x]]); 
                     } else {
                       DACValues[x] = 128 - (CustomVoltage2[CustomStimTimestampIndex[x]]-128);
                     } 
                   }
                   if (CustomStimTarget[x] == 0) {
                       CustomStimTimestampIndex[x] = CustomStimTimestampIndex[x] + 1;
                   }
                 }
               }
            } break;
            case 3: {
              if (SystemTime > NextPulseTransitionTime[x]) {
                  if (FollowsCustomStimID[x] == 0) {
                      NextPulseTransitionTime[x] = SystemTime + (InterPulseInterval[x] - (SystemTime - NextPulseTransitionTime[x]));
                  } else if (FollowsCustomStimID[x] == 1) {  
                    if (CustomStimTarget[x] == 0) {
                      NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain1[CustomStimTimestampIndex[x]];
                      if (CustomStimTimestampIndex[x] >= (CustomStimNpulses[0])){
                          CustomStimTimestampIndex[x] = 0;
                          StimulusStatus[x] = 0;
                          PulseStatus[x] = 0;
                          DACValues[x] = 128;
                          gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                     }
                    } else {
                      NextPulseTransitionTime[x] = SystemTime + (InterPulseInterval[x] - (SystemTime - NextPulseTransitionTime[x]));
                    }  
                  } else {
                    if (CustomStimTarget[x] == 0) {
                        NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain2[CustomStimTimestampIndex[x]];
                        if (CustomStimTimestampIndex[x] >= (CustomStimNpulses[1])){
                         CustomStimTimestampIndex[x] = 0;
                          StimulusStatus[x] = 0;
                          PulseStatus[x] = 0;
                          DACValues[x] = 128;
                          gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                       }
                    } else {
                        NextPulseTransitionTime[x] = SystemTime + (InterPulseInterval[x] - (SystemTime - NextPulseTransitionTime[x]));
                    } 
                  }
                 if (!((FollowsCustomStimID[x] == 0) && (InterPulseInterval[x] == 0))) { 
                   PulseStatus[x] = 0;
                   gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                   DACValues[x] = 128; 
                 } else {
                   PulseStatus[x] = 1;
                   NextPulseTransitionTime[x] = (NextPulseTransitionTime[x] - InterPulseInterval[x]) + (Phase1Duration[x]);
                   DACValues[x] = Phase1Voltage[x]; 
                 }
               }
            } break;
            
          }
        }
          // Determine if burst status should go to 0 now
       if (UsesBursts[x] == true) {
        if (SystemTime >= NextBurstTransitionTime[x]) {
          if (BurstStatus[x] == 1) {
            if (FollowsCustomStimID[x] == 0) {
                     NextPulseTransitionTime[x] = SystemTime + (BurstInterval[x] - (SystemTime - NextBurstTransitionTime[x]));
                     NextBurstTransitionTime[x] = SystemTime + (BurstInterval[x] - (SystemTime - NextBurstTransitionTime[x]));
              } else if ((FollowsCustomStimID[x] == 1) &&(CustomStimTarget[x] == 1)) {
                     CustomStimTimestampIndex[x] = CustomStimTimestampIndex[x] + 1;
                     if (CustomStimTimestampIndex[x] > (CustomStimNpulses[0])){
                         CustomStimTimestampIndex[x] = 0;
                         StimulusStatus[x] = 0;
                         PulseStatus[x] = 0;
                         BurstStatus[x] = 0;
                         DACValues[x] = 128; 
                         gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                     }
                     NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain1[CustomStimTimestampIndex[x]];
                     NextBurstTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain1[CustomStimTimestampIndex[x]];
                     
              } else if  ((FollowsCustomStimID[x] == 2) &&(CustomStimTarget[x] == 1)) {
                      CustomStimTimestampIndex[x] = CustomStimTimestampIndex[x] + 1;
                      if (CustomStimTimestampIndex[x] > (CustomStimNpulses[1])){ 
                     CustomStimTimestampIndex[x] = 0;
                     StimulusStatus[x] = 0;
                     PulseStatus[x] = 0;
                     BurstStatus[x] = 0;
                     DACValues[x] = 128; 
                     gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW);
                     }
                      NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain2[CustomStimTimestampIndex[x]];
                      NextBurstTransitionTime[x] = PulseTrainTimestamps[x] + CustomTrain2[CustomStimTimestampIndex[x]];
                      
              }
              BurstStatus[x] = 0;
              DACValues[x] = 128; 
          } else {
          // Determine if burst status should go to 1 now
            //NextBurstTransitionTime[x] = SystemTime + BurstDuration[x];
            NextBurstTransitionTime[x] = SystemTime + (BurstDuration[x] - (SystemTime - NextBurstTransitionTime[x]));
            //NextPulseTransitionTime[x] = SystemTime + Phase1Duration[x];
            NextPulseTransitionTime[x] = SystemTime + (Phase1Duration[x] - (SystemTime - NextPulseTransitionTime[x]));
            PulseStatus[x] = 1;
            if ((FollowsCustomStimID[x] > 0) && (CustomStimTarget[x] == 1)) {
              if (FollowsCustomStimID[x] == 1) {
                 if (CustomStimTimestampIndex[x] < CustomStimNpulses[0]){
                    DACValues[x] = CustomVoltage1[CustomStimTimestampIndex[x]];
                 }
              } else {
                if (CustomStimTimestampIndex[x] < CustomStimNpulses[1]){
                    DACValues[x] = CustomVoltage1[CustomStimTimestampIndex[x]];
                 }
              }
            } else {
                 DACValues[x] = Phase1Voltage[x]; 
            }
            BurstStatus[x] = 1;
         }
        }
       } 
        // Determine if Stimulus Status should go to 0 now
        if ((SystemTime > StimulusTrainEndTime[x]) && (StimulusStatus[x] == 1)) {
          if (((FollowsCustomStimID[x] > 0) && (CustomStimLoop[x] == 1)) || (FollowsCustomStimID[x] == 0)) {
          if (ContinuousLoopMode[x] == false) {
              CustomStimTimestampIndex[x] = 0;
              StimulusStatus[x] = 0;
              PulseStatus[x] = 0;
              DACValues[x] = 128; 
              gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[x], LOW); 
            }
          }
        }
       
         
      
    }

  }
}
// Convenience Functions


unsigned long SerialReadLong() {
   // Generic routine for getting a 4-byte long int over the serial port
   unsigned long OutputLong = 0;
        while (SerialUSB.available() == 0) {}
          inByte = SerialUSB.read();
        while (SerialUSB.available() == 0) {}
          inByte2 = SerialUSB.read();
        while (SerialUSB.available() == 0) {}
          inByte3 = SerialUSB.read();
        while (SerialUSB.available() == 0) {}
          inByte4 = SerialUSB.read();
          OutputLong =  makeLong(inByte4, inByte3, inByte2, inByte);
  return OutputLong;
}

unsigned long Bytes2Long(byte Highest, byte High, byte Low, byte Lowest) 
{
    unsigned long OutputVal = 0;
    
    // Compute
    
    return OutputVal;
}

byte* Long2Bytes(long LongInt2Break) {
  byte Output[4] = {0};
  return Output;
}


//void dacWrite(byte DACVal[]) {
//  for (int x = 0; x < 4; x++) {
//      spi.write(x);
//      spi.write(DACVal[x]);
//      digitalWrite(DACLoadPin, LOW);
//      digitalWrite(DACLoadPin, HIGH);
//  }
//
//  digitalWrite(DACLatchPin,LOW);
//  digitalWrite(DACLatchPin, HIGH);
//}
void dacWrite(byte DACVal[]) {
      DACBuffer0[1] = DACVal[0];
      spi.write(DACBuffer0,2);
      GPIOB_BASE->BRR = 1<<5; // DAC load pin low
      GPIOB_BASE->BSRR = 1<<5; // DAC load pin high
      DACBuffer1[1] = DACVal[1];
      spi.write(DACBuffer1,2);
      GPIOB_BASE->BRR = 1<<5; // DAC load pin low
      GPIOB_BASE->BSRR = 1<<5; // DAC load pin high
      DACBuffer2[1] = DACVal[2];
      spi.write(DACBuffer2,2);
      GPIOB_BASE->BRR = 1<<5; // DAC load pin low
      GPIOB_BASE->BSRR = 1<<5; // DAC load pin high
      DACBuffer3[1] = DACVal[3];
      spi.write(DACBuffer3,2);
      GPIOB_BASE->BRR = 1<<5; // DAC load pin low
      GPIOB_BASE->BSRR = 1<<5; // DAC load pin high

      GPIOB_BASE->BRR = 1<<6; // DAC latch pin low
      GPIOB_BASE->BRR = 1<<6; // DAC latch pin low (stall for time)
      GPIOB_BASE->BSRR = 1<<6; // DAC latch pin high
}

void UpdateSettingsMenu(int inByte) {
    ClickerX = analogRead(ClickerXLine);
    ClickerY = analogRead(ClickerYLine);
    ClickerButtonState = ReadDebouncedButton();
    if (ClickerButtonState == 1 && LastClickerButtonState == 0) {
      LastClickerButtonState = 1;
      switch(inMenu) {
        case 0: {
          inMenu = 1;
          SelectedChannel = 1;
          write2Screen("Output Channels","<  Channel 1  >");
          NeedUpdate = 1;
        } break;
        case 1: {
          switch(SelectedChannel) {
            case 7: {
              inMenu = 0;
              switch (ConnectedToApp) {
                case 0: {write2Screen(" PULSE PAL v0.4"," Click for menu");} break;
                case 1: {write2Screen("MATLAB Connected"," Click for menu");} break;
              }
            } break;
            
          // These two are to prevent entering the input menus until they are programmed
          case 6: {} break;
          case 5:{} break;
          default: {
            inMenu = 2;
            SelectedAction = 1;
            write2Screen("< Trigger Now  >"," ");
          } break;
         }
       } break;
       case 2: {
        switch (SelectedAction) {
          case 1: {
            inMenu = 3; // soft-trigger menu
            write2Screen("< Single Train >"," ");
            SelectedStimMode = 1;
          } break;
          case 2: {IsBiphasic[SelectedChannel-1] = ReturnUserValue(0, 1, 1, 3);} break; // biphasic (on /off)
          case 3: {Phase1Voltage[SelectedChannel-1] = ReturnUserValue(0, 255, 1, 2);} break; // Get user to input phase 1 voltage
          case 4: {Phase1Duration[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 50, 1);} break; // phase 1 duration
          case 5: {InterPhaseInterval[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 100, 1);} break; // inter-phase interval
          case 6: {Phase2Voltage[SelectedChannel-1] = ReturnUserValue(0, 255, 1, 2);} break; // Get user to input phase 2 voltage
          case 7: {Phase2Duration[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 50, 1);} break; // phase 2 duration
          case 8: {InterPulseInterval[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 100, 1);} break; // pulse interval
          case 9: {BurstDuration[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 50, 1);} break; // burst width
          case 10: {BurstInterval[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 50, 1);} break; // burst interval
          case 11: {StimulusTrainDelay[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 50, 1);} break; // stimulus train delay
          case 12: {StimulusTrainDuration[SelectedChannel-1] = ReturnUserValue(50, 4000000000, 50, 1);} break; // stimulus train duration
          case 13: {byte Bit2Write = ReturnUserValue(0, 1, 1, 3);
                    byte Ch = SelectedChannel-1;
                    bitWrite(TriggerAddress[0], Ch, Bit2Write);
                    } break; // Follow input 1 (on/off)
          case 14: {byte Bit2Write = ReturnUserValue(0, 1, 1, 3);
                    byte Ch = SelectedChannel-1;
                    bitWrite(TriggerAddress[1], Ch, Bit2Write);
                    } break; // Follow input 2 (on/off)
          case 15: {FollowsCustomStimID[SelectedChannel-1] = ReturnUserValue(0, 2, 1, 0);} break; // stimulus train duration
          case 16: {CustomStimTarget[SelectedChannel-1] = ReturnUserValue(0,1,1,4);} break; // Custom stim target (Pulses / Bursts)
          case 17: {
            // Exit to channel menu
          inMenu = 1; RefreshChannelMenu(SelectedChannel);
          } break;
         }
         if ((SelectedAction > 1) && (SelectedAction < 9)) {
          //EEPROM update channel timer values
          PrepareOutputChannelMemoryPage1(SelectedChannel-1);
          WriteEEPROMPage(PageBytes, 32, ((SelectedChannel-1)*64));
          PrepareOutputChannelMemoryPage2(SelectedChannel-1);
          WriteEEPROMPage(PageBytes, 32, (((SelectedChannel-1)*64)+32));              
         }
        } break;
        case 3: {
        switch (SelectedStimMode) {
          case 1: {
            // Soft-trigger channel
            write2Screen("< Single Train >","      ZAP!");
            delay(100);
            while (ClickerButtonState == 1) {
             ClickerButtonState = ReadDebouncedButton();
            }
            write2Screen("< Single Train >"," ");
            PreStimulusStatus[SelectedChannel-1] = 1;
            BurstStatus[SelectedChannel-1] = 1;
            PrePulseTrainTimestamps[SelectedChannel-1] = micros();  
          } break;
          case 2: {
            write2Screen("< Single Pulse >","      ZAP!");
            delay(100);
            write2Screen("< Single Pulse >"," ");
            SystemTime = micros();
            if (IsBiphasic[SelectedChannel-1] == 0) {
              DACValues[SelectedChannel-1] = Phase1Voltage[SelectedChannel-1];
              NextPulseTransitionTime[SelectedChannel-1] = SystemTime + Phase1Duration[SelectedChannel-1];
              dacWrite(DACValues);
              while (NextPulseTransitionTime[SelectedChannel-1] > SystemTime) {SystemTime = micros();}
              DACValues[SelectedChannel-1] = 128;
              dacWrite(DACValues);
            } else {
              DACValues[SelectedChannel-1] = Phase1Voltage[SelectedChannel-1];
              NextPulseTransitionTime[SelectedChannel-1] = SystemTime + Phase1Duration[SelectedChannel-1];
              dacWrite(DACValues);
              while (NextPulseTransitionTime[SelectedChannel-1] > SystemTime) {SystemTime = micros();}
              if (InterPhaseInterval[SelectedChannel-1] > 0) {
              DACValues[SelectedChannel-1] = 128;
              NextPulseTransitionTime[SelectedChannel-1] = SystemTime + InterPhaseInterval[SelectedChannel-1];
              dacWrite(DACValues);
              while (NextPulseTransitionTime[SelectedChannel-1] > SystemTime) {SystemTime = micros();}
              }
              DACValues[SelectedChannel-1] = Phase2Voltage[SelectedChannel-1];
              NextPulseTransitionTime[SelectedChannel-1] = SystemTime + Phase2Duration[SelectedChannel-1];
              dacWrite(DACValues);
              while (NextPulseTransitionTime[SelectedChannel-1] > SystemTime) {SystemTime = micros();}
              DACValues[SelectedChannel-1] = 128;
              dacWrite(DACValues);
            }
          } break;
          case 3: {
            if (ContinuousLoopMode[SelectedChannel-1] == false) {
               write2Screen("<  Continuous  >","      On");
               ContinuousLoopMode[SelectedChannel-1] = true;
           } else {
               write2Screen("<  Continuous  >","      Off");
               ContinuousLoopMode[SelectedChannel-1] = false;
               PulseStatus[SelectedChannel-1] = 0;
               BurstStatus[SelectedChannel-1] = 0;
               StimulusStatus[SelectedChannel-1] = 0;
               CustomStimTimestampIndex[SelectedChannel-1] = 0;
               DACValues[SelectedChannel-1] = 128;
               dacWrite(DACValues);
               gpio_write_bit(LED_PIN_PORT, OutputLEDLineBits[SelectedChannel-1], LOW);
             }
          } break;
          case 4: {
            inMenu = 2;
            SelectedAction = 1;
            write2Screen("< Trigger Now  >"," ");
          } break;
         }
       } break; 
    }
    }
    if (ClickerButtonState == 0 && LastClickerButtonState == 1) {
      LastClickerButtonState = 0;
    }
    if (LastClickerXState != 1 && ClickerX < 800) {
      LastClickerXState = 1;
      NeedUpdate = 1;
      if (inMenu == 1) {SelectedChannel = SelectedChannel - 1;}
      if (inMenu == 2) {
        if ((IsBiphasic[SelectedChannel-1] == 0) && (SelectedAction == 8)) {
          SelectedAction = SelectedAction - 4;
        } else {  
          SelectedAction = SelectedAction - 1;
        }
      }
      if (inMenu == 3) {SelectedStimMode = SelectedStimMode - 1;}
      if (SelectedChannel == 0) {SelectedChannel = 7;}
      if (SelectedAction == 0) {SelectedAction = 17;}
      if (SelectedStimMode == 0) {SelectedStimMode = 4;}
    }
    if (LastClickerXState != 2 && ClickerX > 3200) {
      LastClickerXState = 2;
      NeedUpdate = 1;
      if (inMenu == 1) {SelectedChannel = SelectedChannel + 1;}
      if (inMenu == 2) {
        if ((IsBiphasic[SelectedChannel-1] == 0) && (SelectedAction == 4)) {
          SelectedAction = SelectedAction + 4;
        } else {
          SelectedAction = SelectedAction + 1;
        }
      }
      if (inMenu == 3) {SelectedStimMode = SelectedStimMode + 1;}
      if (SelectedChannel == 8) {SelectedChannel = 1;}
      if (SelectedAction == 18) {SelectedAction = 1;}
      if (SelectedStimMode == 5) {SelectedStimMode = 1;}
    }
    if (LastClickerXState != 0 && ClickerX < 2800 && ClickerX > 1200) {
      LastClickerXState = 0;
    }
    if (NeedUpdate == 1) {
      if (inMenu == 1) {
        RefreshChannelMenu(SelectedChannel);
      } else if (inMenu == 2) {
        RefreshActionMenu(SelectedAction);
      } else if (inMenu == 3) {
        switch (SelectedStimMode) {
          case 1: {write2Screen("< Single Train >", " ");} break;
          case 2: {write2Screen("< Single Pulse >", " ");} break;
          case 3: {
          if (ContinuousLoopMode[SelectedChannel-1] == false) {
               write2Screen("<  Continuous  >","      Off");
             } else {
               write2Screen("<  Continuous  >","      On");
             }
        } break;
          case 4: {write2Screen("<     Exit     >"," ");} break;
        }
      }
      NeedUpdate = 0;
    }
}
void RefreshChannelMenu(int ThisChannel) {
  switch (SelectedChannel) {
        case 1: {write2Screen("Output Channels","<  Channel 1  >");} break;
        case 2: {write2Screen("Output Channels","<  Channel 2  >");} break;
        case 3: {write2Screen("Output Channels","<  Channel 3  >");} break;
        case 4: {write2Screen("Output Channels","<  Channel 4  >");} break;
        case 5: {write2Screen("Input Channels","<  Channel 1  >");} break;
        case 6: {write2Screen("Input Channels","<  Channel 2  >");} break;
        case 7: {write2Screen("<Click to exit>"," ");} break;
  }
}
void RefreshActionMenu(int ThisAction) {
    switch (SelectedAction) {
          case 1: {write2Screen("< Trigger Now  >"," ");} break;
          case 2: {write2Screen("<Biphasic Pulse>",FormatNumberForDisplay(IsBiphasic[SelectedChannel-1], 3));} break;
          case 3: {write2Screen("<Phase1 Voltage>",FormatNumberForDisplay(Phase1Voltage[SelectedChannel-1], 2));} break;
          case 4: {write2Screen("<Phase1Duration>",FormatNumberForDisplay(Phase1Duration[SelectedChannel-1], 1));} break;
          case 5: {write2Screen("<InterPhaseTime>",FormatNumberForDisplay(InterPhaseInterval[SelectedChannel-1], 1));} break;
          case 6: {write2Screen("<Phase2 Voltage>",FormatNumberForDisplay(Phase2Voltage[SelectedChannel-1], 2));} break;
          case 7: {write2Screen("<Phase2Duration>",FormatNumberForDisplay(Phase2Duration[SelectedChannel-1], 1));} break;
          case 8: {write2Screen("<Pulse Interval>",FormatNumberForDisplay(InterPulseInterval[SelectedChannel-1], 1));} break;
          case 9: {write2Screen("<Burst Duration>",FormatNumberForDisplay(BurstDuration[SelectedChannel-1], 1));} break;
          case 10: {write2Screen("<Burst Interval>",FormatNumberForDisplay(BurstInterval[SelectedChannel-1], 1));} break;
          case 11: {write2Screen("< Train Delay  >",FormatNumberForDisplay(StimulusTrainDelay[SelectedChannel-1], 1));} break;
          case 12: {write2Screen("<Train Duration>",FormatNumberForDisplay(StimulusTrainDuration[SelectedChannel-1], 1));} break;
          case 13: {write2Screen("<Follow input 1>",FormatNumberForDisplay(bitRead(TriggerAddress[0], SelectedChannel-1), 3));} break;
          case 14: {write2Screen("<Follow input 2>",FormatNumberForDisplay(bitRead(TriggerAddress[1], SelectedChannel-1), 3));} break; 
          case 15: {write2Screen("<Custom Stim ID>",FormatNumberForDisplay(FollowsCustomStimID[SelectedChannel-1], 0));} break;
          case 16: {write2Screen("<Custom Target >",FormatNumberForDisplay(CustomStimTarget[SelectedChannel-1], 4));} break;
          case 17: {write2Screen("<     Exit     >"," ");} break;
     }
}

void write2Screen(const char* Line1, const char* Line2) {
  lcd.clear(); lcd.home(); lcd.print(Line1); lcd.setCursor(0, 1); lcd.print(Line2);
}

const char* FormatNumberForDisplay(unsigned int InputNumber, int Units) {
  // Units are: 0 - none, 1 - s/ms, 2 - V
  // Clear var
  for (int x = 0; x < 17; x++) {
    Value2Display[x] = ' ';
  }
  // Figure out how many digits
unsigned int Bits2Display = InputNumber;
double InputNum = double(InputNumber);
  if (Units == 1) {
  InputNum = InputNum/1000000;
  }
if (Units == 2) {
  // Convert volts from bytes to volts
  InputNum = (((InputNum/256)*10)*2 - 10);
}
  switch (Units) {
    case 0: {sprintf (Value2Display, "       %.0f", InputNum);} break;
    case 1: {
      if (inMenu == 3) {
        sprintf (Value2Display, "  %010.5f s ", InputNum);
      } else {
        if (InputNum < 100) {
          sprintf (Value2Display, "    %.5f s ", InputNum);
        } else {
          sprintf (Value2Display, "   %.5f s ", InputNum);
        }
      }
    } break;
    case 2: {
      if (inMenu == 3) {
        if (InputNum >= 0) {
          if (Bits2Display == 256) {
            sprintf (Value2Display, "%03d bits= +%04.1fV ", Bits2Display, InputNum);
          } else {
            sprintf (Value2Display, "%03d bits= +%04.2fV ", Bits2Display, InputNum);
          }
        } else {
          if (Bits2Display > 0) {
            sprintf (Value2Display, "%03d bits= %4.2fV", Bits2Display, InputNum);
          } else {
            sprintf (Value2Display, "%03d bits= %04.1fV", Bits2Display, InputNum);
          }
        }
      } else {
        if (InputNum >= 0) {
          sprintf (Value2Display, "     %04.2f V", InputNum);
        } else {
          sprintf (Value2Display, "    %05.2f V", InputNum);
        }
      }
    } break;
    case 3:{
      if (InputNum == 0) {
        sprintf(Value2Display, "      Off");
      } else if (InputNum == 1) {
        sprintf(Value2Display, "       On");
      } else {
        sprintf(Value2Display, "Error");
      }
    } break;
    case 4: {
      if (InputNum == 0) {
        sprintf(Value2Display, "     Pulses");
      } else if (InputNum == 1) {
        sprintf(Value2Display, "     Bursts");
      } else {
        sprintf(Value2Display, "Error");
      }
    } break;
  }
  return Value2Display;
}

boolean ReadDebouncedButton() {
  ClickerButtonState = digitalRead(ClickerButtonLine);
  //ClickerButtonState = gpio_read_bit(INPUT_PIN_PORT, ClickerButtonBit);
    if (ClickerButtonState != lastButtonState) {lastDebounceTime = SystemTime;}
    lastButtonState = ClickerButtonState;
   if (((SystemTime - lastDebounceTime) > 75000) && (ClickerButtonState == LOW)) {
      return 1;
   } else {
     return 0;
   }
   
}

unsigned int ReturnUserValue(unsigned int LowerLimit, unsigned int UpperLimit, unsigned int StepSize, byte Units) {
      // This function returns a value that the user chooses by scrolling up and down a number list with the joystick, and clicks to select the desired number.
      // LowerLimit and UpperLimit are the limits for this selection, StepSize is the smallest step size the system will scroll. Units (as for Write2Screen) codes none=0, time=1, volts=2 True/False=3
     switch (SelectedAction) {
       case 2:{UserValue = IsBiphasic[SelectedChannel-1];} break;
       case 3:{UserValue = Phase1Voltage[SelectedChannel-1];} break;
       case 4:{UserValue = Phase1Duration[SelectedChannel-1];} break;
       case 5:{UserValue = InterPhaseInterval[SelectedChannel-1];} break;
       case 6:{UserValue = Phase2Voltage[SelectedChannel-1];} break;
       case 7:{UserValue = Phase2Duration[SelectedChannel-1];} break;
       case 8:{UserValue = InterPulseInterval[SelectedChannel-1];} break;
       case 9:{UserValue = BurstDuration[SelectedChannel-1];} break;
       case 10:{UserValue = BurstInterval[SelectedChannel-1];} break;
       case 11:{UserValue = StimulusTrainDelay[SelectedChannel-1];} break;
       case 12:{UserValue = StimulusTrainDuration[SelectedChannel-1];} break;
       case 13:{UserValue = bitRead(TriggerAddress[0], SelectedChannel-1);} break;
       case 14:{UserValue = bitRead(TriggerAddress[1], SelectedChannel-1);} break;
       case 15:{UserValue = FollowsCustomStimID[SelectedChannel-1];} break;
       case 16:{UserValue = CustomStimTarget[SelectedChannel-1];} break;       
     }
     inMenu = 3; // Temporarily goes a menu layer deeper so leading zeros are displayed by FormatNumberForDisplay
     lcd.setCursor(0, 1); lcd.print("                ");
     delay(100);
     lcd.setCursor(0, 1); lcd.print(FormatNumberForDisplay(UserValue, Units));
     ChoiceMade = 0;
     int ScrollSpeedDelay = 500;
     int Place = 0; 
     byte CursorPos = 0;
     byte CursorPosRightLimit = 0;
     byte CursorPosLeftLimit = 0;
     byte ValidCursorPositions[9] = {0};
     byte Digits[9] = {0};
     int DACBits = pow(2,8);
     int CandidateVoltage = 0; // used to see if voltage will go over limits for DAC
    unsigned int UVTemp = UserValue;
    float FractionalVoltage = 0;
    // Read digits from User Value
    int x = 0;
    if (Units == 1) {
      UVTemp = UVTemp / 10;
      while (UVTemp > 0) {
        Digits[8-x] = (UVTemp % 10);
        UVTemp = UVTemp / 10;
        x++;
      }
    }
    if (Units == 2) {
      Digits[2] = (UVTemp % 10);
      UVTemp = UVTemp/10;
      Digits[1] = (UVTemp % 10);
      UVTemp = UVTemp/10;
      Digits[0] = (UVTemp % 10);
    }
    
     // Assign valid cursor positions by unit type
     switch(Units) {
       case 0: {ValidCursorPositions[0] = 7;} break;
       case 1: {ValidCursorPositions[0] = 2; ValidCursorPositions[1] = 3; ValidCursorPositions[2] = 4; ValidCursorPositions[3] = 5; ValidCursorPositions[4] = 7; ValidCursorPositions[5] = 8; ValidCursorPositions[6] = 9; ValidCursorPositions[7] = 10; ValidCursorPositions[8] = 11;} break;
       case 2: {ValidCursorPositions[0] = 0; ValidCursorPositions[1] = 1; ValidCursorPositions[2] = 2;} break;
       case 3: {ValidCursorPositions[0] = 7;} break;
       case 4: {ValidCursorPositions[0] = 7;} break;
     }
     // Initialize cursor starting positions and limits by unit type
     switch (Units) {
       case 0: {CursorPos = 0; CursorPosLeftLimit = 0; CursorPosRightLimit = 0;} break; // Format for Index
       case 1: {CursorPos = 3; CursorPosLeftLimit = 0; CursorPosRightLimit = 8;} break; // Format for seconds
       case 2: {CursorPos = 2; CursorPosLeftLimit = 0; CursorPosRightLimit = 2;} break; // Format for volts
       case 3: {CursorPos = 0; CursorPosLeftLimit = 0; CursorPosRightLimit = 0;} break; // Format for Off/On
       case 4: {CursorPos = 0; CursorPosLeftLimit = 0; CursorPosRightLimit = 0;} break; // Format for Pulses/Bursts
       }
     unsigned int CursorToggleTime = micros();
     unsigned int CursorToggleInterval = 300000; // Cursor toggle interval in microseconds
     boolean CursorOn = 0;
     while (ChoiceMade == 0) {
       SystemTime = micros();
       if (SystemTime > CursorToggleTime) {
         switch (CursorOn) {
           case 0: { lcd.setCursor(ValidCursorPositions[CursorPos], 1); lcd.cursor(); CursorOn = 1;} break;
           case 1: {lcd.noCursor(); CursorOn = 0;} break;
         }
         CursorToggleTime = SystemTime+CursorToggleInterval;
       }
       ClickerX = analogRead(ClickerXLine);
       ClickerY = analogRead(ClickerYLine);
       ChoiceMade = ReadDebouncedButton();
       if (ClickerY < 1500) {
          switch(Units) {
            case 0: {
              if (UserValue < UpperLimit) {
                UserValue = UserValue + 1;
              }
            } break;
            case 1: {
              if (CursorPos < 8) {
                if (Digits[CursorPos] < 9) {
                 UserValue = UserValue + pow(10, ((7-CursorPos)+2));
                 Digits[CursorPos] = Digits[CursorPos] + 1;
                }
              } else {
                if (Digits[CursorPos] == 0) {
                 UserValue = UserValue + 50;
                 Digits[CursorPos] = Digits[CursorPos] + 5;
                }
              }
            } break;
            case 2: {
                if (((CursorPos > 0) && (Digits[CursorPos] < 9)) || (((CursorPos == 0) && (Digits[CursorPos] < 2)))) {
                    if (UserValue < 255) {
                      Digits[CursorPos] = Digits[CursorPos] + 1;
                      CandidateVoltage = 0;
                      CandidateVoltage = CandidateVoltage + (Digits[0]*100);
                      CandidateVoltage = CandidateVoltage + (Digits[1]*10);
                      CandidateVoltage = CandidateVoltage + (Digits[2]*1);
                      
                      if (CandidateVoltage > DACBits) {
                        Digits[CursorPos] = Digits[CursorPos] - 1;
                      } else {
                        UserValue = CandidateVoltage;
                        //dacWrite(SelectedChannel-1, UserValue);
                        delay(1);
                      }
                    }
                } 
            } break;
            case 3: {
              if (UserValue < UpperLimit) {
                UserValue = UserValue + 1;
              }
            } break;
            case 4: {
              if (UserValue < UpperLimit) {
                UserValue = UserValue + 1;
              }
            } break;
          }
          ScrollSpeedDelay = 300;
          lcd.noCursor();
          lcd.setCursor(0, 1); lcd.print(FormatNumberForDisplay(UserValue, Units));
       }
      else if (ClickerY > 2500) {
         switch(Units) {
            case 0: {
              if (UserValue > LowerLimit) {
                UserValue = UserValue - 1;
              }
            } break;
            case 1: {
              if (CursorPos < 8) {
                if (Digits[CursorPos] > 0) {
                 UserValue = UserValue - pow(10, ((7-CursorPos)+2));
                  Digits[CursorPos] = Digits[CursorPos] - 1;
                }
              } else {
                if (Digits[CursorPos] == 5) {
                 UserValue = UserValue - 50;
                  Digits[CursorPos] = Digits[CursorPos] - 5;
                }
              }
            } break;
            case 2: {
              if (Digits[CursorPos] > 0) {
                    if (UserValue > 0) {
                      Digits[CursorPos] = Digits[CursorPos] - 1;
                      CandidateVoltage = 0;
                      CandidateVoltage = CandidateVoltage + (Digits[0]*100);
                      CandidateVoltage = CandidateVoltage + (Digits[1]*10);
                      CandidateVoltage = CandidateVoltage + (Digits[2]*1);

                      if (CandidateVoltage < 0) {
                        Digits[CursorPos] = Digits[CursorPos] + 1;
                      } else {
                        UserValue = CandidateVoltage;
                        //dacWrite(SelectedChannel-1, UserValue);
                        delay(1);
                      }
                    }
                } 
            } break;
            case 3: {
              if (UserValue > LowerLimit) {
                UserValue = UserValue - 1;
              }
            } break;
            case 4: {
              if (UserValue > LowerLimit) {
                UserValue = UserValue - 1;
              }
            } break;
          }
          ScrollSpeedDelay = 300;
          lcd.noCursor();
          lcd.setCursor(0, 1); lcd.print(FormatNumberForDisplay(UserValue, Units));
       } else {
         ScrollSpeedDelay = 0;
       }
       if ((ClickerX > 2500) && (CursorPos < CursorPosRightLimit)) {
         CursorPos = CursorPos + 1;
         ScrollSpeedDelay = 300;
         lcd.noCursor();
          lcd.setCursor(0, 1); lcd.print(FormatNumberForDisplay(UserValue, Units));
         lcd.setCursor(ValidCursorPositions[CursorPos], 1); lcd.cursor(); CursorOn = 1; CursorToggleTime = SystemTime+CursorToggleInterval;
       }
       if ((ClickerX < 1500) && (CursorPos > CursorPosLeftLimit)) {
         CursorPos = CursorPos - 1;
         ScrollSpeedDelay = 300;
         lcd.noCursor();
         lcd.setCursor(0, 1); lcd.print(FormatNumberForDisplay(UserValue, Units));
         lcd.setCursor(ValidCursorPositions[CursorPos], 1); lcd.cursor(); CursorOn = 1; CursorToggleTime = SystemTime+CursorToggleInterval;
       }
     delay(ScrollSpeedDelay);  
     }
     // If the system now uses bursts, update UsesBursts param
     for (int x = 0; x < 4; x++) {
              if (BurstDuration[x] == 0) {UsesBursts[x] = false;} else {UsesBursts[x] = true;}
            }
     lcd.noCursor();
     lcd.setCursor(0, 1); lcd.print("                ");
     inMenu = 2;
     delay(100);
     lcd.setCursor(0, 1); lcd.print(FormatNumberForDisplay(UserValue, Units));
     //lcd.noCursor();
     return UserValue;
} 

byte  ReadEEPROM(int EEPROM_address) {
 int data;
 digitalWrite(CS, LOW); // EEPROM enable
 EEPROM.send(READ); //transmit read opcode
 EEPROM.send((uint8)(EEPROM_address>>8)); //send MSByte address first
 EEPROM.send((uint8)(EEPROM_address)); //send LSByte address
 data = EEPROM.send(0xFF); //get data byte
 digitalWrite(CS, HIGH); // EEPROM disable
 return data;
}
void WriteEEPROMPage(byte Content[], byte nBytes, int address) {
 digitalWrite(CS, LOW); // EEPROM enable
 EEPROM.send(WREN); // EEPROM write enable instruction
 digitalWrite(CS, HIGH); // EEPROM disable
 delay(10);
 digitalWrite(CS, LOW); // EEPROM enable
 EEPROM.send(WRITE); // EEPROM write instruction
 EEPROM.send((uint8)(address>>8)); //send MSByte address first
 EEPROM.send((uint8)(address)); //send LSByte address
 for (int i = 0; i < nBytes; i++) {
 EEPROM.send(Content[i]); // EEPROM write data byte
 }
 digitalWrite(CS, HIGH); // EEPROM disable
 delay(5);
}

void PrepareOutputChannelMemoryPage1(byte ChannelNum) {
  // This function organizes a single output channel's parameters into an array in preparation for an EEPROM memory write operation, according to the
  // PulsePal EEPROM Map (see documentation). Each channel is stored in two pages of memory. This function prepares page 1.
  breakLong(Phase1Duration[ChannelNum]);
  PageBytes[0] = BrokenBytes[0]; PageBytes[1] = BrokenBytes[1]; PageBytes[2] = BrokenBytes[2]; PageBytes[3] = BrokenBytes[3]; 
  breakLong(InterPhaseInterval[ChannelNum]);
  PageBytes[4] = BrokenBytes[0]; PageBytes[5] = BrokenBytes[1]; PageBytes[6] = BrokenBytes[2]; PageBytes[7] = BrokenBytes[3]; 
  breakLong(Phase2Duration[ChannelNum]);
  PageBytes[8] = BrokenBytes[0]; PageBytes[9] = BrokenBytes[1]; PageBytes[10] = BrokenBytes[2]; PageBytes[11] = BrokenBytes[3]; 
  breakLong(InterPulseInterval[ChannelNum]);
  PageBytes[12] = BrokenBytes[0]; PageBytes[13] = BrokenBytes[1]; PageBytes[14] = BrokenBytes[2]; PageBytes[15] = BrokenBytes[3]; 
  breakLong(BurstDuration[ChannelNum]);
  PageBytes[16] = BrokenBytes[0]; PageBytes[17] = BrokenBytes[1]; PageBytes[18] = BrokenBytes[2]; PageBytes[19] = BrokenBytes[3]; 
  breakLong(BurstInterval[ChannelNum]);
  PageBytes[20] = BrokenBytes[0]; PageBytes[21] = BrokenBytes[1]; PageBytes[22] = BrokenBytes[2]; PageBytes[23] = BrokenBytes[3]; 
  breakLong(StimulusTrainDuration[ChannelNum]);
  PageBytes[24] = BrokenBytes[0]; PageBytes[25] = BrokenBytes[1]; PageBytes[26] = BrokenBytes[2]; PageBytes[27] = BrokenBytes[3]; 
  breakLong(StimulusTrainDelay[ChannelNum]);
  PageBytes[28] = BrokenBytes[0]; PageBytes[29] = BrokenBytes[1]; PageBytes[30] = BrokenBytes[2]; PageBytes[31] = BrokenBytes[3]; 
}

void PrepareOutputChannelMemoryPage2(byte ChannelNum) {
  // This function organizes a single output channel's parameters into an array in preparation for an EEPROM memory write operation, according to the
  // PulsePal EEPROM Map (see documentation). Each channel is stored in two pages of memory. This function prepares page 2.
  PageBytes[0] = IsBiphasic[ChannelNum];
  PageBytes[1] = Phase1Voltage[ChannelNum];
  // PageBytes[2] reserved for >8-bit DAC upgrade 
  PageBytes[3] = Phase2Voltage[ChannelNum];
  // PageBytes[3] reserved for >8-bit DAC upgrade
  PageBytes[4] = FollowsCustomStimID[ChannelNum];
  PageBytes[5] = CustomStimTarget[ChannelNum];
  PageBytes[6] = TriggerAddress[0]; // To be used in future...
  PageBytes[7] = TriggerAddress[1];
  PageBytes[8] = CustomStimLoop[ChannelNum];
  PageBytes[9] = 0;
  PageBytes[10] = 0;
  PageBytes[11] = 0;
  PageBytes[12] = 0;
  PageBytes[13] = 0;
  PageBytes[14] = 0;
  PageBytes[15] = 0;
  PageBytes[16] = 0;
  PageBytes[17] = 0;
  PageBytes[18] = 0;
  PageBytes[19] = 0;
  PageBytes[20] = 0;
  PageBytes[21] = 0;
  PageBytes[22] = 0;
  PageBytes[23] = 0;
  PageBytes[24] = 0;
  PageBytes[25] = 0;
  PageBytes[26] = 0;
  PageBytes[27] = 0;
  PageBytes[28] = 0;
  PageBytes[29] = 0;
  PageBytes[30] = 0;
  PageBytes[31] = 0;
}
void breakLong(unsigned long LongInt2Break) {
  //BrokenBytes is a global array for the output of long int break operations
  BrokenBytes[3] = (byte)(LongInt2Break >> 24);
  BrokenBytes[2] = (byte)(LongInt2Break >> 16);
  BrokenBytes[1] = (byte)(LongInt2Break >> 8);
  BrokenBytes[0] = (byte)LongInt2Break;
}
void RestoreParametersFromEEPROM() {
  // This function is called on Pulse Pal boot, to make pulse pal parameters invariant to power cycles.
  int ChannelMemoryOffset = 0;
   byte PB = 0;
  for (int Chan = 0; Chan < 4; Chan++) {
    ChannelMemoryOffset = 64*Chan;
    PB = 0;
    for (int i = ChannelMemoryOffset; i < (32+ChannelMemoryOffset); i++) {
      PageBytes[PB] = ReadEEPROM(i);
      PB++;
    }
    // Set Channel time parameters
    Phase1Duration[Chan] =  makeLong(PageBytes[3], PageBytes[2], PageBytes[1], PageBytes[0]);
    InterPhaseInterval[Chan] = makeLong(PageBytes[7], PageBytes[6], PageBytes[5], PageBytes[4]);
    Phase2Duration[Chan] = makeLong(PageBytes[11], PageBytes[10], PageBytes[9], PageBytes[8]);
    InterPulseInterval[Chan] = makeLong(PageBytes[15], PageBytes[14], PageBytes[13], PageBytes[12]);
    BurstDuration[Chan] = makeLong(PageBytes[19], PageBytes[18], PageBytes[17], PageBytes[16]);
    BurstInterval[Chan] = makeLong(PageBytes[23], PageBytes[22], PageBytes[21], PageBytes[20]);
    StimulusTrainDuration[Chan] = makeLong(PageBytes[27], PageBytes[26], PageBytes[25], PageBytes[24]);
    StimulusTrainDelay[Chan] = makeLong(PageBytes[31], PageBytes[30], PageBytes[29], PageBytes[28]);
    PB = 0;
    for (int i = (32+ChannelMemoryOffset); i < (64+ChannelMemoryOffset); i++) {
      PageBytes[PB] = ReadEEPROM(i);
      PB++;
    }
    // Set Channel non-time parameters
    IsBiphasic[Chan] = PageBytes[0];
    Phase1Voltage[Chan] = PageBytes[1];
    Phase2Voltage[Chan] = PageBytes[3];
    FollowsCustomStimID[Chan] = PageBytes[4];
    CustomStimTarget[Chan] = PageBytes[5];
    TriggerAddress[0] = PageBytes[6]; // This is stored on every channel and over-written 4 times for convenience 
    TriggerAddress[1] = PageBytes[7];
    CustomStimLoop[Chan] = PageBytes[8];
  }
}

void StoreCustomStimuli() {

  // Store voltages for custom stim 1
  int WritePosition = 1024;
  int WritePagePosition = 1024;
  int CustomStimPosition = 0;
  for (int i = 0; i < 31; i++) {
    for (int x = 0; x < 32; x++) {
      PageBytes[x] = CustomVoltage1[CustomStimPosition];
      WritePosition++; CustomStimPosition++;
    }
    WriteEEPROMPage(PageBytes, 32, WritePagePosition);
    WritePagePosition = WritePagePosition + 32;
  }
  for (int x = 0; x < 8; x++) {
    PageBytes[x] = CustomVoltage1[CustomStimPosition];
    WritePosition++; CustomStimPosition++;
  }
  for (int x = 8; x < 32; x++) {
    PageBytes[x] = 0;
  }
  WriteEEPROMPage(PageBytes, 32, WritePagePosition);
  write2Screen("Saving Settings",". . .");
  // Store voltages for custom stim 2
  WritePosition = 2048;
  WritePagePosition = 2048;
  CustomStimPosition = 0;
  for (int i = 0; i < 31; i++) {
    for (int x = 0; x < 32; x++) {
      PageBytes[x] = CustomVoltage2[CustomStimPosition];
      WritePosition++; CustomStimPosition++;
    }
    WriteEEPROMPage(PageBytes, 32, WritePagePosition);
    WritePagePosition = WritePagePosition + 32;
  }
  for (int x = 0; x < 8; x++) {
    PageBytes[x] = CustomVoltage2[CustomStimPosition];
    WritePosition++; CustomStimPosition++;
  }
  for (int x = 8; x < 32; x++) {
    PageBytes[x] = 0;
  }
  WriteEEPROMPage(PageBytes, 32, WritePagePosition);
  write2Screen("Saving Settings",". . . .");
  // Store timestamps for custom stim 1
//  WritePagePosition = 3072;
//  CustomStimPosition = 0;
//  int inPagePosition = 0;
//  for (int i = 0; i < 125; i++) {
//    inPagePosition = 0;
//    for (int x = 0; x < 8; x++) { 
//      breakLong(CustomTrain1[CustomStimPosition]);
//      for (int y = 0; y < 4; y++) {
//        PageBytes[inPagePosition] = BrokenBytes[y];
//        inPagePosition++;
//      }
//      CustomStimPosition++;      
//    }
//    WriteEEPROMPage(PageBytes, 32, WritePagePosition);
//    WritePagePosition = WritePagePosition + 32;
//  }
  write2Screen("Saving Settings",". . . . .");
  // Store timestamps for custom stim 2
//  WritePagePosition = 7200;
//  CustomStimPosition = 0;
//  inPagePosition = 0;
//  for (int i = 0; i < 125; i++) {
//    inPagePosition = 0;
//    for (int x = 0; x < 8; x++) { 
//      breakLong(CustomTrain2[CustomStimPosition]);
//      for (int y = 0; y < 4; y++) {
//        PageBytes[inPagePosition] = BrokenBytes[y];
//        inPagePosition++;
//      }
//      CustomStimPosition++;      
//    }
//    WriteEEPROMPage(PageBytes, 32, WritePagePosition);
//    WritePagePosition = WritePagePosition + 32;
//  }
  write2Screen("Saving Settings",". . . . . Done!");
  delay(700);
}

void RestoreCustomStimuli() {
  int ChannelMemoryOffset = 1024;
  int ChennelMemoryEnd = ChannelMemoryOffset+1000;
  byte  PB = 0;
    for (int i = ChannelMemoryOffset; i < (ChennelMemoryEnd); i++) {
      CustomVoltage1[PB] = ReadEEPROM(i);
      PB++;
    }
  ChannelMemoryOffset = 2048;
  ChennelMemoryEnd = ChannelMemoryOffset+1000;
  PB = 0;
    for (int i = ChannelMemoryOffset; i < (ChennelMemoryEnd); i++) {
      CustomVoltage2[PB] = ReadEEPROM(i);
      PB++;
    }
  ChannelMemoryOffset = 3072;
  for (int i = 0; i < 1000; i++) {
      BrokenBytes[0] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      BrokenBytes[1] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      BrokenBytes[2] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      BrokenBytes[3] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      CustomTrain1[i] = makeLong(BrokenBytes[3], BrokenBytes[2], BrokenBytes[1], BrokenBytes[0]);
  }
  ChannelMemoryOffset = 7200;
  for (int i = 0; i < 1000; i++) {
      BrokenBytes[0] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      BrokenBytes[1] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      BrokenBytes[2] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      BrokenBytes[3] = ReadEEPROM(ChannelMemoryOffset); ChannelMemoryOffset++;
      CustomTrain2[i] = makeLong(BrokenBytes[3], BrokenBytes[2], BrokenBytes[1], BrokenBytes[0]);
  }
}

void WipeEEPROM() {
  write2Screen("Clearing Memory"," ");
  for (int i = 0; i < 32; i++) {
  PageBytes[i] = 0;
  }
  int WritePagePosition = 0;
  for (int i = 0; i < 512; i++) {
    WriteEEPROMPage(PageBytes, 32, WritePagePosition);
    WritePagePosition = WritePagePosition + 32;
  }
  write2Screen("Clearing Memory","     DONE! ");
  delay(1000);
  write2Screen(" PULSE PAL v0.4"," Click for menu");
}
