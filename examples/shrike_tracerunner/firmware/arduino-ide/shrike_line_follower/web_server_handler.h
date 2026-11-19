#ifndef WEB_SERVER_HANDLER_H
#define WEB_SERVER_HANDLER_H

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "config.h"
#include "fpga_interface.h"
#include "motors.h"
#include "sensors.h"
#include "web_dashboard.h"

class WebServerHandler {
private:
    WebServer           _server;
    FpgaInterface*      _fpga;
    MotorDriver*        _motors;
    SensorArray*        _sensors;
    uint8_t*            _base_speed;
    const FpgaResponse* _last_resp;
    bool                _ap_active;

    void handleRoot();
    void handleTelemetry();
    void handleTune();
    void handleAction();
    void handleNotFound();

public:
    WebServerHandler();
    void begin(FpgaInterface* fpga, MotorDriver* motors, SensorArray* sensors, uint8_t* base_speed, const FpgaResponse* last_resp);
    void handleClient();
    bool isApActive() const { return _ap_active; }
};

#endif // WEB_SERVER_HANDLER_H
