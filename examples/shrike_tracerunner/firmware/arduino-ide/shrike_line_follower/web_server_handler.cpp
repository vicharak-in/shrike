#include "web_server_handler.h"

WebServerHandler::WebServerHandler() 
    : _server(WEB_SERVER_PORT),
      _fpga(nullptr),
      _motors(nullptr),
      _sensors(nullptr),
      _base_speed(nullptr),
      _last_resp(nullptr),
      _ap_active(false)
{
}

void WebServerHandler::begin(FpgaInterface* fpga, MotorDriver* motors, SensorArray* sensors, uint8_t* base_speed, const FpgaResponse* last_resp) {
    _fpga = fpga;
    _motors = motors;
    _sensors = sensors;
    _base_speed = base_speed;
    _last_resp = last_resp;

    // Start Wi-Fi in Access Point Mode
    WiFi.mode(WIFI_AP);
    _ap_active = WiFi.softAP(WIFI_AP_SSID, WIFI_AP_PASSWORD, WIFI_AP_CHANNEL);

    IPAddress apIP = WiFi.softAPIP();
    Serial.printf("\n[WIFI] Access Point '%s' activated.\n", WIFI_AP_SSID);
    Serial.printf("[WIFI] Web PID Dashboard live at: http://%s/\n\n", apIP.toString().c_str());

    // Register HTTP Handlers
    _server.on("/", HTTP_GET, [this]() { this->handleRoot(); });
    _server.on("/api/telemetry", HTTP_GET, [this]() { this->handleTelemetry(); });
    _server.on("/api/tune", HTTP_POST, [this]() { this->handleTune(); });
    _server.on("/api/tune", HTTP_GET, [this]() { this->handleTune(); });
    _server.on("/api/action", HTTP_POST, [this]() { this->handleAction(); });
    _server.on("/api/action", HTTP_GET, [this]() { this->handleAction(); });
    _server.onNotFound([this]() { this->handleNotFound(); });

    _server.begin();
    Serial.println("[WIFI] HTTP Web Server started.");
}

void WebServerHandler::handleClient() {
    _server.handleClient();
}

void WebServerHandler::handleRoot() {
    _server.send(200, "text/html", INDEX_HTML);
}

void WebServerHandler::handleTelemetry() {
    char json[320];
    uint16_t left_pw = 1500;
    uint16_t right_pw = 1500;

    if (_last_resp) {
        // Map 8-bit duty back to 1000-2000 us RC pulse width
        left_pw  = 1000 + (uint16_t)(((uint32_t)_last_resp->pwm_left * 1000) / 255);
        right_pw = 1000 + (uint16_t)(((uint32_t)_last_resp->pwm_right * 1000) / 255);
    }

    snprintf(json, sizeof(json),
        "{\"armed\":%s,\"watchdog_ok\":%s,\"sensors\":%u,\"error\":%d,\"left_pw\":%u,\"right_pw\":%u,\"line_lost\":%s,\"speed\":%u,\"kp\":%u,\"ki\":%u,\"kd\":%u}",
        (_motors && _motors->isArmed()) ? "true" : "false",
        (_fpga && _fpga->isResponsive()) ? "true" : "false",
        _sensors ? _sensors->getLastByte() : 0,
        _last_resp ? _last_resp->line_error : 0,
        left_pw,
        right_pw,
        (_last_resp && _last_resp->line_lost) ? "true" : "false",
        _base_speed ? *_base_speed : 0,
        _fpga ? _fpga->getKp() : 0,
        _fpga ? _fpga->getKi() : 0,
        _fpga ? _fpga->getKd() : 0
    );

    _server.send(200, "application/json", json);
}

void WebServerHandler::handleTune() {
    if (_server.hasArg("speed") && _base_speed) {
        int val = _server.arg("speed").toInt();
        *_base_speed = (uint8_t)constrain(val, 0, MAX_ALLOWED_SPEED);
        Serial.printf("[WEB] Base speed set to %u\n", *_base_speed);
    }
    if (_server.hasArg("kp") && _fpga) {
        int val = _server.arg("kp").toInt();
        _fpga->setKp((uint8_t)constrain(val, 0, 255));
        Serial.printf("[WEB] FPGA Kp set to %u\n", val);
    }
    if (_server.hasArg("ki") && _fpga) {
        int val = _server.arg("ki").toInt();
        _fpga->setKi((uint8_t)constrain(val, 0, 255));
        Serial.printf("[WEB] FPGA Ki set to %u\n", val);
    }
    if (_server.hasArg("kd") && _fpga) {
        int val = _server.arg("kd").toInt();
        _fpga->setKd((uint8_t)constrain(val, 0, 255));
        Serial.printf("[WEB] FPGA Kd set to %u\n", val);
    }

    _server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void WebServerHandler::handleAction() {
    if (_server.hasArg("cmd")) {
        String cmd = _server.arg("cmd");
        if (cmd.equalsIgnoreCase("arm") && _motors) {
            _motors->arm();
            Serial.println("[WEB] Motors ARMED.");
        } else if ((cmd.equalsIgnoreCase("disarm") || cmd.equalsIgnoreCase("stop")) && _motors) {
            _motors->disarm();
            Serial.println("[WEB] Motors DISARMED (0V Pulse Silence).");
        } else if (cmd.equalsIgnoreCase("reset") && _fpga) {
            _fpga->resetPID();
            Serial.println("[WEB] FPGA PID state reset.");
        } else if (cmd.equalsIgnoreCase("polarity") && _sensors) {
            bool cur = SENSOR_ACTIVE_POLARITY_HIGH;
            _sensors->setPolarity(!cur);
            Serial.println("[WEB] Sensor polarity toggled.");
        }
    }
    _server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void WebServerHandler::handleNotFound() {
    _server.send(404, "text/plain", "Not Found");
}
