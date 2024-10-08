/*
 * Simple Open Pixel Control client for Processing,
 * designed to sample each LED's color from some point on the canvas.
 *
 * Micah Elizabeth Scott, 2013
 * This file is released into the public domain.
 */

//import java.net.*;
import java.util.Arrays;
import ch.bildspur.artnet.*;
import ch.bildspur.artnet.packets.*;
import ch.bildspur.artnet.events.*;

public class ARTNET
{
  //Socket socket;
  
  OutputStream output, pending;
  //DatagramSocket udpsock;
  //InetAddress wledaddress;
  String host;
  int start_universe;
  int start_channel;
  ArtNetClient artnet;
  int[] pixelLocations;
  byte[] packetData;
  byte[][] dmxData;
  byte firmwareConfig;
  String colorCorrection;
  boolean enableShowLocations;

  ARTNET(PApplet parent, String host, int start_universe, int start_channel)
  {
    this.host = host;
    this.start_universe = start_universe;
    this.start_channel = start_channel;
    this.enableShowLocations = true;
    parent.registerMethod("draw", this);
    //try{
    //  udpsock = new DatagramSocket();
    //}catch(Exception e){println("Failed to Open WLED Socket",e);}
    //try{
     // wledaddress = InetAddress.getByName(host);
    //}catch(Exception e){println("DNS lookup failed for ",host,e);}
    artnet = new ArtNetClient(null);
    artnet.start();
    
    
    
  }

  // Set the location of a single LED
  void led(int index, int x, int y)  
  {
    // For convenience, automatically grow the pixelLocations array. We do want this to be an array,
    // instead of a HashMap, to keep draw() as fast as it can be.
    if (pixelLocations == null) {
      pixelLocations = new int[index + 1];
    } else if (index >= pixelLocations.length) {
      pixelLocations = Arrays.copyOf(pixelLocations, index + 1);
    }

    pixelLocations[index] = x + width * y;
  }
  
  // Set the location of several LEDs arranged in a strip.
  // Angle is in radians, measured clockwise from +X.
  // (x,y) is the center of the strip.
  void ledStrip(int index, int count, float x, float y, float spacing, float angle, boolean reversed)
  {
    float s = sin(angle);
    float c = cos(angle);
    for (int i = 0; i < count; i++) {
      led(reversed ? (index + count - 1 - i) : (index + i),
        (int)(x + (i - (count-1)/2.0) * spacing * c + 0.5),
        (int)(y + (i - (count-1)/2.0) * spacing * s + 0.5));
    }
  }

  // Set the locations of a ring of LEDs. The center of the ring is at (x, y),
  // with "radius" pixels between the center and each LED. The first LED is at
  // the indicated angle, in radians, measured clockwise from +X.
  void ledRing(int index, int count, float x, float y, float radius, float angle)
  {
    for (int i = 0; i < count; i++) {
      float a = angle + i * 2 * PI / count;
      led(index + i, (int)(x - radius * cos(a) + 0.5),
        (int)(y - radius * sin(a) + 0.5));
    }
  }

  // Set the location of several LEDs arranged in a grid. The first strip is
  // at 'angle', measured in radians clockwise from +X.
  // (x,y) is the center of the grid.
  void ledGrid(int index, int stripLength, int numStrips, float x, float y,
               float ledSpacing, float stripSpacing, float angle, boolean zigzag)
  {
    float s = sin(angle + HALF_PI);
    float c = cos(angle + HALF_PI);
    for (int i = 0; i < numStrips; i++) {
      ledStrip(index + stripLength * i, stripLength,
        x + (i - (numStrips-1)/2.0) * stripSpacing * c,
        y + (i - (numStrips-1)/2.0) * stripSpacing * s, ledSpacing,
        angle, zigzag && (i % 2) == 1);
    }
  }

  // Set the location of 64 LEDs arranged in a uniform 8x8 grid.
  // (x,y) is the center of the grid.
  void ledGrid8x8(int index, float x, float y, float spacing, float angle, boolean zigzag)
  {
    ledGrid(index, 8, 8, x, y, spacing, spacing, angle, zigzag);
  }

