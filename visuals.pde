import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress pdLocation;

// --- PRESETS & CONFIG --- 
int maxCapacity = 1000;   
int activePointCount = 700;
float baseRadius = 150;
float activeDotSize = 10;
float inactiveDotSize = 6;

float baseXSpeed = 1.5;
float wobbleMultiplier = 0.5;
float wobbleAmount = 1.0;

PVector[] originalPos;
PVector[] pos;
PVector[] vel;
float[] sizes;
float[] noiseOffsetX;
float[] noiseOffsetY;

// --- REVERSE BEHAVIOR VARIABLES ---
boolean[] isAffected;
float[] currentDotDir; 
float reverseRatio = 0.3; 
boolean isReversed = false; 

// --- GRAIN SIZE VARIABLES ---
float grainSizeVal = 0.5; 
boolean[] isGrainAffected;
float[] grainRandomness;

// --- OSC VARIABLES ---
float incomingSpeed = 0.0;
float reverseVal = 0.0;
float delayVal = 0.0;
float delayTimeVal = 0.0;
float globalNoiseTime = 0.0;
float filterVal = 10000.0;
float dryWetVal = 1.0;
float freezeVal = 0.0;
float offsetRndVal = 0.0; 
float octaveVal = 0.0; 

// --- PITCH SMOOTHING ---
float pitchVal = 2.0; 
float currentPitchVal = 2.0; 

// --- SETTINGS MENU & UI ---
boolean showSettings = false;
boolean isStereo = true;  
Slider volSlider, hpfSlider, bufSlider;

// --- BOUNDARY BOX --- 
float boxMargin = -30;    
float boxX, boxY, boxW, boxH; 

// --- INDEPENDENT TRACKER VARIABLES ---
int maxTrackers = 5;
int[] trackedDotIdx = new int[maxTrackers]; 
int[] lastTrackTime = new int[maxTrackers];             
int[] trackIntervals = new int[maxTrackers];

void setup() { 
  fullScreen(P2D);  
  pixelDensity(displayDensity()); 
  smooth(2);  
  
  oscP5 = new OscP5(this, 12001); 
  pdLocation = new NetAddress("127.0.0.1", 12000); 

  boxX = boxMargin; 
  boxY = boxMargin; 
  boxW = width - (boxMargin * 2); 
  boxH = height - (boxMargin * 2); 
   
  originalPos = new PVector[maxCapacity]; 
  pos = new PVector[maxCapacity]; 
  vel = new PVector[maxCapacity]; 
  sizes = new float[maxCapacity]; 
  noiseOffsetX = new float[maxCapacity]; 
  noiseOffsetY = new float[maxCapacity]; 
  
  isAffected = new boolean[maxCapacity]; 
  currentDotDir = new float[maxCapacity];
  
  isGrainAffected = new boolean[maxCapacity];
  grainRandomness = new float[maxCapacity];
   
  initPoints();
  
  // Initialize tracking dots with random start times and intervals
  for(int i = 0; i < maxTrackers; i++) {
    trackedDotIdx[i] = int(random(activePointCount));
    lastTrackTime[i] = millis();
    trackIntervals[i] = int(random(400, 1500)); 
  }
  
  float menuX = width * 0.125;
  volSlider = new Slider("INPUT VOLUME", menuX + 50, height * 0.3, 400, 0, 200, 100, "/inputvol");
  hpfSlider = new Slider("HIGH PASS", menuX + 50, height * 0.45, 400, 0, 127, 0, "/hpf");
  bufSlider = new Slider("BUFFER LENGTH", menuX + 50, height * 0.6, 400, 100, 10000, 3000, "/buffer");

  sendInitialPdState();
} 

void sendInitialPdState() {
  oscP5.send(new OscMessage("/stereo").add(0), pdLocation);
  oscP5.send(new OscMessage("/inputvol").add(100), pdLocation);
  oscP5.send(new OscMessage("/hpf").add(0), pdLocation);
  oscP5.send(new OscMessage("/buffer").add(3000), pdLocation);
}

void initPoints() { 
  for (int i = 0; i < maxCapacity; i++) { 
    noiseOffsetX[i] = random(10000);  
    noiseOffsetY[i] = random(10000);  
    float x = random(boxW) + boxX; 
    float y = random(boxH) + boxY;  
    originalPos[i] = new PVector(x, y);
    pos[i] = new PVector(x, y);            
    vel[i] = new PVector(0, 0); 
    sizes[i] = inactiveDotSize; 
    
    isAffected[i] = false;
    currentDotDir[i] = 1.0; 
    
    isGrainAffected[i] = (random(1) < 0.5);
    grainRandomness[i] = random(0.5, 2.0);
  } 
} 

