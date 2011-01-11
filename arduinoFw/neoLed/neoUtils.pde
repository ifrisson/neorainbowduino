extern "C" { 
#include "utility/twi.h"  // from Wire library, so we can do bus scanning
}

//Static start+end address for i2x scan
#define START_I2C_SCAN 1
#define END_I2C_SCAN 101

//I2C definitions
#define START_OF_DATA 0x10
#define END_OF_DATA 0x20

#define CLEARCOL 51 //00110011

//some magic numberes
#define CMD_START_BYTE  0x01
#define CMD_SENDFRAME 0x03
#define CMD_PING  0x04
#define CMD_INIT_RAINBOWDUINO 0x05
#define CMD_SCAN_I2C_BUS 0x06

//8ms is the minimum!
#define SERIAL_WAIT_TIME_IN_MS 8


//process the serial data (send images..)
void processSerialData() {
  //i2c addres of device
  byte addr    = serInStr[1];
  //how many bytes we're sending
  byte sendlen = serInStr[2];
  //what kind of command we send
  byte type = serInStr[3];
  //parameter
  byte* cmd    = serInStr+5;

  switch (type) {
    case CMD_SENDFRAME:
    	//the size of an image must be exactly 96 bytes
        if (sendlen!=96) {
          g_errorCounter=100;
        } else {
          g_errorCounter = BlinkM_sendBuffer(addr, cmd);    
        }
        break;
    case CMD_PING:
        //just send the ack!
        break;
    case CMD_INIT_RAINBOWDUINO:
        //send initial image to rainbowduino
        g_errorCounter = send_initial_image(addr);
        break;
    case CMD_SCAN_I2C_BUS:
    	scanI2CBus();
    	break;
    default:
        //invalid command
        g_errorCounter=130; 
        break;
  }
        
  //send ack to library - command processed
  sendAck();
}

// ripped from http://todbot.com/arduino/sketches/I2CScanner/I2CScanner.pde
// Scan the I2C bus between addresses from_addr and to_addr.
// On each address, call the callback function with the address and result.
// If result==0, address was found, otherwise, address wasn't found
// (can use result to potentially get other status on the I2C bus, see twi.c)
// Assumes Wire.begin() has already been called
// HINT: maximal 14 devices can be scanned!
void scanI2CBus() {
  memset(serialResonse, 255, SERIALBUFFERSIZE);
  serialResonse[0] = CMD_START_BYTE;
  serialResonse[1] = CMD_SCAN_I2C_BUS;

  byte rc,i=2;
  byte data = 0; // not used, just an address to feed to twi_writeTo()
  for (byte addr = START_I2C_SCAN; addr <= END_I2C_SCAN; addr++) {
  //rc 0 = success
    digitalWrite(13, HIGH);
    rc = twi_writeTo(addr, &data, 0, 1);
    digitalWrite(13, LOW);
    if (rc==0) {
      serialResonse[i]=addr;
      if (i<SERIALBUFFERSIZE) i++;
    }
    delayMicroseconds(64);
  }
  Serial.write(serialResonse, SERIALBUFFERSIZE);
  memset(serialResonse, 0, SERIALBUFFERSIZE);
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
byte readCommand(byte *str) {
  byte b,i,sendlen;

  //wait until we get a CMD_START_BYTE or queue is empty
  i=0;
  while (Serial.available()>0 && i==0) {
    b = Serial.read();
    if (b == CMD_START_BYTE) {
      i=1;
    }
  }

  if (i==0) {
    //failed to get data
    g_errorCounter=101;
    return 0;    
  }

//read header  
  i = SERIAL_WAIT_TIME_IN_MS;
  while (Serial.available() < HEADER_SIZE-1) {   // wait for the rest
    delay(1); 
    if (i-- == 0) {
      g_errorCounter=102;
      return 0;        // get out if takes too long
    }
  }
  for (i=1; i<HEADER_SIZE; i++) {
    str[i] = Serial.read();       // fill it up
  }
  
// --- START HEADER CHECK    
  //check if data is correct, 0x10 = START_OF_DATA
  if (str[4] != START_OF_DATA) {
    g_errorCounter=104;
    return 0;
  }
  
  //check sendlen, its possible that sendlen is 0!
  sendlen = str[2];
// --- END HEADER CHECK

  
//read data  
  i = SERIAL_WAIT_TIME_IN_MS;
  // wait for the final part, +1 for END_OF_DATA
  while (Serial.available() < sendlen+1) {
    delay(1); 
    if( i-- == 0 ) {
      g_errorCounter=105;
      return 0;
    }
  }

  for (i=HEADER_SIZE; i<HEADER_SIZE+sendlen+1; i++) {
    str[i] = Serial.read();       // fill it up
  }

  //check if data is correct, 0x20 = END_OF_DATA
  if (str[HEADER_SIZE+sendlen] != END_OF_DATA) {
    g_errorCounter=106;
    return 0;
  }

  //return data size (without meta data)
  return sendlen;
}


//send status back to library
static void sendAck() {
  serialResonse[0] = 'A';
  serialResonse[1] = 'K';
  serialResonse[2] = Serial.available();
  serialResonse[3] = g_errorCounter;  
  Serial.write(serialResonse, 4);

  //Clear bufer
 // Serial.flush();
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

  //buffer layout: 32b RED, 32b GREEN, 32b BLUE
  int ofs=0;
  for (int i=0; i<tail2; i++) {
    serInStr[ofs++]=255;
  }
  if (useTail) {
    serInStr[ofs++]=243;
  }
  
  return BlinkM_sendBuffer(i2caddr, serInStr);
}



//send data via I2C to a client
static byte BlinkM_sendBuffer(byte addr, byte* cmd) {
    Wire.beginTransmission(addr);
    Wire.send(START_OF_DATA);
    Wire.send(cmd, 96);
    Wire.send(END_OF_DATA);
    return Wire.endTransmission();
}

