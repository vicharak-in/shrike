#include <WiFi.h>
#include <WebServer.h>
#include "SPIFFS.h"

#include <SPI.h>
#include "driver/spi_master.h"
#include "driver/gpio.h"

// ---------------- WIFI ----------------
const char *ssid = <"SSID">;
const char *password = <"PASSWORD">;

WebServer server(80);

File uploadFile;

// ---------------- SPI CONFIG ----------------
spi_device_handle_t spi;

#define SPI_INSTANCE SPI2_HOST  
#define SPI_CLOCK (1000 * 16000) //FPGA CLOCK

// SPI PINS
#define PIN_MISO 13
#define PIN_MOSI 11
#define PIN_SCK  12
#define PIN_SS   10
#define PIN_PWR  9
#define PIN_EN   8

// ---------------- HTML PAGE ----------------
const char *uploadPage = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <title>Shrike-fi FPGA Upload</title>

  <meta name="viewport" content="width=device-width, initial-scale=1">

  <style>

    *{
      margin:0;
      padding:0;
      box-sizing:border-box;
    }

    body{
      font-family: Arial, sans-serif;

      height:100vh;

      display:flex;
      justify-content:center;
      align-items:center;

      background: linear-gradient(
        135deg,
        #0f172a,
        #111827,
        #1e293b
      );

      color:white;
    }

    .container{

      width:420px;

      background: rgba(255,255,255,0.08);

      border:1px solid rgba(255,255,255,0.15);

      backdrop-filter: blur(10px);

      border-radius:20px;

      padding:30px;

      text-align:center;

      box-shadow:
      0 8px 32px rgba(0,0,0,0.4);
    }

    h1{
      font-size:30px;
      margin-bottom:10px;
      color:#60a5fa;
    }

    .subtitle{
      color:#cbd5e1;
      margin-bottom:30px;
      font-size:15px;
    }

    #drop_zone{

      width:100%;
      height:220px;

      border:2px dashed #60a5fa;

      border-radius:16px;

      display:flex;
      justify-content:center;
      align-items:center;

      font-size:22px;

      cursor:pointer;

      transition:0.3s;

      background: rgba(255,255,255,0.03);
    }

    #drop_zone:hover{
      background: rgba(96,165,250,0.12);
      transform: scale(1.02);
    }

    #drop_zone.hover{
      background: rgba(96,165,250,0.18);
      border-color:#93c5fd;
    }

    #status{

      margin-top:25px;

      font-size:16px;

      padding:12px;

      border-radius:10px;

      background: rgba(255,255,255,0.05);

      color:#e2e8f0;
    }

    .footer{
      margin-top:20px;
      color:#94a3b8;
      font-size:13px;
    }

  </style>
</head>

<body>

<div class="container">

  <h1>Shrike-fi</h1>

  <p class="subtitle">
    ESP32-S3 to FPGA Bitstream Upload
  </p>

  <div id="drop_zone">
    Drop File Here<br>OR Click
  </div>

  <p id="status">
    Waiting for upload...
  </p>

  <div class="footer">
    SPI Flash Transfer Interface
  </div>

</div>

<input type="file" id="fileInput" hidden>

<script>

let dropZone = document.getElementById('drop_zone');
let fileInput = document.getElementById('fileInput');
let statusText = document.getElementById('status');

// CLICK
dropZone.addEventListener('click', () => {
    fileInput.click();
});

// FILE SELECT
fileInput.addEventListener('change', () => {
    uploadFile(fileInput.files[0]);
});

// DRAG OVER
dropZone.addEventListener('dragover', (e) => {

    e.preventDefault();

    dropZone.classList.add('hover');
});

// DRAG LEAVE
dropZone.addEventListener('dragleave', () => {

    dropZone.classList.remove('hover');
});

// DROP
dropZone.addEventListener('drop', (e) => {

    e.preventDefault();

    dropZone.classList.remove('hover');

    let file = e.dataTransfer.files[0];

    uploadFile(file);
});

// UPLOAD FUNCTION
function uploadFile(file)
{
    if(!file)
    {
        alert("No File Selected");
        return;
    }

    let formData = new FormData();

    formData.append("file", file);

    statusText.innerHTML =
    "Uploading " + file.name + "...";

    fetch('/upload', {

        method: 'POST',
        body: formData
    })

    .then(response => response.text())

    .then(data => {

        statusText.innerHTML =
        "" + data;
    })

    .catch(error => {

        statusText.innerHTML =
        "Upload Failed";

        console.log(error);
    });
}

</script>

</body>
</html>
)rawliteral";

// ---------------- ROOT PAGE ----------------
void handleRoot()
{
    server.send(200, "text/html", uploadPage);
}

