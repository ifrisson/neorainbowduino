//arduino serial-i2c-gateway, by michael vogt / neophob.com 2010
//published as i-dont-give-a-shit-about-any-license 
//you need the MsTime2 library, check http://www.arduino.cc/playground/Main/MsTimer2
#include <MsTimer2.h>
#include "Wire.h"
#include "BlinkM_funcs.h"

#define BAUD_RATE 57600
//115200

#define CLEARCOL 51 //00110011

//some magic numberes
#define CMD_START_BYTE  0x01
#define CMD_PING  0x04
#define CMD_HEARTBEAT 0x10
#define START_OF_DATA 0x10;
#define END_OF_DATA 0x20;

#define SERIAL_WAIT_TIME_IN_MS 20

//this should match RX_BUFFER_SIZE from HardwareSerial.cpp
byte serInStr[128];  // array that will hold the serial input string
byte errorCounter;
byte send[4];

static void sendSerialResponse(byte command, byte param) {
  send[0]=OK;
  send[1]=command;
  send[2]=param;
  send[3]=Serial.available();
  Serial.write(send, 4);
}

//send heartbeat command to host and reset the error counter
//save the error counter on the host side!
void heartbeat() {
  digitalWrite(13, HIGH);
  sendSerialResponse(CMD_HEARTBEAT, errorCounter);
  errorCounter=0;
  digitalWrite(13, LOW);
}

//send an white image to the target rainbowduino
//contains red led's which describe its i2c addr
int send_initial_image(byte i2caddr) {
  
  //clear whole buffer
  memset(serInStr, CLEARCOL, 128);

  //draw i2c addr as led pixels
  float tail = i2caddr/2.0f;
  int tail2 = (int)(tail);
  boolean useTail = (tail-(int)(tail))!=0;			

  //buffer: 32b RED, 32b GREEN, 32b BLUE
  int ofs=0;
  for (int i=0; i<tail2; i++) {
    serInStr[ofs++]=255;
  }
  if (useTail) {
    serInStr[ofs++]=243;
  }
  
  return BlinkM_sendBuffer(i2caddr, serInStr);
}

void setup() {
  errorCounter=0;

  Wire.begin(); // join i2c bus (address optional for master)
  //clear both rainbowduinos - 
  //hint init will fail if both rainbowduinos are not available!
  errorCounter+=send_initial_image(0x06);
  errorCounter+=send_initial_image(0x05);

  pinMode(13, OUTPUT);

  //im your slave and wait for your commands, master!
  Serial.begin(BAUD_RATE); //Setup high speed Serial
  Serial.flush();

  //do not send serial data too often
  MsTimer2::set(3000, heartbeat); // 3000ms period
  MsTimer2::start();
}

void loop()
{
  //read the serial port and create a string out of what you read
  
  // see if we got a proper command string yet
  if (readCommand(serInStr) == 0) {
    delay(10); 
    return;
  }

  //i2c addres of device
  byte addr    = serInStr[1];
  //how many bytes we're sending
  byte sendlen = serInStr[2];
  //what kind of command we send
  byte type = serInStr[3];
  //parameter
  byte* cmd    = serInStr+5;

  if (type == CMD_PING) {
    //simple ardiumo ping
    sendSerialResponse(CMD_PING, 0); 
  } 
  else {
    //else its a frame, a frame need 96 bytes
    if (sendlen!=96) {
      errorCounter++;
      return;
    }
    errorCounter += BlinkM_sendBuffer(addr, cmd);
  }    

}


//read a string from the serial and store it in an array
//you must supply the str array variable
//returns number of bytes read, or zero if fail
/* example ping command:
		cmdfull[0] = START_OF_CMD (marker);
		cmdfull[1] = addr;
		cmdfull[2] = 0x01; 
		cmdfull[3] = CMD_PING;
		cmdfull[4] = START_OF_DATA (marker);
		cmdfull[5] = 0x02;
		cmdfull[6] = END_OF_DATA (marker);
*/
#define HEADER_SIZE 5
uint8_t readCommand(byte *str)
{
  uint8_t b,i,sendlen;

  //wait until we get a CMD_START_BYTE or queue is empty
  i=0;
  while (Serial.available()>0 && i==0) {
    b = Serial.read();
    if (b == CMD_START_BYTE) {
      i=1;
    }
  }

  if (i==0) {
    errorCounter++;
    return 0;    
  }

//read header  
  i = SERIAL_WAIT_TIME_IN_MS;
  while (Serial.available() < HEADER_SIZE-1) {   // wait for the rest
    delay(1); 
    if( i-- == 0 ) {
      errorCounter++;
      return 0;        // get out if takes too long
    }
  }
  for (i=1; i<HEADER_SIZE; i++)
    str[i] = Serial.read();       // fill it up
  
  //check sendlen
  sendlen = str[2];
  if( sendlen == 0 ) {
    errorCounter++;
    return 0;
  }
  
  //check if data is correct, 0x10 = START_OF_DATA
  b = str[4];
  if ( b != 0x10 ) {
    errorCounter++;
    return 0;
  }
  
//read data  
  i = SERIAL_WAIT_TIME_IN_MS;
  // wait for the final part, +1 for END_OF_DATA
  while (Serial.available() < sendlen+1) {
    delay(1); 
    if( i-- == 0 ) {
      errorCounter++;
      return 0;
    }
  }

  for (i=HEADER_SIZE; i<HEADER_SIZE+sendlen+1; i++) 
    str[i] = Serial.read();       // fill it up

  //check if data is correct, 0x20 = END_OF_DATA
  b = str[HEADER_SIZE+sendlen];
  if( b != 0x20 ) {
    errorCounter++;
    return 0;
  }
  //return data size (without meta data)
  return sendlen;
}


