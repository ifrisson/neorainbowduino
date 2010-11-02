#ifndef Rainbow_h
#define Rainbow_h

//Address of the device. Note: this must be changed and compiled for all unique Rainbowduinos
#define I2C_DEVICE_ADDRESS 0x06

//=============================================
#define SH_BIT_OE    0x08
#define SH_BIT_SDI   0x01
#define SH_BIT_CLK   0x02
#define SH_BIT_LE    0x04

//PORTC maps to Arduino analog pins 0 to 5. Pins 6 & 7 are only accessible on the Arduino Mini
//PORTC - The Port C Data Register - read/write
#define SH_PORT_OE   PORTC
#define SH_PORT_SDI  PORTC
#define SH_PORT_CLK  PORTC
#define SH_PORT_LE   PORTC
//============================================

//some handy hints, ripped form the arduino forum
//Setting a bit: byte |= 1 << bit;
//Clearing a bit: byte &= ~(1 << bit);
//Toggling a bit: byte ^= 1 << bit;
//Checking if a bit is set: if (byte & (1 << bit))
//Checking if a bit is cleared: if (~byte & (1 << bit)) OR if (!(byte & (1 << bit)))

#define clk_rising  {SH_PORT_CLK&=~SH_BIT_CLK;SH_PORT_CLK|=SH_BIT_CLK;}
#define le_high     {SH_PORT_LE|=SH_BIT_LE;}
#define le_low      {SH_PORT_LE&=~SH_BIT_LE;}
#define enable_oe   {SH_PORT_OE&=~SH_BIT_OE;}
#define disable_oe  {SH_PORT_OE|=SH_BIT_OE;}

#define shift_data_1     {SH_PORT_SDI|=SH_BIT_SDI;}
#define shift_data_0     {SH_PORT_SDI&=~SH_BIT_SDI;}
//============================================
/*#define open_line0	{PORTB=0x04;}
#define open_line1	{PORTB=0x02;}
#define open_line2	{PORTB=0x01;}
#define open_line3	{PORTD=0x80;}
#define open_line4	{PORTD=0x40;}
#define open_line5	{PORTD=0x20;}
#define open_line6	{PORTD=0x10;}
#define open_line7	{PORTD=0x08;}*/
#define close_all_line	{PORTD&=~0xf8;PORTB&=~0x07;}

#endif