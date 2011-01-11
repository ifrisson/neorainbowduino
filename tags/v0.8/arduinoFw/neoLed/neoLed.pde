/*
 * arduino serial-i2c-gateway, Copyright (C) 2010 michael vogt <michu@neophob.com>
 *  
 * based on 
 * -blinkm firmware by thingM
 * -"daft punk" firmware by Scott C / ThreeFN 
 *  
 * libraries to patch:
 * Wire: 
 *  	utility/twi.h: #define TWI_FREQ 400000L (was 100000L)
 *                    #define TWI_BUFFER_LENGTH 98 (was 32)
 *  	wire.h: #define BUFFER_LENGTH 98 (was 32)
 *
 * This file is part of neorainbowduino.
 *
 * neorainbowduino is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * neorainbowduino is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 * 	
 */
#include <Wire.h>
#include "WProgram.h"

//to draw a frame we need arround 20ms to send an image. the serial baudrate is
//NOT the bottleneck. 
#define BAUD_RATE 115200


//this should match RX_BUFFER_SIZE from HardwareSerial.cpp
byte serInStr[128]; 	 				 // array that will hold the serial input string

//counter for 2000 frames
//http://www.ftdichip.com/Support/Documents/AppNotes/AN232B-04_DataLatencyFlow.pdf
//there is a 16ms delay until the buffer is full, here are some measurements
//time is round trip time from/to java
//size  errorrate       frames>35ms  time for 2000frames  time/frame  time/frame worstcase
//5  -> rate: 0.0,      long: 156,   totalTime: 44250     22.13ms
//8  -> rate: 5.894106, long: 38,    totalTime: 41184     20.59ms     21.83ms
//16 -> rate: 7.092907, long: 4,     totalTime: 40155     20.07ms     21.48ms
//32 -> rate: 6.943056, long: 5,     totalTime: 39939     19.97ms     21.36ms
//62 -> rate: 22.97702, long: 7,     totalTime: 33739     16.89ms     20.58ms
//64 -> rate: 24.22577, long: 3,     totalTime: 33685     16.84ms     20.89ms
//-> I use 16b - not the fastest variant but more accurate

#define SERIALBUFFERSIZE 16
byte serialResonse[SERIALBUFFERSIZE];

byte g_errorCounter;


void setup() {
  Wire.begin(1); // join i2c bus (address optional for master)
  
  pinMode(13, OUTPUT);
  memset(serialResonse, 0, SERIALBUFFERSIZE);

  //im your slave and wait for your commands, master!
  Serial.begin(BAUD_RATE); //Setup high speed Serial
  Serial.flush();
}


void loop() {
  //read the serial port and create a string out of what you read
  g_errorCounter=0;

  digitalWrite(13, LOW);
  // see if we got a proper command string yet
  if (readCommand(serInStr) == 0) {
    //no valid data found
    //sleep for 250us
    delayMicroseconds(250);
    return;
  }
  
  digitalWrite(13, HIGH);
  processSerialData();
    
}







