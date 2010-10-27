/*
arduino serial-i2c-gateway, by michael vogt / neophob.com 2010
published as i-dont-give-a-shit-about-any-license

based on blinkm firmware by thingM and
"daft punk" firmware by Scott C / ThreeFN 

needed libraries:
 -FlexiTimer (http://github.com/wimleers/flexitimer2)
 
libraries to patch:
 Wire: 
 	utility/twi.h: #define TWI_FREQ 400000L (was 100000L)
                       #define TWI_BUFFER_LENGTH 98 (was 32)
 	wire.h: #define BUFFER_LENGTH 98 (was 32)
 
 
 TODO: add maybe i2c scanner (http://todbot.com/arduino/sketches/I2CScanner/I2CScanner.pde)
 	
*/


#include <Wire.h>
#include <FlexiTimer2.h>
#include "Rainbow.h"

/*
A variable should be declared volatile whenever its value can be changed by something beyond the control 
of the code section in which it appears, such as a concurrently executing thread. In the Arduino, the 
only place that this is likely to occur is in sections of code associated with interrupts, called an 
interrupt service routine.
*/
extern unsigned char buffer[2][3][8][4];  //define Two Buffs (one for Display ,the other for receive data)
unsigned char imageBuffer[96];

//volatile 
byte line,level;

//read from bufCurr, write to !bufCurr
//volatile mess everything up now, why?
byte bufCurr, swapNow;
byte readI2c,i;

#define START_OF_DATA 0x10
#define END_OF_DATA 0x20

void setup() {
  readI2c=0;
  DDRD=0xff;        // Configure ports (see http://www.arduino.cc/en/Reference/PortManipulation): digital pins 0-7 as OUTPUT
  DDRC=0xff;        // analog pins 0-5 as OUTPUT
  DDRB=0xff;        // digital pins 8-13 as OUTPUT
  PORTD=0;          // Configure ports data register (see link above): digital pins 0-7 as READ
  PORTB=0;          // digital pins 8-13 as READ

  level = 0;
  line = 0;

  bufCurr = 0;
  swapNow = 0;

  Wire.begin(I2C_DEVICE_ADDRESS); // join i2c bus (address optional for master) 
  Wire.onReceive(receiveEvent); // define the receive function for receiving data from master

  //calculate: 64(256-GAMMA)/16000000 = x;  
  //gamma 200(0xc8): 0.000224  -> flimmert
  //gamma 215(0xd7): 0.000164  -> leichtes flimmern
  //gamma 221(0xdd): 0.00014   -> original
  //gamma 231(0xe7): 0.0001    -> original 
  //gamma 240(0xf0): 0.000064  -> wie original
  //gamma 250(0xfa): 0.000024  -> does not work
  //10kHz resolution
  FlexiTimer2::set(1, 0.0001, displayNextLine);
  FlexiTimer2::start();
}

void loop() {
  uint8_t b;
  delayMicroseconds(10);
  
  //check if buffer is filled, 96b image + 1b start marker + 1b end marker = 98b 
  if (readI2c>97) { 
    readI2c-=98;
    //read header, wait until we get a START_OF_DATA or queue is empty
    i=0;
    while (Wire.available()>0 && i==0) {
      b = Wire.receive();
      if (b == START_OF_DATA) {
        i=1;
      }
    }
    
    if (i==0) {
      //error, missing START_OF_DATA marker
      return;
    }
  
    i=0;
    while (Wire.available()>0 && i<96) { 
      imageBuffer[i]=Wire.receive();  //recieve whatever is available
      i++;
    }
    
    //check footer
    b=0;
    if (Wire.available()>0) {
      b = Wire.receive();      
    }
    
    if (b == END_OF_DATA) {
      DispshowFrame();
    } else {
      //error, try to read data until eod marker if possible
      while (Wire.available()>0 && i==0) {
        b = Wire.receive();
        if (b == END_OF_DATA) {
          i=1;
        }
      }

    }
  }
}

//============INTERRUPTS======================================

//shift out led colors
void displayNextLine() {
  flash_next_line(line, level);  // scan the next line in LED matrix level by level.
  line++;
  if(line>7)        // when have scaned all LED's, back to line 0 and add the level
  {
    line=0;
    level++;
    if(level>15) {
      level=0;
      //SWAP buffer
      if (swapNow==1) {
        bufCurr = !bufCurr;			// do the actual swapping, synced with display refresh.
      }
    }
  }
}

//=============HANDLERS======================================

//get data from master
//HINT: do not handle stuff here!! this will NOT work
//collect only data here and process it in the main loop!
void receiveEvent(int numBytes) {
  readI2c+=numBytes;
}


//==============DISPSHOW========================================
void DispshowFrame(void) {
  unsigned char color,row,dots,ofs;

  ofs=0;
  for(color=0;color<3;color++) {
    for (row=0;row<8;row++) {
      for (dots=0;dots<4;dots++) {
        //format: 32b G, 32b R, 32b B
        buffer[!bufCurr][color][row][dots]=imageBuffer[ofs++];  //get byte info for two dots directly from command
      }
    }
  }
  swapNow = 1;			//set the flag to swap buffers
}

//==============================================================
void shift_1_bit(unsigned char LS)  //shift 1 bit of 1 Byte color data into Shift register by clock
{
  if(LS)
  {
    shift_data_1;
  }
  else
  {
    shift_data_0;
  }
  clk_rising;
}
//==============================================================
void flash_next_line(unsigned char line,unsigned char level) // scan one line
{
  disable_oe;
  close_all_line;
  //open_line(line);
  //TODO    
  if(line < 3) {    // Open the line and close others
   PORTB  = (PINB & ~0x07) | 0x04 >> line;
   PORTD  = (PIND & ~0xF8);
   } else {
   PORTB  = (PINB & ~0x07);
   PORTD  = (PIND & ~0xF8) | 0x80 >> (line - 3);
   }
   
  shift_24_bit(line,level);
  enable_oe;
}

//==============================================================
void shift_24_bit(unsigned char line, unsigned char level)   // display one line by the color level in buff
{
  unsigned char color,row,data0,data1;
  le_high;
  for (color=0;color<3;color++)//GRB
  {
    for (row=0;row<4;row++)
    {
      data1=buffer[bufCurr][color][line][row]&0x0f;
      data0=buffer[bufCurr][color][line][row]>>4;
/*
      if(data0>level)   //gray scale,0x0f aways light
      {
        shift_1_bit(1);
      }
      else
      {
        shift_1_bit(0);
      }

      if(data1>level)
      {
        shift_1_bit(1);
      }
      else
      {
        shift_1_bit(0);
      }*/
      if(data0>level) {    //gray scale, 0x0f aways light (original comment, not sure what it means)
        shift_data_1;
        clk_rising;
      } else {
        shift_data_0;
        clk_rising;
      }
      
      if(data1>level) {
        shift_data_1;
        clk_rising;
      } else {
        shift_data_0;
        clk_rising;
      }
    }
  }
  le_low;
}



//==============================================================
void open_line(unsigned char line)     // open the scaning line 
{
  switch(line)
  {
  case 0:
    {
      open_line0;
      break;
    }
  case 1:
    {
      open_line1;
      break;
    }
  case 2:
    {
      open_line2;
      break;
    }
  case 3:
    {
      open_line3;
      break;
    }
  case 4:
    {
      open_line4;
      break;
    }
  case 5:
    {
      open_line5;
      break;
    }
  case 6:
    {
      open_line6;
      break;
    }
  case 7:
    {
      open_line7;
      break;
    }
  }
}