// ---------------- FILE UPLOAD ----------------
void handleUpload()
{
    HTTPUpload &upload = server.upload();

    // UPLOAD START
    if (upload.status == UPLOAD_FILE_START)
    {
        String filename = "/" + upload.filename;

        Serial.println("================================");
        Serial.println("UPLOAD START");
        Serial.print("FILE: ");
        Serial.println(filename);

        uploadFile = SPIFFS.open(filename, FILE_WRITE);

        if (!uploadFile)
        {
            Serial.println("FILE OPEN FAILED");
        }
    }

    // FILE WRITE
    else if (upload.status == UPLOAD_FILE_WRITE)
    {
        if (uploadFile)
        {
            uploadFile.write(upload.buf, upload.currentSize);

            Serial.print("WRITTEN BYTES: ");
            Serial.println(upload.currentSize);
        }
    }

    // UPLOAD END
    else if (upload.status == UPLOAD_FILE_END)
    {
        if (uploadFile)
        {
            uploadFile.close();
        }

        Serial.println("UPLOAD COMPLETE");

        // ---------------- READ FILE ----------------
        String filename = "/" + upload.filename;

        File readFile = SPIFFS.open(filename, FILE_READ);

        if (!readFile)
        {
            Serial.println("READ OPEN FAILED");
            return;
        }

        Serial.println("START FPGA SPI TRANSFER");

        uint8_t spi_buffer[256]; // Adjust buffer size as needed

        while (readFile.available())
        {
            int len = readFile.read(spi_buffer, sizeof(spi_buffer));

            if (len > 0)
            {
                spi_transaction_t t;

                memset(&t, 0, sizeof(t));

                t.length = len * 8;
                t.tx_buffer = spi_buffer;
                t.rx_buffer = NULL;

                digitalWrite(PIN_SS, LOW);

                esp_err_t err = spi_device_transmit(spi, &t);

                digitalWrite(PIN_SS, HIGH);

                if (err == ESP_OK)
                {
                    Serial.print("SPI SENT BYTES: ");
                    Serial.println(len);
                }
                else
                {
                    Serial.println("SPI TRANSFER FAILED");
                }
            }
        }

        readFile.close();

        Serial.println("FPGA TRANSFER COMPLETE");
    }
}

// ---------------- SETUP ----------------
void setup()
{
    Serial.begin(115200);

    // ---------------- SPIFFS INIT ----------------
    if (!SPIFFS.begin(true))
    {
        Serial.println("SPIFFS MOUNT FAILED");
        return;
    }

    // ---------------- GPIO CONFIG ----------------
    pinMode(PIN_PWR, OUTPUT);
    pinMode(PIN_EN, OUTPUT);
    pinMode(PIN_SS, OUTPUT);

    // ---------------- SPI BUS CONFIG ----------------
    spi_bus_config_t buscfg;

    memset(&buscfg, 0, sizeof(buscfg));

    buscfg.miso_io_num = PIN_MISO;
    buscfg.mosi_io_num = PIN_MOSI;
    buscfg.sclk_io_num = PIN_SCK;
    buscfg.quadwp_io_num = -1;
    buscfg.quadhd_io_num = -1;
    buscfg.max_transfer_sz = 4096;

    // ---------------- SPI DEVICE CONFIG ----------------
    spi_device_interface_config_t devcfg;

    memset(&devcfg, 0, sizeof(devcfg));

    devcfg.clock_speed_hz = SPI_CLOCK;
    devcfg.mode = 0;
    devcfg.spics_io_num = -1;
    devcfg.queue_size = 1;

    // ---------------- SPI INIT ----------------
    esp_err_t ret;

    ret = spi_bus_initialize(
              SPI_INSTANCE,
              &buscfg,
              SPI_DMA_CH_AUTO);

    if (ret != ESP_OK)
    {
        Serial.println("SPI BUS INIT FAILED");
        return;
    }

    ret = spi_bus_add_device(
              SPI_INSTANCE,
              &devcfg,
              &spi);

    if (ret != ESP_OK)
    {
        Serial.println("SPI DEVICE ADD FAILED");
        return;
    }

    // ---------------- FPGA RESET ----------------
    digitalWrite(PIN_PWR, LOW);
    digitalWrite(PIN_EN, LOW);
    digitalWrite(PIN_SS, HIGH);

    delay(3);

    digitalWrite(PIN_PWR, HIGH);
    digitalWrite(PIN_EN, HIGH);
    digitalWrite(PIN_SS, LOW);

    delay(10);
        
    digitalWrite(PIN_SS, HIGH);
    delay(1);


    Serial.println("FPGA INIT DONE");

    // ---------------- WIFI CONNECT ----------------
    WiFi.begin(ssid, password);

    Serial.print("CONNECTING TO WIFI");

    while (WiFi.status() != WL_CONNECTED)
    {
        delay(500);
        Serial.print(".");
    }

    Serial.println();
    Serial.println("WIFI CONNECTED");

    Serial.print("ESP32 IP: ");
    Serial.println(WiFi.localIP());

    // ---------------- SERVER ROUTES ----------------
    server.on("/", HTTP_GET, handleRoot);

    server.on(
        "/upload",
        HTTP_POST,
        []()
        {
            server.send(200, "text/plain", "FILE UPLOADED IN ESP32S3 & FPGA FLASHING DONE");
        },
        handleUpload);

    // ---------------- SERVER START ----------------
    server.begin();

    Serial.println("HTTP SERVER STARTED");
}

// ---------------- LOOP ----------------
void loop()
{
    server.handleClient();
}