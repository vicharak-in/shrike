/*  This code checks for the presence of PSRAM and prints its size. */

void setup()
{
    Serial.begin(115200);

    if (psramFound()) {
        Serial.printf("PSRAM Found\n");
    } 
    else {
        Serial.println("PSRAM NOT Found");
        return;
    }

   //Check the total size of PSRAM
    Serial.printf("Size of PSRAM: %d bytes \n", ESP.getPsramSize());    
}

void loop()
{
}