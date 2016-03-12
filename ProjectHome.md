## NEWS (26 April 2013) ##
A new project to control multiple Rainbowduinos v3 with a RPI. See https://github.com/neophob/udp-to-i2c for documentation. More details soon (I hope).

## Important ##

I will not update this project anymore because I created a successor called **PixelInvaders**. Check
  * http://pixelinvaders.ch to **see** my new created panels **in action**
  * check https://github.com/neophob/PixelController to see the **controlling software**

## Info ##

Some of the neorainbowduino v0.8 features:
  * Multiple Rainbowduinos supported via i2c protocol
  * Running fast and stable, you need about 20ms are needed to send a frame from Processing/Java to an Rainbowduino matrix
  * A **[Processing](http://www.processing.org) library**, so you can easily control your Rainbowduino from Processing! Check http://www.neophob.com/neorainbowduino for a description of the library.
  * Send frames from Processing to your RGB matrix, each frame has a size of 8x8 pixel, 12bit color resolution (4096 colors). The color conversion is handled by the library
  * Optimized processing lib - send only frames to Rainbowduino if needed (save ~50% of traffic - of course it depends on your frames)
  * Fixed buffer swapping (no more flickering)
  * Check if Arduino is ready (ping arduino)
  * Added i2c bus scanner, find your Rainbowduinos if you forget their addresses


More information:
  * http://www.neophob.com/2010/09/neorainbowduino-processing-library
  * http://www.neophob.com/2010/07/rainbowduino-fun-aka-neorainbowduino
  * http://garden.seeedstudio.com/index.php?title=Rainbowduino_LED_driver_platform_-_Atmega_328

## Install ##

### Needed libraries ###
  * FlexiTimer (http://github.com/wimleers/flexitimer2)

### Libraries to patch ###
Wire (TWI/I2C):
```
utility/twi.h:
     #define TWI_FREQ 400000L (was 100000L)
     #define TWI_BUFFER_LENGTH 98 (was 32)

wire.h: 
     #define BUFFER_LENGTH 98 (was 32)
```

**Hint:** make sure that the Arduino ide is NOT running while you patch the files!


## Step by Step ##
  * Make sure you installed the needed libs and patched your Arduino installation
  * Upload firmware to one or more Rainbowduinos. If you're uploading to multiple Rainbowduinos, make sure to change the I2C adress for each Rainbowduino. **Hint:** make sure you first upload an empty sketch to the Arduino - else the upload to the Rainbowduinos may not work!
  * Upload firmware to Arduino
  * Wire up (I2C from Arduino to Rainbowduinos, Power... Check blog entry for more information)
  * Install Processing library (see below)
  * Start an example sketch - check if the I2C slave address match your Rainbowduinos.

### Install Processing libraries ###
the zip file you downloaded contains 3 main directories (and the directory name should be self explaining):
  * arduinoFw
  * processingLib
  * rainbowduinoFw

You can find the processing library in the **processingLib\distribution\neorainbowduino-x.y\download** directory. In this directory you'll find the processing library as zip file, containing an INSTALL.txt file. for your viewing pleasure here is a copy of it:
```
How to install library neorainbowduino 

Contributed libraries must be downloaded separately and placed within 
the "libraries" folder of your Processing sketchbook. To find the Processing 
sketchbook location on your computer, open the Preferences window from the 
Processing application and look for the "Sketchbook location" item at the top. 

Copy the contributed library's folder into the "libraries" folder at this location. 
You will need to create the "libraries" folder if this is your first contributed library. 

By default the following locations are used for your sketchbook folder.
For mac users the sketchbook folder is located inside ~/Documents/Processing. 
for windows users the sketchbook folder is located inside folder 'My Documents'/Processing

The folder structure for library neorainbowduino should be as follows

Processing
  libraries
    neorainbowduino
      examples
      library
        neorainbowduino.jar
      reference
      src
                      
                      
After library neorainbowduino has been successfully installed, restart processing.                    
```