float getWrappedDist(float x1, float y1, float x2, float y2) {
  float dx = abs(x1 - x2);
  float dy = abs(y1 - y2);
  
  // X STILL WRAPS, BUT Y NO LONGER WRAPS
  if (dx > boxW / 2) dx = boxW - dx;
  return sqrt(dx*dx + dy*dy);
}

void draw() { 
  background(0);  
      
  float currentFilterScale = map(filterVal, 5, 10000, 0.5, 1.0);
  currentFilterScale = constrain(currentFilterScale, 0.5, 1.0);
      
  float noiseSpeed = map(delayTimeVal, 20, 1000, 0.4, 0.03);
  noiseSpeed = constrain(noiseSpeed, 0.03, 0.4);
  globalNoiseTime += noiseSpeed;
  
  float targetWobble = map(incomingSpeed, 0, 100, 1.0, 20.0) * map(delayVal, 0, 1, 0.3, 1.0) * dryWetVal; 
  wobbleAmount = lerp(wobbleAmount, targetWobble, 0.1);

  float currentJitter = map(offsetRndVal, 0.0, 1.0, 0.0, 2); 

  currentPitchVal = lerp(currentPitchVal, pitchVal, 0.001);

  float pitchMultiplier = map(currentPitchVal, 0, 4, 0.7, 2.2);
  float currentXSpeed = (freezeVal > 0.5) ? 0 : (baseXSpeed * pitchMultiplier);
  
  if (!showSettings) sendOscMouse(); 
   
  float dynamicRadius = baseRadius; 
  float lineRadius = map(dryWetVal, 0, 1, 0, dynamicRadius);
   
  for (int i = 0; i < activePointCount; i++) { 
    PVector p = pos[i]; 
    PVector v = vel[i]; 
    PVector home = originalPos[i]; 
    
    // 1. Calculate Target Movement
    float targetDir = 1.0; 
    if (isReversed && isAffected[i]) {
      targetDir = -1.0; 
    }
    
    currentDotDir[i] = lerp(currentDotDir[i], targetDir, 0.03);
    float dotSpeed = currentXSpeed * currentDotDir[i];
    home.x += dotSpeed;

    // --- DYNAMIC SQUASH TARGET FOR VERTICAL DENSITY ---
    PVector dynamicTarget = new PVector(home.x, home.y);
    
    float pitchCenterY = map(currentPitchVal, 0, 4, boxY + boxH, boxY);
    float relativeY = (home.y - boxY) / boxH - 0.5; 
    
    float cubicY = (relativeY * relativeY * relativeY) * 4.0;
    float denseRelativeY = lerp(relativeY, cubicY, 0.6); 
    
    float normOctave = map(constrain(octaveVal, 0, 100), 0, 100, 0.0, 1.0);
    float blendedRelativeY = lerp(denseRelativeY, relativeY, normOctave);
    
    float finalY = pitchCenterY;
    if (blendedRelativeY < 0) {
      float spaceAbove = pitchCenterY - boxY;
      finalY = pitchCenterY + (blendedRelativeY * 2.0 * spaceAbove);
    } else {
      float spaceBelow = (boxY + boxH) - pitchCenterY;
      finalY = pitchCenterY + (blendedRelativeY * 2.0 * spaceBelow);
    }
    dynamicTarget.y = finalY;

    // 2. Physics & Easing
    PVector toHome = PVector.sub(dynamicTarget, p); 
    
    if (toHome.x > boxW / 2) toHome.x -= boxW;
    else if (toHome.x < -boxW / 2) toHome.x += boxW;

    toHome.mult(0.05);  
    v.add(toHome); 
      
    float nX = noise(noiseOffsetX[i] + globalNoiseTime); 
    float nY = noise(noiseOffsetY[i] + globalNoiseTime);
    v.add(new PVector((nX - 0.5) * wobbleAmount, (nY - 0.5) * wobbleAmount));
      
    if (currentJitter > 0.01) {
      v.add(new PVector(random(-currentJitter, currentJitter), random(-currentJitter, currentJitter)));
    }

    v.mult(0.85);  
    p.add(v); 
      
    // 3. --- WRAP AROUND (X) & BOUNDS (Y) ---
    if (p.x > boxX + boxW) { p.x -= boxW; home.x -= boxW; }
    else if (p.x < boxX) { p.x += boxW; home.x += boxW; }
    
    if (p.y < boxY) { 
      p.y = boxY; 
      v.y *= -0.5; 
    } else if (p.y > boxY + boxH) { 
      p.y = boxY + boxH; 
      v.y *= -0.5; 
    }
    
    // 4. --- DISTANCE CHECK ---
    float dMouseWrapped = showSettings ? 999999 : getWrappedDist(mouseX, mouseY, p.x, p.y);
    float dMouseStandard = showSettings ? 999999 : dist(mouseX, mouseY, p.x, p.y);
    
    boolean isConnected = (dMouseWrapped < lineRadius && dMouseStandard < lineRadius);

    // 5. Size and Visual Logic
    float targetSize = (isConnected ? activeDotSize : inactiveDotSize) * currentFilterScale; 
    
    if (isGrainAffected[i]) {
      float grainBaseScale = map(grainSizeVal, 0.01, 1.0, 0.4, 1.5);
      targetSize *= (grainBaseScale * grainRandomness[i]);
    }
    
    sizes[i] = lerp(sizes[i], targetSize, 0.1);
      
    if (isConnected) {
       stroke(255);
       strokeWeight(1);
       line(mouseX, mouseY, p.x, p.y);
    }
  } 
   
  noStroke(); 
  for (int i = 0; i < activePointCount; i++) { 
    fill(255); 
    ellipse(pos[i].x, pos[i].y, sizes[i], sizes[i]); 
  } 

  if (showSettings) drawSettingsMenu();

  if (!showSettings) {
    // --- DYNAMIC TRACKER COUNT ---
    int activeTrackers = round(map(dryWetVal, 0, 1, 0, maxTrackers));
    activeTrackers = constrain(activeTrackers, 0, maxTrackers);

    for (int i = 0; i < activeTrackers; i++) {
      if (millis() - lastTrackTime[i] > trackIntervals[i]) {
        trackedDotIdx[i] = int(random(activePointCount));
        lastTrackTime[i] = millis();
        trackIntervals[i] = int(random(400, 1500)); 
      }
    }

    if (activeTrackers > 0) {
      fill(255);
      textSize(10);
      textAlign(LEFT, TOP);
      
      for (int i = 0; i < activeTrackers; i++) {
        int idx = trackedDotIdx[i];
        PVector p = pos[idx];
        float bufferSeconds = bufSlider.val / 1000.0; 
        float currentPos = map(p.x, boxX, boxX + boxW, 0, bufferSeconds);
        
        stroke(255, 150);
        line(p.x - 5, p.y, p.x + 5, p.y);
        line(p.x, p.y - 5, p.x, p.y + 5);
        
        text("PTR: " + nf(currentPos, 1, 3) + "s", p.x + 8, p.y + 8);
        text("ID: " + idx, p.x + 8, p.y + 20);
      }
    }
  }
}

