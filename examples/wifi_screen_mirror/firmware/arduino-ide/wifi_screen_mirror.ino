
#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>

// ── WiFi ──────────────────────────────────────────────────────────────────────
const char* ssid     = "Galaxy A13 5CFC";
const char* password = "dgav4455";

// ── Ports ─────────────────────────────────────────────────────────────────────
#define TCP_PORT  5000
#define HTTP_PORT 80
#define WS_PORT   81

// ── Frame buffer ──────────────────────────────────────────────────────────────
#define MAX_FRAME 65000   // 65 KB — full 640x480 JPEG at Q70 fits easily

static uint8_t  bufA[MAX_FRAME];
static uint8_t  bufB[MAX_FRAME];
static uint8_t* front        = bufA;
static uint8_t* back         = bufB;
static volatile size_t   frontLen     = 0;
static volatile uint8_t  frontType    = 'F';
static volatile uint16_t frontX       = 0;
static volatile uint16_t frontY       = 0;
static volatile uint32_t framesRx     = 0;
static volatile uint32_t framesServed = 0;
static portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

// ── Servers ───────────────────────────────────────────────────────────────────
WiFiServer        tcpServer(TCP_PORT);
WebServer         httpServer(HTTP_PORT);
WebSocketsServer  webSocket(WS_PORT);

// ── HTML / JS: canvas compositor ─────────────────────────────────────────────
const char html[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<title>Shrike-fi Stream</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#000;display:flex;flex-direction:column;align-items:center;
       justify-content:center;min-height:100vh;font-family:monospace;color:#0f0}
  canvas{display:block;max-width:100vw;max-height:95vh;image-rendering:pixelated;
         border:1px solid #030}
  #hud{font-size:11px;color:#0f0;opacity:.7;margin-top:4px}
</style>
</head>
<body>
<canvas id="c" width="640" height="480"></canvas>
<div id="hud">connecting...</div>
<script>
  const canvas = document.getElementById('c');
  const ctx = canvas.getContext('2d');
  const hud = document.getElementById('hud');
  let frames = 0, t0 = performance.now();

  function connect() {
    const ws = new WebSocket(`ws://${location.hostname}:81/`);
    ws.binaryType = 'arraybuffer';

    ws.onopen  = () => hud.textContent = 'connected';
    ws.onclose = () => { hud.textContent = 'disconnected — retrying...'; setTimeout(connect, 1000); };
    ws.onerror = () => ws.close();

    ws.onmessage = async (ev) => {
      const buf = new Uint8Array(ev.data);
      // header: [0]=type ('F'=70 / 'D'=68)  [1,2]=x  [3,4]=y  (big-endian)
      const type = buf[0];
      const x = (buf[1] << 8) | buf[2];
      const y = (buf[3] << 8) | buf[4];
      const jpegBytes = buf.slice(5);

      const blob = new Blob([jpegBytes], {type: 'image/jpeg'});
      try {
        const bitmap = await createImageBitmap(blob);
        // Full frames land at (0,0) and cover the whole canvas.
        // Diff patches composite at their real screen offset, on top
        // of whatever is already drawn — nothing gets cleared.
        ctx.drawImage(bitmap, x, y);
        bitmap.close();
        frames++;
      } catch (e) { /* corrupt/partial frame — skip it, keep last good pixels */ }
    };
  }
  connect();

  setInterval(async () => {
    const elapsed = (performance.now() - t0) / 1000;
    const fps = (frames / elapsed).toFixed(1);
    try {
      const r = await fetch('/stats');
      const t = await r.text();
      hud.textContent = `${t}  |  render=${fps}fps`;
    } catch (e) {}
  }, 1000);
</script>
</body>
</html>
)rawliteral";

// ── WebSocket events ──────────────────────────────────────────────────────────
void onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_CONNECTED) {
    Serial.printf("[WS] Client %u connected\n", num);
  } else if (type == WStype_DISCONNECTED) {
    Serial.printf("[WS] Client %u disconnected\n", num);
  }
}

