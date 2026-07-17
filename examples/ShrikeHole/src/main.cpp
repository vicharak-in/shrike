#include <Arduino.h>
#include <WiFi.h>
#include "config.h"
#include "DNSServer.h"
#include "BlocklistManager.h"
#include "WebServer.h"

// Global instances
DNSServer dnsServer;
BlocklistManager blocklistManager;
PiHoleWebServer webServer(&dnsServer, &blocklistManager);

void setupWiFi() {
    Serial.println("\n=== Pi-hole ESP32 ===");
    Serial.printf("Connecting to WiFi: %s\n", WIFI_SSID);
    
    WiFi.mode(WIFI_STA);
    WiFi.setHostname(DEVICE_HOSTNAME);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi connected!");
        Serial.printf("IP Address: %s\n", WiFi.localIP().toString().c_str());
        Serial.printf("Hostname: %s\n", DEVICE_HOSTNAME);
        Serial.printf("Gateway: %s\n", WiFi.gatewayIP().toString().c_str());
        Serial.printf("DNS: %s\n", WiFi.dnsIP().toString().c_str());
    } else {
        Serial.println("\nFailed to connect to WiFi!");
        Serial.println("Please configure WiFi credentials:");
        Serial.println("1. Copy include/config.h.template to include/config.h");
        Serial.println("2. Edit include/config.h with your WiFi SSID and password");
        Serial.println("3. Recompile and upload");
    }
}

void printSystemInfo() {
    Serial.println("\n=== System Information ===");
    Serial.printf("Chip Model: %s\n", ESP.getChipModel());
    Serial.printf("Chip Revision: %d\n", ESP.getChipRevision());
    Serial.printf("CPU Frequency: %d MHz\n", ESP.getCpuFreqMHz());
    Serial.printf("Flash Size: %d MB\n", ESP.getFlashChipSize() / (1024 * 1024));
    Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());
    Serial.printf("Free PSRAM: %d bytes\n", ESP.getFreePsram());
    Serial.println();
}

void printConfiguration() {
    Serial.println("=== Configuration ===");
    Serial.printf("DNS Port: %d\n", DNS_PORT);
    Serial.printf("Upstream DNS: %s:%d\n", UPSTREAM_DNS_IP, UPSTREAM_DNS_PORT);
    Serial.printf("Web Server Port: %d\n", WEB_SERVER_PORT);
    Serial.printf("Max Blocklist Entries: %d\n", MAX_BLOCKLIST_ENTRIES);
    Serial.printf("Blocklist File: %s\n", BLOCKLIST_FILE);
    Serial.println();
}

void printUsageInstructions() {
    Serial.println("=== Usage Instructions ===");
    Serial.println("1. Configure your devices to use this ESP32 as DNS server");
    Serial.printf("   DNS Server IP: %s\n", WiFi.localIP().toString().c_str());
    Serial.println();
    Serial.println("2. Access the web interface:");
    Serial.printf("   URL: http://%s/\n", WiFi.localIP().toString().c_str());
    Serial.println();
    Serial.println("3. To test DNS blocking:");
    Serial.println("   - Add a domain to the blocklist via web interface");
    Serial.println("   - Try to access that domain from a device using this DNS");
    Serial.println();
    Serial.println("4. View real-time statistics on the web interface");
    Serial.println();
}

void setup() {
    // Initialize serial communication
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("\n\n");
    Serial.println("=====================================================");
    Serial.println("        Pi-hole ESP32 - DNS Ad Blocker");
    Serial.println("=====================================================");
    
    // Print system information
    printSystemInfo();
    
    // Setup WiFi
    setupWiFi();
    
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("Cannot start services without WiFi connection");
        Serial.println("Please reset the device after configuring WiFi credentials");
        return;
    }
    
    // Print configuration
    printConfiguration();
    
    // Initialize blocklist manager
    Serial.println("Initializing blocklist manager...");
    if (blocklistManager.begin()) {
        Serial.printf("Blocklist initialized with %d domains\n", 
                     blocklistManager.getBlocklistSize());
    } else {
        Serial.println("Warning: Blocklist initialization failed, but continuing...");
    }
    
    // Start DNS server
    Serial.println("Starting DNS server...");
    if (dnsServer.begin(DNS_PORT)) {
        Serial.println("DNS server started successfully");
    } else {
        Serial.println("Failed to start DNS server!");
        return;
    }
    
    // Start web server
    Serial.println("Starting web server...");
    if (webServer.begin(WEB_SERVER_PORT)) {
        Serial.println("Web server started successfully");
    } else {
        Serial.println("Failed to start web server!");
    }
    
    Serial.println();
    Serial.println("=====================================================");
    Serial.println("           System Ready!");
    Serial.println("=====================================================");
    
    // Print usage instructions
    printUsageInstructions();
    
    Serial.println("Monitoring DNS queries...");
    Serial.println();
}

void loop() {
    // Handle DNS queries
    dnsServer.handleClient();
    
    // Small delay to prevent watchdog timer issues
    delay(1);
    
    // Print statistics every 60 seconds
    static unsigned long lastStatsTime = 0;
    if (millis() - lastStatsTime > 60000) {
        lastStatsTime = millis();
        
        Serial.println("\n=== Statistics ===");
        Serial.printf("Total Queries: %u\n", dnsServer.getTotalQueries());
        Serial.printf("Blocked Queries: %u\n", dnsServer.getBlockedQueries());
        Serial.printf("Forwarded Queries: %u\n", dnsServer.getForwardedQueries());
        Serial.printf("Blocklist Size: %u\n", blocklistManager.getBlocklistSize());
        
        uint32_t total = dnsServer.getTotalQueries();
        if (total > 0) {
            float blockRate = (dnsServer.getBlockedQueries() * 100.0) / total;
            Serial.printf("Block Rate: %.1f%%\n", blockRate);
        }
        
        Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());
        Serial.println();
    }
}
