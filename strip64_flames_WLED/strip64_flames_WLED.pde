WLED wled;
PImage im;

void setup()
{
  size(800, 200);

  // Load a sample image
  im = loadImage("flames.jpeg");

  // Connect to the local instance of fcserver
  wled = new WLED(this, "galagoled.local", 21324);//21324 or 65506

  // Map one 64-LED strip to the center of the window
  wled.ledStrip(0, 490, width/2, height/2, width / 70.0, 0, false);
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