// ── TCP receive task (core 0) ─────────────────────────────────────────────────
// Protocol: [1B type 'F'/'D'][2B x][2B y][4B length][JPEG bytes]
void tcpReceiveTask(void*) {
  WiFiClient client;
  Serial.println("[TCP] Receive task on core 0");

  static uint8_t  frameType = 'F';
  static uint16_t rxX = 0, rxY = 0;
  static uint32_t expected = 0, received = 0;
  static uint8_t  hdr[4];
  static uint8_t  hdrBytes = 0;
  static bool     gotType = false, gotXY = false, gotLen = false;

  for (;;) {
    if (!client || !client.connected()) {
      client = tcpServer.available();
      if (client) {
        client.setNoDelay(true);
        Serial.printf("[TCP] Client: %s\n", client.remoteIP().toString().c_str());
        gotType = gotXY = gotLen = false;
        hdrBytes = 0;
      }
      vTaskDelay(pdMS_TO_TICKS(10));
      continue;
    }

    while (client.available()) {
      if (!gotType) {
        frameType = client.read();
        if (frameType != 'F' && frameType != 'D') {
          while (client.available()) client.read();  // resync on garbage
          break;
        }
        gotType  = true;
        hdrBytes = 0;

      } else if (!gotXY) {
        while (client.available() && hdrBytes < 4) {
          hdr[hdrBytes++] = client.read();
        }
        if (hdrBytes < 4) break;  // wait for more bytes
        rxX      = ((uint16_t)hdr[0] << 8) | hdr[1];
        rxY      = ((uint16_t)hdr[2] << 8) | hdr[3];
        gotXY    = true;
        hdrBytes = 0;

      } else if (!gotLen) {
        while (client.available() && hdrBytes < 4) {
          hdr[hdrBytes++] = client.read();
        }
        if (hdrBytes < 4) break;
        expected = ((uint32_t)hdr[0] << 24) | ((uint32_t)hdr[1] << 16)
                 | ((uint32_t)hdr[2] <<  8) |  (uint32_t)hdr[3];

        if (expected == 0 || expected > MAX_FRAME) {
          while (client.available()) client.read();  // resync on bad length
          gotType = gotXY = gotLen = false;
          break;
        }
        received = 0;
        gotLen   = true;

      } else {
        int avail = client.available();
        if (avail > 0) {
          uint32_t want = expected - received;
          int n = client.read(back + received, min((uint32_t)avail, want));
          if (n > 0) received += n;
        }

        if (received == expected) {
          portENTER_CRITICAL(&mux);
          uint8_t* tmp = front;
          front      = back;
          frontLen   = expected;
          frontType  = frameType;
          frontX     = rxX;
          frontY     = rxY;
          back       = tmp;
          portEXIT_CRITICAL(&mux);

          framesRx++;
          if (framesRx % 60 == 0) {
            Serial.printf("[TCP] rx=%u served=%u heap=%u\n",
                          framesRx, framesServed, ESP.getFreeHeap());
          }
          gotType = gotXY = gotLen = false;
        }
        break;  // come back on next loop iteration
      }
    }
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}

// ── WiFi ──────────────────────────────────────────────────────────────────────
void connectWiFi() {
  WiFi.disconnect(true);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);       // disable WiFi sleep for lowest latency
  WiFi.setAutoReconnect(true);
  WiFi.persistent(false);
  WiFi.begin(ssid, password);
  Serial.printf("[WiFi] Connecting to %s", ssid);
  while (WiFi.status() != WL_CONNECTED) {
    delay(400);
    Serial.print(".");
  }
  Serial.printf("\n[WiFi] IP: %s  RSSI: %d dBm\n",
    WiFi.localIP().toString().c_str(), WiFi.RSSI());
}

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== Shrike-fi WebSocket Screen Mirror ===");

  connectWiFi();

  tcpServer.begin();
  tcpServer.setNoDelay(true);
  Serial.printf("[TCP] Server on port %d\n", TCP_PORT);

  httpServer.on("/", HTTP_GET, []() {
    httpServer.send_P(200, "text/html", html);
  });
  httpServer.on("/stats", HTTP_GET, []() {
    char buf[160];
    snprintf(buf, sizeof(buf),
      "rx=%u  served=%u  heap=%u  rssi=%d  ws=%u",
      framesRx, framesServed, ESP.getFreeHeap(), WiFi.RSSI(),
      webSocket.connectedClients());
    httpServer.send(200, "text/plain", buf);
  });
  httpServer.begin();
  Serial.printf("[HTTP] Server on port %d\n", HTTP_PORT);

  webSocket.begin();
  webSocket.onEvent(onWsEvent);
  Serial.printf("[WS] Server on port %d\n", WS_PORT);

  xTaskCreatePinnedToCore(tcpReceiveTask, "tcp_rx", 8192, nullptr, 2, nullptr, 0);

  Serial.println("──────────────────────────────────────");
  Serial.printf("  Browser: http://%s/\n", WiFi.localIP().toString().c_str());
  Serial.printf("  Sender:  python screen_sender.py --ip %s\n",
                WiFi.localIP().toString().c_str());
  Serial.println("──────────────────────────────────────");
}

// ── Loop (core 1 — HTTP + WebSocket, all single-threaded here on purpose) ────
// broadcastBIN() and webSocket.loop() both run from this same core/task so
// there's no need for a cross-core mutex around the WebSocketsServer itself
// (it isn't thread-safe). Only the front/back frame buffer needs the mux,
// since that's shared with the TCP task on core 0.
void loop() {
  httpServer.handleClient();
  webSocket.loop();

  static uint32_t lastFrame = 0;
  uint32_t currentFrame = framesRx;

  if (currentFrame != lastFrame && webSocket.connectedClients() > 0) {
    lastFrame = currentFrame;

    uint8_t*  src = nullptr;
    size_t    len = 0;
    uint8_t   ftype;
    uint16_t  fx, fy;

    portENTER_CRITICAL(&mux);
    src   = front;
    len   = frontLen;
    ftype = frontType;
    fx    = frontX;
    fy    = frontY;
    portEXIT_CRITICAL(&mux);

    if (len > 0 && src != nullptr) {
      static uint8_t outBuf[MAX_FRAME + 5];
      outBuf[0] = ftype;
      outBuf[1] = (fx >> 8) & 0xFF;
      outBuf[2] = fx & 0xFF;
      outBuf[3] = (fy >> 8) & 0xFF;
      outBuf[4] = fy & 0xFF;
      memcpy(outBuf + 5, src, len);

      webSocket.broadcastBIN(outBuf, len + 5);
      framesServed++;
    }
  }

  delay(1);
}
