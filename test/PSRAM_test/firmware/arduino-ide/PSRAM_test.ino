/*  This code checks for the presence of PSRAM and prints its size. */

void setup()
{
    Serial.begin(115200);

    if (psramFound()) {
        Serial.printf("PSRAM Found\n");   // PSRAM is found, continue with the rest of the code
    } 
    else {
        Serial.println("PSRAM NOT Found"); // PSRAM is not found, print a message and stop the execution
        return;
    }

   //Check the total size of PSRAM
    Serial.printf("Size of PSRAM: %d bytes \n", ESP.getPsramSize());    
}

void loop()
{
}