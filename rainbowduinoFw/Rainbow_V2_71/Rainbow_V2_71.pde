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
 	
 */

//#define TWI_BUFFER_LENGTH 98

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
unsigned char imageBuffer[96];            //buffer used to read data from i2c bus

//interrupt variables
byte g_line,g_level;

//read from bufCurr, write to !bufCurr
//volatile   //the display is flickerling, brightness is reduced
byte g_bufCurr;
byte interlace=0; 

//flag to blit image
volatile byte g_swapNow;
//volatile byte g_doNotDraw;

//hold the number of availble bytes in the i2c buffer
volatile byte g_readI2c;


#define START_OF_DATA 0x10
#define END_OF_DATA 0x20

void setup() {
  DDRD=0xff;        // Configure ports (see http://www.arduino.cc/en/Reference/PortManipulation): digital pins 0-7 as OUTPUT
  DDRC=0xff;        // analog pins 0-5 as OUTPUT
  DDRB=0xff;        // digital pins 8-13 as OUTPUT
  PORTD=0;          // Configure ports data register (see link above): digital pins 0-7 as READ
  PORTB=0;          // digital pins 8-13 as READ

  g_level = 0;
  g_line = 0;
  g_bufCurr = 0;
  g_swapNow = 0; 
  g_readI2c = 0;
  //  g_doNotDraw = 0;

  Wire.begin(I2C_DEVICE_ADDRESS); // join i2c bus as slave
  Wire.onReceive(receiveEvent);   // define the receive function for receiving data from master

  //10kHz resolution (PWM)
  FlexiTimer2::set(1, 1.0f/(128.0f*80), displayNextLine);
  //  FlexiTimer2::set(1, 1.0f/10000.0f, displayNextLine);
  FlexiTimer2::start();                            //start interrupt code
}

//the mainloop - try to fetch data from the i2c bus and copy it into our buffer
void loop() {
  byte b,i;

  if (g_readI2c>97) { 
    b = Wire.receive();
    g_readI2c--;
    if (b != START_OF_DATA) {
      //handle error, read remaining data until end of data marker
      while (Wire.available()>0 && Wire.receive()!=END_OF_DATA) {}
      g_readI2c=0;
      return;
    }

    //read image data
    i=0;
    while (Wire.available()>0 && i<96) { 
      imageBuffer[i++]=Wire.receive();  //recieve whatever is available
      g_readI2c--;
    }

    //read end of data marker
    b=0;
    if (Wire.available()>0) {
      b = Wire.receive();  
      g_readI2c--;
    }

    //if the receieved data looks good - copy it into backBuffer
    if (b == END_OF_DATA) {
      DispshowFrame();
    } 

  }
}



//=============HANDLERS======================================

//get data from master - HINT: this is a ISR call!
//HINT2: do not handle stuff here!! this will NOT work
//collect only data here and process it in the main loop!
void receiveEvent(int numBytes) {
  g_readI2c+=numBytes;
}


//==============DISPSHOW========================================

//copy data from the i2c bus into backbuffer and set the g_swapNow flag
void DispshowFrame(void) {
  byte color,row,dots,ofs;

  //this is not needed, as the swapping is done much faster!
  //do not fill buffer if we still wait for the blit!
  //if (g_swapNow==1) {
  //  return;
  //}

  ofs=0;
  for (color=0;color<3;color++) {
    for (row=0;row<8;row++) {
      for (dots=0;dots<4;dots++) {
        //format: 32b G, 32b R, 32b B
        buffer[g_bufCurr][color][row][dots]=imageBuffer[ofs++];  //get byte info for two dots directly from command
      }
    }
  }

  //set the 'we need to blit' flag
  g_swapNow = 1;
}


//============INTERRUPTS======================================

// shift out led colors and swap buffer if needed (back buffer and front buffer) 
// function: draw whole image for brightness 0, then for brightness 1... this will 
//           create the brightness effect. 
//           so this interrupt needs to be called 128 times to draw all pixels (8 lines * 16 brightness levels) 
//           using a 10khz resolution means, we get 10000/128 = 78.125 frames/s 
void displayNextLine() { 
  //  if (g_doNotDraw == 1) return;
  flash_next_line();  // scan the next line in LED matrix level by level. 
  g_line+=2;                                                      // process all 8 lines of the led matrix 
  if(g_line>7) {                                 // when have scaned all LED's, back to line 0 and add the level 
//    g_line=0; 
    g_line=interlace;
    g_level++;                                           // g_level controls the brightness of a pixel. 
    if (g_level>15) {                            // there are 16 levels of brightness (4bit) * 3 colors = 12bit resolution
      g_level=0; 
    } 
  } 

  //check the whole buffer is painted 
  if (g_level==0 && g_line==0) { 
    interlace=!interlace; 
    //SWAP buffer if requested 
    if (g_swapNow==1) { 
      g_bufCurr = !g_bufCurr; 
      g_swapNow=0; 
    } 
  } 
}


// scan one line
void flash_next_line() {
  disable_oe;
  close_all_line;
  shift_24_bit();

  //open_line(line);
  if(g_line < 3) {    // Open the line and close others
    PORTB  = (PINB & ~0x07) | 0x04 >> g_line;
    PORTD  = (PIND & ~0xF8);
  } 
  else {
    PORTB  = (PINB & ~0x07);
    PORTD  = (PIND & ~0xF8) | 0x80 >> (g_line - 3);
  }

  enable_oe;
}

// display one line by the color level in buff
void shift_24_bit() { 
  byte color,row,data0,data1; 
  le_high; 
  for (color=0;color<3;color++)//GRB 
  { 
    for (row=0;row<4;row++) { 
/*      if (interlace) { 
        data1=buffer[g_bufCurr][color][g_line][row]&0x0f; 
        //process second led      
        if(data1>g_level) { 
          shift_data_1; 
          clk_rising;        //TODO: document 
        } 
        else { 
          shift_data_0; 
          clk_rising; 
        } 
      } 
      else { 
        data0=buffer[g_bufCurr][color][g_line][row]>>4; 
        if(data0>g_level) { 
          shift_data_1; 
          clk_rising; 
        } 
        else { 
          shift_data_0; 
          clk_rising; 
        } 
      }
      clk_rising;  */
      data1=buffer[g_bufCurr][color][g_line][row]&0x0f;
      data0=buffer[g_bufCurr][color][g_line][row]>>4;

      if(data0>g_level) {    //gray scale, 0x0f aways light (original comment, not sure what it means)
        shift_data_1;
        clk_rising;
      } else {
        shift_data_0;
        clk_rising;
      }
      
      if(data1>g_level) {
        shift_data_1;
        clk_rising;        //TODO: document
      } else {
        shift_data_0;
        clk_rising;
      }      
    } 
  } 

  le_low; 
}



