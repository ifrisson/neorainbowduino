import processing.serial.*;
import com.neophob.lib.rainbowduino.*;

//the rainbowduino device
Rainbowduino rainbowduino;

//buffer for our image data, must be 8*8 pixel
int[] simpleImage;

void setup() 
{
  frameRate(5);
  simpleImage = new int[64];
  
  //initialize library
  rainbowduino = new Rainbowduino(this);
  
  //create a list with i2c slave destination (=rainbowduinos)
  List<Integer> i2cDest = new ArrayList<Integer>();
  i2cDest.add(6);
  try {
    //let the library search all available serial ports and try to send
    //the initialize image to all slaves
    rainbowduino.initPort(i2cDest);
  } catch (Exception e) {
    //if an error occours handle it here!
    //we just print out the stacktrace and exit.
    e.printStackTrace();
    println("failed to initialize serial port - exit!");
    exit();
  }

  //load+resize image
  PImage pimage = loadImage("hsv.jpg");
  //hint: this function is still buggy!
  //check Issue 332: PImage resize is not pretty
  pimage.resize(8, 8);
  
  //get image data
  pimage.loadPixels();
  System.arraycopy(pimage.pixels, 0, simpleImage, 0, 8*8);
  pimage.updatePixels();

  rainbowduino.sendRgbFrame((byte)6, simpleImage);
}

void draw()
{
}
