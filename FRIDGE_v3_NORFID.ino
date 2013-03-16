/*

 @author        Karl Quinsland
 @project       RFrIDge
 @version       3.0-NORFID
 @purpose       replace thermostat on mini-fridge
 @date          1/3/12

 @license       Creative Commons Attribute, Share Alike, Non Commercial

 */


#include <LiquidCrystal.h>
#include <rotary.h>
#include "TimerOne.h"
#include <OneWire.h>
#include <DallasTemperature.h>



/*
  #  DEFINITIONS
 */

///// LCD

// LCD    LCD    ARDUINO
#define   LCD4   12
#define   LCD6   11
#define   LCD11  10
#define   LCD12  9
#define   LCD13  8
#define   LCD14  7


///// ROTARY
#define   ROTA    2
#define   ROTB    4

///// ONE WIRE
#define ONE_WIRE_BUS 6


///// COMPRESSOR
#define compressorPin 13


char UI_TREND_UP = '+';
char UI_TREND_DN = '-';
char UI_TREND_NC = 'N';
/*
  #  OBJECT CREATION
 */

//LCD
LiquidCrystal lcd(LCD4, LCD6, LCD11, LCD12, LCD13, LCD14);

//ROTARY ENCODER
Rotary r = Rotary(ROTA, ROTB);

// Temp
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensor(&oneWire);

DeviceAddress tempProbe;


/*
  #  VARIABLES
 */

////TEMPERATURE

//CAPS - adjust theese for UI; they, like all temperature variables are in C not F!
int MAX_H = -5;                                           // MAXimum tempreature before forcing compressor ON
int MAX_L = -30;                                          // MAXimum cold before forcig compressor off

/* just one thing to keep in mind

 -5C   is 23 F
 -30C  is -22 F
 */


//SETTINGS - algo adjustments; moddify theese :)
int TMRM_sampInt  =  (1 * 1000000);                      // this is the numebr of micro seconds to wait before recording a temperature
int THRM_numSamp  =  60;                                 // this is the number of samples to take before recording a temperature; ie, every X TMRM_sampInt we
//record a temp

//// - - - TEMPERATURE

//ALGO - used for cooling algo; do not moddify!
int THRESH_U = MAX_H;                                    // get NO HOTTER THAN
int THRESH_L = MAX_L;                                    // get no COLDER THAN

volatile int samples = 0;                                // a counter to keep track of temperature samples since last temperature record.
int oldSamples = samples;


//SENSOR
volatile float tempC = -1.0;                             // used to actually hold the current temperature reading
volatile float oldTemp = tempC;

//HISTORY
int temps[] = {
  0, 0, 0, 0};


////COMPRESSOR
boolean compStatus = true;                               // TRUE if compressor is on; false if off.  default to ON!


/////SCREEN
char line1[] = {
  "L:X R:X T:XX C:X -XX"};                // Allocation of space
char line2[] = {
  "XXXXXXXXXXXXXXXXXXXX"};
char line3[] = {
  "XXXXXXXXXXXXXXXXXXXX"};
char line4[] = {
  "XXXXXXXXXXXXXXXXXXXX"};


// TRENDS
char TEMP_sampTrend = 'A';                                // keeps track of the trends; default to A,
char TEMP_intTrend = 'A';                                 // but valid trneds are + or v or - (A should not be seen!)


/*
 #
 #
 #    MAIN CODE
 #
 #
 */




