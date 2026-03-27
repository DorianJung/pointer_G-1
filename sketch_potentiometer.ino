const int potPins[5] = {PA0, PA1, PA2, PA3, PA4}; 
const int buttonPin = PB0;                   

int stablePots[5] = {0, 0, 0, 0, 0}; 

const int noiseThreshold = 5; 

const int numSamples = 16;

void setup() {
  Serial.begin(115200);
  pinMode(buttonPin, INPUT_PULLUP);
  
  for(int i = 0; i < 5; i++){
     analogRead(potPins[i]);
     delayMicroseconds(10);
     stablePots[i] = analogRead(potPins[i]);
  }
}

void loop() {
  for (int i = 0; i < 5; i++) {
    
    analogRead(potPins[i]); 
    delayMicroseconds(10);  
    
    long readingSum = 0;
    for (int j = 0; j < numSamples; j++) {
      readingSum += analogRead(potPins[i]);
    }
    
    int smoothedRaw = readingSum / numSamples;
    
    if (abs(smoothedRaw - stablePots[i]) >= noiseThreshold) {
      stablePots[i] = smoothedRaw;
    }
    
    Serial.print(stablePots[i]);
    Serial.print(" "); 
  }

  int buttonState = !digitalRead(buttonPin);
  Serial.println(buttonState);

  delay(10); 
}