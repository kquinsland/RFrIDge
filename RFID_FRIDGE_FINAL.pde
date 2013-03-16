    /**
     * AUTHOR   : Karl Quinsland
     * PURPOSE  : Controll electromechanical lock on dorm room mini fridge
     * VERSION  : 2.6F
     * LICENSE  : Completly open, be sure to credit me and Benjamin. Don't blame us for things this code does!
     *
     *
     * This is very loosely based on the work of Benjamin Eckel (http://www.gumbolabs.org/2009/10/17/parallax-rfid-reader-arduino/)
     * Some of his RFID handeling code was used and moddified to make more modular
     *
     * CIRCUIT:
     *  RFID VCC ==> ARDUINO VCC
     *  RFID ENA ==> ARDUINO 2 (SERIAL ENABLE)
     *  RFID SOT ==> ARDUINO 0 (GPIO)
     *  RFID GND ==> ARDUINO GND
     *
     *  SERVO POS ==> ARDUINO 5
     */

    // INCLUDES
    #include <Servo.h>               // This is used to  open the door's lock

    //////////// Definitions ////////////


    // RFID
    #define RFID_Enable 2            // define the pin for RFID ENABLE
    #define RFID_codeLength 10       // length of RFID tag (IN BYTES)
    #define RFID_tagValiddate 1      // if set to 1, tag will be 'validated' by checking to makes sure we get the same UID twice
    #define RFID_validateLength 200  // maximum time to wait for a second pass of the same tag
    #define RFID_Pause 2000          // length of time that we set the reader to disable
    #define RFID_startByte 0x0A      // this is the start of the serial string
    #define RFID_stopByte 0x0D       // this is the end of the serial string

    // SERVO
    #define SERVO_Pin 5              // this is the servo's home!
    #define SERVO_Open 155           // this is the position for open
    #define SERVO_Closed  10         // this is the position for closed
    #define SERVO_Delay  3500        // this is the amount of time to hold the lock open
    #define SERVO_MiniDelay 5       // This is the number of miliseconds we wait before incrementing the servo's position.

    // DEBUG
    int ledPin = 13;

    // SECURITY
    boolean FirstRun = true;






    ////////////////////////////////////////////////////////////////////////////////////////////

    ////////// ALLOWED TAGS //////////
    // put all tags you want to ALLOW in the arrays below \\

    // 6706
    //
    // TAG (HEX) : 31-42-30-30-XX-XX-XX-XX-XX-XX
    // TAG (DEC) : 49-66-48-48-XX-XX-XX-XX-XX-XX
    // TAG (RAW) : 1-B-0-0-X-X-X-X-X-X
    //
    // 4174
    //
    // TAG (HEX) : 31-42-30-30-XX-XX-XX-XX-XX-XX
    // TAG (DEC) : 49-66-48-48-XX-XX-XX-XX-XX-XX
    // TAG (RAW) : 1-B-0-0-X-X-X-X-X-X

    byte legit1[] = {
    0x31, 0x42, 0x30, 0x30, 0x38, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX};


    byte legit2[] = {
    0x31, 0x42, 0x30, 0x30, 0x38, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX};
    ////////////////////////////////////////////////////////////////////////////////////////////


    // we will store the serial string (one byte at a time) into an array
    byte tag[RFID_codeLength];

    // we will need a servo object
    Servo lock;

    void setup()
    {
    // lets set up our serial for PC use
    Serial.begin(2400);  // This is our PC connections
    Serial.println("PC Serial Should be ALIVE");
    BlinkLED(1);

    pinMode(RFID_Enable, OUTPUT);  //sets a single pin to high so we can tell the reader to activly search for tags... this will que up a red LED


    // this is done to make sure that the lock is forecefully closed
    FirstRun = true;

    // blink the LED a few times to indicate startup is done.
    RFID_SETUP_BLINK();
    Serial.println("SETUP and BLINKING are DONE!");

    lock.attach(SERVO_Pin);  // configure our servo pin

      BlinkLED(0);          //  turn the debug LED off

    }


    void loop() {

    Serial.println("Entering the LOOP");

    // we do the bit below in the event of power loss.  the servo goes to 1/2 way (90 deg)
    // the if statement makes sure it is only done ONCE per power cycle.
    // as it is now, a bad tag jumps to the top of the loop which will cause this to run
    // which will open the lock enough to forcefully pull it out!


    if(FirstRun = true){
      for (int post = 90; SERVO_Closed <= post; post -=1)
      {
        lock.write(post);
        delay(3);
      }

      // we don't need to do this again.... not until a power reset
      FirstRun = false;
    }


    // Just to be sure, we are going to set the reader to ENABLE / RED
    RFID_Status(1);

    // lets open up and scan for tags

    Serial.println("checking for tags...");

    getRFIDTag();

    Serial.println("tag has been found");

    if(isTagValid){

      RFID_Status(0);     // if the code is valid, disable the reader for just a second (this also shows a green light)
      Serial.println("Reader is GREEN");

      sendCode();         // WE should send the code to the PC, if it is valid
      Serial.println("Tag is SENT - - - - - - AUTHORIZING");

      RFID_Status(1);     // go back to red for a second


      if(checkTagForAuth()){

        RFID_Status(0);  // go green

        Serial.println("Tag was good, AND IS GOOD!");

        Serial.println("Attempting to OPEN LOCK");
        RFID_Status(0);      // make the reader turn GREEN
        Lock(0);             // attempt to open the servo

        Serial.println("Should be open! NOW ENTERING DELAY...");

        delay(SERVO_Delay);
        RFID_Status(0);      // make the reader turn GREEN
        delay(500);
        RFID_Status(1);      // make the reader turn red
        delay(5000);
        RFID_Status(0);      // make the reader turn GREEN
        delay(500);
        RFID_Status(1);      // make the reader turn red
        Serial.println("Delay is over, now closing");
        Lock(1);
        RFID_Status(1);      // make the reader turn red - as a percaution


      }
      else {

        Serial.println("Tag was good, but is not authed!");
        RFIDErrorBlink();
        BlinkLED(1);
      }


    }
    else {

      Serial.println("sorry, NOISE");
      RFIDErrorBlink();  // blink the led a series of red / greens to indicate a problem
      BlinkLED(1);

    }

    delay(2000);  // We should just give everything a second or two to clear out;
    Serial.flush();    // clear the buffer for serial port.
    clearTagArr();    // clear out the array

    }


    /**************************************************************/
    /**********************    Functions  *************************/
    /**************************************************************/

    //
    // This is an infinite loop function, waits for available serial data, then checks it for validity, then fills the buffer if it is
    // vaid.
    //

    void getRFIDTag() {

    // a temporary polace holder
    byte next_byte;
    while(Serial.available() <= 0) {

      // Do NOTHING while we don't have data coming in!

    }


    // When we do have data coming in, we process it below.
    // Check to see if we've got a PC instruction or not

    // fill our temporary buffer
    next_byte = Serial.read();

    // Check our buffer to see if it's valid.
    if(next_byte == RFID_startByte) {

      byte bytesread = 0;  // if we're staring with a valid character, start counting as we fill the buffer

      while(bytesread < RFID_codeLength) {
        if(Serial.available() > 0) {    // wait for the next byte

          if((next_byte = Serial.read()) == RFID_stopByte) break;  // if weve got a stop byte, then lets wrap up, else, heep filling the array.
          tag[bytesread++] = next_byte;

          delay(1);
        }
      }
    }
    }


    //
    //  This is a simple call to adjust the status (and led color) of the reader.
    //
    void RFID_Status(int S){
    if ( S == 1){
      // pin should be RED
      digitalWrite(RFID_Enable, LOW);    // tell the reader to start scanning
    }
    if (S == 0){
      // let shoudl be GREEN
      digitalWrite(RFID_Enable, HIGH);    // tell the reader to stop scanning
    }

    }


    //
    //  This is just a simple set of code to bink the led; its put here to clear up space above.
    //
    //    3 of each color, starting with RED, each blink lasting 1/3 of a second
    //
    //
    //

    void RFID_SETUP_BLINK(){

    RFID_Status(1);  // RED
    delay(333);
    RFID_Status(0);  // GRN
    delay(333);
    RFID_Status(1);  // RED
    delay(333);
    RFID_Status(0);  // GRN
    delay(333);
    RFID_Status(1);  // RED
    delay(333);
    RFID_Status(0);  // GRN
    delay(300);

    }


    //
    // clears the buffer array
    //

    void clearTagArr() {
    for(int i=0; i<RFID_codeLength; i++) {
      tag[i] = 0;
    }
    }

    //
    // Sends the code to the PC
    //

    void sendCode() {
    Serial.print("TAG (HEX) : ");
    for(int i=0; i<RFID_codeLength; i++) {
      Serial.print(tag[i] , HEX);
      Serial.print("-");
    }
    Serial.println();
    }
    //
    // this is essentially a double check of the buffer
    //

    boolean isTagValid() {
    // Temp
    byte next_byte;
    int count = 0;

    // We've already got 2 bytes in the buffer, its proably a stop byte
    while (Serial.available() < 2) {
      delay(2); // a very short wait, not too accurate and not too important

      // a REALLY simple check to see if the new count is the old;  if it's not, we clearly have garbage
      if(count++ > RFID_validateLength) return false;
    }

    Serial.read(); // read from the buffer and throw it to nothing; get rid of the stop byte

    // Is the new tag valid?  does it have a legit start bit?
    if ((next_byte = Serial.read()) == RFID_startByte) {

      // Temp buffer (again)
      byte bytes_read = 0;

      // reading the buffer and checking it for stop bytes and comparing them.
      while (bytes_read < RFID_codeLength) {
        if (Serial.available() > 0) { //wait for the next byte
          if ((next_byte = Serial.read()) == RFID_stopByte) break;
          if (tag[bytes_read++] != next_byte) return false;
        }
      }
    }
    return true;
    }


    //
    // indicate an error in reading the tag with the folowing pattern:
    //
    // red, green, RED, green, RED
    //
    //
    //
    void RFIDErrorBlink(){

    // blink the led to let user know there was noise on the line...
    RFID_Status(1);  // RED
    delay(200);
    RFID_Status(0);  // GREEN
    delay(150);
    RFID_Status(1);  // RED for quite a while
    delay(750);
    RFID_Status(0);  // GREEN
    delay (150);
    RFID_Status(1);  // RED
    delay (500);

    }

    boolean checkTagForAuth(){
    boolean Auth1 = true;
    boolean Auth2 = true;

    Serial.println("AuthCheck is live");

    if(legit1[5] != tag[5]){
      Serial.println("We Failed checking the FIRST unique BYTE for LEGIT KEY 1");
    }

    if(legit2[5] != tag[5]){
      Serial.println("We Failed checking the FIRST unique BYTE for LEGIT KEY 2");
    }

    if(  (legit2[5] != tag[5]) && (legit1[5] != tag[5])){
      Serial.println("this should only happen if the tag is valid but not authed!!!! - SHOULD NOT SEE THIS");
    }

    for(int i=0; i<RFID_codeLength; i++) {
      // read each bit, see if it matches.  if not, reject it and set local auth to fail!
      if(legit1[i] != tag[i]){
        Auth1 = false;
        Serial.print(" (1) Failed on byte number ");
        Serial.println(i);
        break;  // DO NOT USE CONTINUE - we want to skip checking AS SOON AS WE FIND A SINGLE INVALID BYTE!
      }

    }

    for(int i=0; i<RFID_codeLength; i++) {
      // read each bit, see if it matches.  if not, reject it and set local auth to fail!
      if(legit2[i] != tag[i]){
        Auth2 = false;
        Serial.print(" (2) Failed on byte number ");
        Serial.println(i);
        break;  // DO NOT USE CONTINUE - we want to skip checking AS SOON AS WE FIND A SINGLE INVALID BYTE!
      }

    }

    if((Auth1=false) || (Auth2=false)){
      return false;
    }
    else if((Auth1=true) || (Auth2=true)){
      return true;
    }

    }

    void Lock(int s){

    int pos = SERVO_Closed;  // temp for our position.
    Serial.println("LOCK IS LIVE and POINTER IS CLOSED");


    if(s == 1){
      // Lets LOCK
      Serial.println("Servo is now closing to LOCK");

      for(pos = SERVO_Open; pos >= SERVO_Closed; pos -= 1) {

        lock.write(pos);
        delay(SERVO_MiniDelay);

      }

    Serial.println("servo should be closed now");

    } else if(s == 0) {

      // Lets OPEN - we assume it is locked
      Serial.println("Attempting to open");

      for(pos = SERVO_Closed; pos <= SERVO_Open; pos += 1) {

        lock.write(pos);
        delay(SERVO_MiniDelay);

      }

      Serial.println("Servo should be open now!");

    }
    }


    void BlinkLED(int s){

    if(s == 1){
      digitalWrite(ledPin, HIGH);   // set the LED on
    }

    if(s == 0){
      digitalWrite(ledPin, LOW);   // set the LED off
    }
  }