void setup() {

  Serial.begin(9600);
  Serial.println("ALIVE...");


  // set up LCD
  Serial.print("Setting up LCD...");                     // set up the LCD's number of columns and rows:
  lcd.begin(20, 4);

  // some fancy load screen
  lcd.setCursor(0,0);
  lcd.print("xXxXx R-FRIDGE xXxXx");

  lcd.setCursor(0,1);
  lcd.print("Version 3.0 - NORFID");

  lcd.setCursor(0,2);
  lcd.print("-  Karl Quinsland  -");

  lcd.setCursor(0,3);
  lcd.print("*****---------------");
  delay(100);



  Serial.println("DONE");

  // set up ONE WIRE
  Serial.println("Setting up ONE WIRE...");
  sensor.begin();

  lcd.setCursor(0,3);
  lcd.print("*******-------------");
  delay(100);

  Serial.print(" found {");
  Serial.print(sensor.getDeviceCount(), DEC);
  Serial.print("} temp probes...");

  // get address :)
  if (!sensor.getAddress(tempProbe, 0)){

    Serial.println("Unable to find address for Device 0");
    lcd.clear();
    lcd.setCursor(0,0);
    lcd.print("ERROR; NO ADDRESS");

    // we want to make sure that the compressor is on to prevent food from going bad!
    emergency();
  }


  sensor.setResolution(tempProbe, 12);
  lcd.setCursor(0,3);
  lcd.print("********------------");
  delay(100);

  sensor.requestTemperatures();

  lcd.setCursor(0,3);
  lcd.print("*********-----------");
  delay(100);

  Serial.println("DONE");


  // set up interupts
  Serial.print("Setting up interupts...");

  PCICR |= (1 << PCIE2);                        // enable interupt on pin 2
  PCMSK2 |= (1 << PCINT18) | (1 << PCINT20);    // make sure pin 2 and pin 4 are made available to the ISR
  sei();                                        // make interupt active!

  lcd.setCursor(0,3);
  lcd.print("**************-----");
  delay(100);

  Serial.println("DONE");

  Serial.print("Setting up timers....");

  Timer1.initialize(1000000);
  Timer1.attachInterrupt(getTemp);
  lcd.setCursor(0,3);
  lcd.print("*******************");

  Serial.println("DONE");


  Serial.println("Setup is DONE... entering main loop");
  delay(350);
  lcd.clear();
}




void getTemp() {

  // ask devices on bus for temperature
  sensor.requestTemperatures();

  // increase number of taken samples
  samples += 1;

  // record temp; copy over the old one
  oldTemp = tempC;
  tempC = sensor.getTempC(tempProbe);

}


void showTemp(){

  Serial.print ("S: [");
  Serial.print(samples);
  Serial.print("] GOT A TEMP OF: [");
  Serial.print(tempC);
  Serial.print("] C -> [");
  Serial.print(DallasTemperature::toFahrenheit(tempC));
  Serial.println("] F");

}

void procTrends(){

  // what happened from now and the last sample?
  if (tempC == oldTemp){
    TEMP_sampTrend = UI_TREND_NC;
  }
  else if(tempC > oldTemp){
    TEMP_sampTrend = UI_TREND_UP;
  }
  else if (tempC < oldTemp){
    TEMP_sampTrend = UI_TREND_DN;
  }
  else {
    TEMP_sampTrend = 'X';   // should not see this
  }


  // what happened between NOW and last MIN?
  if (temps[0] == temps[1]){
    TEMP_intTrend = UI_TREND_NC;
  }
  else if(temps[0] > temps[1]){
    TEMP_intTrend = UI_TREND_UP;
  }
  else if (temps[0] < temps[1]){
    TEMP_intTrend = UI_TREND_DN;
  }
  else {
    TEMP_intTrend = 'Y';  // should not see this !
  }


}


void loop() {


  if(samples == oldSamples){
    return;
  }

  // else, new iteration...
  oldSamples = samples;


  // do we read the temperature?
  showTemp();

  // process the most recent temperature
  procTemp();

  // now, we can check if we're supposed to do our regular per-sample stuff

  if (samples == THRM_numSamp  ){

    //reset counter
    samples = 0;

    //record the temperature that's just come down
    recordTemp();

  }

  // go over history; decide what the LCD should show
  procTrends();

  // show things on LCD
  updateScreen();

}

ISR(PCINT2_vect) {

  char result = r.process();

  if (result) {

    //ROTATE TO THE RIGHT, adjust the hot setting
    if (result == DIR_CW){

      // if the uper thermo temp is less than the minimum
      if(THRESH_U < MAX_H){

        THRESH_U += 1;

      }
      else {

        THRESH_U = min(MAX_H, THRESH_L+1);

      }

      // ROTATE TO THE LEFT; adjust the cold setting
    }
    else {

      if (THRESH_L > MAX_L){

        THRESH_L -= 1;

      }
      else {

        THRESH_L = max(MAX_L, THRESH_U-1);

      }
    }
  }

}