void drawSettingsMenu() {
  fill(0, 220); 
  rect(0, 0, width, height);
  float menuW = width * 0.75;
  float menuH = height * 0.75;
  float menuX = (width - menuW) / 2.0;
  float menuY = (height - menuH) / 2.0;
  
  stroke(255);
  strokeWeight(1);
  fill(0);
  rect(menuX, menuY, menuW, menuH);
  
  fill(255);
  textAlign(CENTER, CENTER);
  
  // Close 'X' Button
  textSize(30);
  text("X", menuX + menuW - 40, menuY + 40);
  
  // Stereo / Mono Toggle
  textSize(24);
  String modeText = isStereo ? "STEREO" : "MONO";
  fill(255);
  text(modeText, menuX + menuW - 100, menuY + menuH - 50); 
  
  // Quit App Button
  fill(255, 100, 100);
  text("QUIT APP", menuX + 100, menuY + menuH - 50);
  
  volSlider.display();
  hpfSlider.display();
  bufSlider.display();
}

void mousePressed() {
  if (showSettings) {
    float menuW = width * 0.75;
    float menuH = height * 0.75;
    float menuX = (width - menuW) / 2.0;
    float menuY = (height - menuH) / 2.0;

    // Close Menu (X button)
    if (mouseX > menuX + menuW - 60 && mouseX < menuX + menuW - 20 && mouseY > menuY + 20 && mouseY < menuY + 60) {
      showSettings = false;
    }
    
    // Toggle Stereo/Mono
    if (mouseX > menuX + menuW - 160 && mouseX < menuX + menuW - 40 && mouseY > menuY + menuH - 70 && mouseY < menuY + menuH - 30) {
      isStereo = !isStereo;
      oscP5.send(new OscMessage("/stereo").add(isStereo ? 0 : 1), pdLocation);
    }
    
    // Quit App
    if (mouseX > menuX + 40 && mouseX < menuX + 160 && mouseY > menuY + menuH - 70 && mouseY < menuY + menuH - 30) {
      exit(); 
    }
    
    volSlider.press(mouseX, mouseY);
    hpfSlider.press(mouseX, mouseY);
    bufSlider.press(mouseX, mouseY);
  }
}

