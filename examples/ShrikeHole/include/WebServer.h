#ifndef WEB_SERVER_H
#define WEB_SERVER_H

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include "DNSServer.h"
#include "BlocklistManager.h"

class PiHoleWebServer {
public:
    PiHoleWebServer(DNSServer* dns, BlocklistManager* blocklist);
    bool begin(uint16_t port);
    
private:
    AsyncWebServer* server;
    DNSServer* dnsServer;
    BlocklistManager* blocklistManager;
    
    // Web page handlers
    void handleRoot(AsyncWebServerRequest* request);
    void handleStats(AsyncWebServerRequest* request);
    void handleBlocklist(AsyncWebServerRequest* request);
    void handleAddDomain(AsyncWebServerRequest* request);
    void handleRemoveDomain(AsyncWebServerRequest* request);
    void handleResetStats(AsyncWebServerRequest* request);
    
    // Helper methods
    String getStatsJSON();
    String getBlocklistJSON();
    String getHTMLHeader();
    String getHTMLFooter();
    // Note: Authentication to be implemented in future version
};

#endif // WEB_SERVER_H