  // Should the pixel sampling locations be visible? This helps with debugging.
  // Showing locations is enabled by default. You might need to disable it if our drawing
  // is interfering with your processing sketch, or if you'd simply like the screen to be
  // less cluttered.
  void showLocations(boolean enabled)
  {
    enableShowLocations = enabled;
  }
  
  

  // Automatically called at the end of each draw().
  // This handles the automatic Pixel to LED mapping.
  // If you aren't using that mapping, this function has no effect.
  // In that case, you can call setPixelCount(), setPixel(), and writePixels()
  // separately.
  void draw()
  {
    if (pixelLocations == null) {
      // No pixels defined yet
      return;
    }


    int numPixels = pixelLocations.length;
    int ledAddress = 0;
    
    setPixelCount(numPixels);
    loadPixels();

    for (int i = 0; i < numPixels; i++) {
      int pixelLocation = pixelLocations[i];
      int pixel = pixels[pixelLocation];
      
      int dmxPacket_idx = (ledAddress)/(170*3);
      int dmxAddress = (ledAddress) % (170*3);
      //ledAddress 489*3 is the last one
      //ledAddress 4+490*3 becomes 4
      //println("ledAddress: ",ledAddress,", wledPacket_idx: ",wledPacket_idx,", wledAddress",wledAddress);
      byte R = (byte)(pixel >> 16);
      byte G = (byte)(pixel >> 8);
      byte B = (byte)(pixel);
      dmxData[dmxPacket_idx][dmxAddress] = R;//(byte)(pixel >> 16);//R
      dmxData[dmxPacket_idx][dmxAddress + 1] = G;//(byte)(pixel >> 8);//G
      dmxData[dmxPacket_idx][dmxAddress + 2] = B;//(byte)pixel;//B

      ledAddress += 3;

      if (enableShowLocations) {
        pixels[pixelLocation] = 0xFFFFFF ^ pixel;
      }
    }

    writePixels();

    if (enableShowLocations) {
      updatePixels();
    }
  }
  
  // Change the number of pixels in our output packet.
  // This is normally not needed; the output packet is automatically sized
  // by draw() and by setPixel().
  void setPixelCount(int numPixels)
  {

    //warls format
    // byte 0: which realtime protocol to use
    // 4: DNRGB 489 leds per packet
    // byte 1: how many seconds to wait after the last
    // received packet before returning to normal mode
    // 2: pause for two seconds before doing something cool again
    // 255: infinite timeout
    // byte 2-3: start index H-L
    int numDMXPackets = numPixels / 169 + 1;
    //println("Packets= ",numWledPackets,", Pixels= ",numPixels);
    
    if (dmxData == null || dmxData.length != numDMXPackets) {
      dmxData = new byte[numDMXPackets][];
      for(int i=0;i<numDMXPackets;i++){
        int packet_pixels = min(numPixels,170);
        numPixels -= packet_pixels;
        println("creating packet of size ",packet_pixels*3);
        dmxData[i] = new byte[packet_pixels*3];
        /*int offset = 170 * i;
        byte highByte = (byte)(offset >> 8);
        byte lowByte = (byte)offset;
        wledData[i][0] = 4;//DNRGB
        wledData[i][1] = 2;//two second timeout
        wledData[i][2] = highByte;
        wledData[i][3] = lowByte;
        */
      }
    }

  }
  
  

  // Transmit our current buffer of pixel values to the OPC server. This is handled
  // automatically in draw() if any pixels are mapped to the screen, but if you haven't
  // mapped any pixels to the screen you'll want to call this directly.
  void writePixels()
  {
    if (dmxData == null || dmxData.length == 0){
    }else{
      for(int i=0;i<dmxData.length;i++){
        //DatagramPacket packet = new DatagramPacket(wledData[i],wledData[i].length,this.wledaddress,port);//21324 or 65506
        artnet.unicastDmx(host,start_universe+i,0,dmxData[i]);
/*        try{
          udpsock.send(packet);
        }catch(Exception e){
          println("failed to send packet ",e);
        }
*/      }
    }

  }


}