void mouseReleased() {
  volSlider.release();
  hpfSlider.release();
  bufSlider.release();
}

void mouseDragged() {
  if (showSettings) {
    volSlider.update(mouseX);
    hpfSlider.update(mouseX);
    bufSlider.update(mouseX);
  }
}

void sendOscMouse() { 
  OscMessage myMessage = new OscMessage("/mouse"); 
  myMessage.add(constrain(map(mouseX, 0, width, 0, 1), 0, 1));  
  myMessage.add(constrain(map(mouseY, 0, height, 0, 1), 0, 1));  
  oscP5.send(myMessage, pdLocation); 
}

void oscEvent(OscMessage theOscMessage) {
  if (theOscMessage.checkAddrPattern("/settings")) {
    showSettings = true;
    return;
  }
  String typeTag = theOscMessage.typetag();
  if (typeTag.length() == 0) return;
  float safeValue = (typeTag.charAt(0) == 'i') ? (float)theOscMessage.get(0).intValue() : theOscMessage.get(0).floatValue();

  if (theOscMessage.checkAddrPattern("/particlespeed")) incomingSpeed = safeValue;
  else if (theOscMessage.checkAddrPattern("/reverse")) {
    if (safeValue > 0.5 && !isReversed) {
      isReversed = true; 
      for (int i = 0; i < maxCapacity; i++) {
        isAffected[i] = (random(1) < reverseRatio);
      }
    } else if (safeValue <= 0.5 && isReversed) {
      isReversed = false; 
    }
    reverseVal = safeValue;
  }
  else if (theOscMessage.checkAddrPattern("/grainsize")) grainSizeVal = safeValue;
  else if (theOscMessage.checkAddrPattern("/offsetrnd")) offsetRndVal = safeValue; 
  else if (theOscMessage.checkAddrPattern("/octave")) octaveVal = safeValue; 
  else if (theOscMessage.checkAddrPattern("/delay")) delayVal = safeValue;
  else if (theOscMessage.checkAddrPattern("/msdelaytime")) delayTimeVal = safeValue;
  else if (theOscMessage.checkAddrPattern("/filter")) filterVal = safeValue;
  else if (theOscMessage.checkAddrPattern("/drywet")) dryWetVal = safeValue;
  else if (theOscMessage.checkAddrPattern("/freeze")) freezeVal = safeValue;
  else if (theOscMessage.checkAddrPattern("/pitch")) {
    pitchVal = safeValue;
  }
}

class Slider {
  String label;
  float x, y, w, h = 10;
  float min, max, val;
  String addr;
  boolean dragging = false;

  Slider(String l, float xp, float yp, float sw, float mi, float ma, float def, String ad) {
    label = l; x = xp; y = yp; w = sw; min = mi; max = ma; val = def; addr = ad;
  }

  void display() {
    stroke(255);
    line(x, y + h/2, x + w, y + h/2);
    float pos = map(val, min, max, x, x + w);
    noStroke();
    fill(255);
    rect(pos - 5, y, 10, h);
    textAlign(LEFT, BOTTOM);
    textSize(14);
    text(label + ": " + int(val), x, y - 5);
  }

  void press(float mx, float my) {
    if (mx >= x && mx <= x + w && my >= y - 10 && my <= y + 20) {
      dragging = true;
      update(mx);
    }
  }

  void update(float mx) {
    if (dragging) {
      val = map(constrain(mx, x, x + w), x, x + w, min, max);
      oscP5.send(new OscMessage(addr).add(val), pdLocation);
    }
  }

  void release() { dragging = false; }
}