void compressor(int s){

  if(s == 1){
    compStatus = true;
  }
  else if (s == 0 ){
    compStatus = false;
  }
  else {
    compStatus = true;
  }


  if (compStatus){
    digitalWrite(compressorPin, HIGH);
    Serial.println("COMP: ON!");
  }
  else {
    digitalWrite(compressorPin, LOW);
    Serial.println("COMP: OFF!");
  }

}

void procTemp() {

  if((int) tempC == 0){
    Serial.println("POSSIBLE FAILUE WITH THERMO...");

    if (!sensor.getAddress(tempProbe, 0)){
      Serial.println("Address FAILURE; trigger emergency!");
      emergency();
    }

    Serial.println("FALSE ALARM!");

  }

  Serial.print("Temp: [");
  Serial.print(tempC);

  // if the temperature we just got is warmer than the max ceiling, TURN COMPRESSOR ON
  if ( tempC >= THRESH_U ){
    Serial.print("] is warmer than TOP (");
    Serial.print(THRESH_U);
    Serial.println(") compressor ON!");
    compressor(1);
    return;
  }


  // if the temperature we just got is colder than the low ceiling, TURN COMPRESSOR OFF
  if ( tempC <= THRESH_L ){

    Serial.print("] is COOLER than BOTTOM (");
    Serial.print(THRESH_L);
    Serial.println(") compressor OFF!");
    compressor(0);
    return;
  }


}

void recordTemp(){

  // update the history
  temps[3] = temps[2];
  temps[2] = temps[1];
  temps[1] = temps[0];
  temps[0] = (int) tempC;

}


void updateScreen(){
  // show a 1 or 0 if compressor is on or off
  char c = (compStatus == true) ? '1' : '0';

  // update LINE 1
  sprintf(line1, "L:%c R:%c T:%c%c C:%c -%02i" , 0x58, 0x58, TEMP_sampTrend, TEMP_intTrend, c , (samples+1) );


  //temporary space for strings for temps
  char temporaryF[6];
  char temporaryC[6];
  float f = DallasTemperature::toFahrenheit(tempC);

  // make strings from the floats - 5 digits incl the decimal, show 2 places after decimal
  dtostrf(f, 5, 2, temporaryF);
  dtostrf(tempC, 5, 2, temporaryC);

  // put all the strings together - spaces are to make things centered
  sprintf(line2, "  C:%s  F:%s" , temporaryC, temporaryF);


  // make line 3 - pad each to 3 digits to evenly pad all things and make sure screen does not have any left over stuff
  //positive numbers will have leading 0's.  +3 ==> 003 +13 ==> 013
  sprintf(line3, " T:%2i/%2i B:%2i/%3i" , THRESH_U, (int) DallasTemperature::toFahrenheit((float) THRESH_U),
  THRESH_L, (int) DallasTemperature::toFahrenheit((float) THRESH_L));

  // make line 4 - pull the temperatures (integers) recorded over past time intervals
  sprintf(line4, "1:%02i 2:%02i 3:%02i 4:%02i" , temps[0], temps[1], temps[2], temps[3] );


  // PRINT LINE 1
  lcd.setCursor(0, 0);
  lcd.print(line1);

  // PRINT LINE 2
  lcd.setCursor(0, 1);
  lcd.print(line2);


  lcd.setCursor(0, 2);
  lcd.print(line3);

  lcd.setCursor(0, 3);
  lcd.print(line4);


}

void emergency (){

  int flag = 1;

  while(true){
    lcd.clear();
    lcd.setCursor(0,0);
    lcd.print("     EMERGENCY     ");
    lcd.setCursor(0,1);
    if(flag == 1){
      lcd.print("comp ON - 20 min");
    }
    else {
      lcd.print("comp OFF - 20 min");
    }

    compressor(flag);

    // 20 min * 60 sec = 1200 * 1000 = 1200000
    delay(1200000);

    flag = !flag;

  }


}


