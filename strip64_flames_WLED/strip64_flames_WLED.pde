WLED wled;
WLED wled2;
//ARTNET wled2;//anet;
PImage im;

void setup()
{
  size(800, 200);

  // Load a sample image
  im = loadImage("flames.jpeg");
  
  //anet = new ARTNET(this, "192.168.8.138",0,0);//ip address, start universe, start channel
  // Connect to the local instance of fcserver
  wled = new WLED(this, "192.168.8.119", 21324);//21324 or 65506
  
  wled2 = new WLED(this,"192.168.8.138",21324);//caterpillar2
  //wled2 = new ARTNET(this,"192.168.8.138",0,0);
  
  // Map one 64-LED strip to the center of the window
  wled.ledStrip(0, 512, width/2, height/2 - 50 , width / 512.0, 0, false);
  //anet.ledStrip(0, 512, width/2, height/2 + 50 , width / 512.0, 0, false);
  //anet.showLocations(true);
  wled2.ledStrip(0, 512, width/2, height/2 + 50, width / 512.0, 0, false);
  wled.showLocations(true);
  wled2.showLocations(true);
}

void draw()
{
  // Scale the image so that it matches the width of the window
  int imHeight = im.height * width / im.width;

  // Scroll down slowly, and wrap around
  float speed = 0.05;
  float y = (millis() * -speed) % imHeight;
  
  // Use two copies of the image, so it seems to repeat infinitely  
  image(im, 0, y, width, imHeight);
  image(im, 0, y + imHeight, width, imHeight);
  delay(20);
}
