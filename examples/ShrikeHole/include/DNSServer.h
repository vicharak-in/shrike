#ifndef DNS_SERVER_H
#define DNS_SERVER_H

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>

// DNS packet structure definitions
#define DNS_HEADER_SIZE 12
#define DNS_MAX_PACKET_SIZE 512
#define DNS_QR_QUERY 0
#define DNS_QR_RESPONSE 1
#define DNS_OPCODE_QUERY 0
#define DNS_RCODE_NO_ERROR 0
#define DNS_RCODE_NAME_ERROR 3
#define DNS_TYPE_A 1
#define DNS_CLASS_IN 1

class DNSServer {
public:
    DNSServer();
    bool begin(uint16_t port);
    void handleClient();
    void stop();
    
    // Statistics
    uint32_t getTotalQueries() { return totalQueries; }
    uint32_t getBlockedQueries() { return blockedQueries; }
    uint32_t getForwardedQueries() { return forwardedQueries; }
    uint32_t getCachedQueries() { return cachedQueries; }
    void resetStats();
    
private:
    WiFiUDP udp;
    WiFiUDP upstreamUdp;  // Reusable UDP socket for upstream queries
    uint16_t port;
    uint8_t buffer[DNS_MAX_PACKET_SIZE];
    
    // Statistics
    uint32_t totalQueries;
    uint32_t blockedQueries;
    uint32_t forwardedQueries;
    uint32_t cachedQueries;
    
    // Internal methods
    bool parseDNSQuery(uint8_t* buffer, size_t len, String& domain, uint16_t& queryType);
    void sendBlockedResponse(IPAddress clientIP, uint16_t clientPort, uint8_t* queryBuffer, 
                           size_t queryLen);
    void forwardQuery(IPAddress clientIP, uint16_t clientPort, uint8_t* queryBuffer, 
                     size_t queryLen);
    String extractDomain(uint8_t* buffer, size_t& offset);
    bool encodeDomain(const String& domain, uint8_t* buffer, size_t& offset, size_t maxSize);
    uint16_t extractUint16(uint8_t* buffer, size_t offset);
    void insertUint16(uint8_t* buffer, size_t offset, uint16_t value);
    uint32_t extractUint32(uint8_t* buffer, size_t offset);
    void insertUint32(uint8_t* buffer, size_t offset, uint32_t value);
};

#endif // DNS_SERVER_H
