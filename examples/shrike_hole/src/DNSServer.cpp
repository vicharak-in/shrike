#include "DNSServer.h"
#include "config.h"
#include "BlocklistManager.h"

extern BlocklistManager blocklistManager;

DNSServer::DNSServer() : port(DNS_PORT), totalQueries(0), blockedQueries(0), 
                         forwardedQueries(0), cachedQueries(0) {
}

bool DNSServer::begin(uint16_t p) {
    port = p;
    if (udp.begin(port)) {
        // Initialize upstream UDP socket on a random port
        upstreamUdp.begin(0);
        Serial.printf("DNS Server started on port %d\n", port);
        return true;
    }
    Serial.println("Failed to start DNS Server");
    return false;
}

void DNSServer::handleClient() {
    int packetSize = udp.parsePacket();
    if (packetSize > 0 && packetSize < DNS_MAX_PACKET_SIZE) {
        IPAddress clientIP = udp.remoteIP();
        uint16_t clientPort = udp.remotePort();
        
        int len = udp.read(buffer, sizeof(buffer));
        if (len > DNS_HEADER_SIZE) {
            totalQueries++;
            
            String domain;
            uint16_t queryType;
            
            if (parseDNSQuery(buffer, len, domain, queryType)) {
                #if DEBUG_ENABLED
                Serial.printf("DNS Query: %s (type %d) from %s\n", 
                            domain.c_str(), queryType, clientIP.toString().c_str());
                #endif
                
                // Check if domain is blocked
                if (blocklistManager.isBlocked(domain)) {
                    blockedQueries++;
                    sendBlockedResponse(clientIP, clientPort, buffer, len);
                    #if DEBUG_ENABLED
                    Serial.printf("Blocked: %s\n", domain.c_str());
                    #endif
                } else {
                    forwardedQueries++;
                    forwardQuery(clientIP, clientPort, buffer, len);
                }
            }
        }
    }
}

void DNSServer::stop() {
    udp.stop();
    upstreamUdp.stop();
}

void DNSServer::resetStats() {
    totalQueries = 0;
    blockedQueries = 0;
    forwardedQueries = 0;
    cachedQueries = 0;
}

bool DNSServer::parseDNSQuery(uint8_t* buffer, size_t len, String& domain, uint16_t& queryType) {
    if (len < DNS_HEADER_SIZE + 5) return false;
    
    size_t offset = DNS_HEADER_SIZE;
    domain = extractDomain(buffer, offset);
    
    if (offset + 4 > len) return false;
    
    queryType = extractUint16(buffer, offset);
    offset += 2; // Move past query type
    // Query class is at offset, offset+1 but we don't need it
    
    return true;
}

String DNSServer::extractDomain(uint8_t* buffer, size_t& offset) {
    String domain = "";
    uint8_t len = buffer[offset++];
    
    while (len > 0 && offset < DNS_MAX_PACKET_SIZE) {
        if (domain.length() > 0) domain += ".";
        
        for (uint8_t i = 0; i < len && offset < DNS_MAX_PACKET_SIZE; i++) {
            domain += (char)buffer[offset++];
        }
        
        if (offset >= DNS_MAX_PACKET_SIZE) break;
        len = buffer[offset++];
    }
    
    return domain;
}

bool DNSServer::encodeDomain(const String& domain, uint8_t* buffer, size_t& offset, size_t maxSize) {
    int start = 0;
    int end = domain.indexOf('.');
    
    while (end != -1) {
        int len = end - start;
        if (offset + len + 1 > maxSize) return false;  // Buffer overflow check
        
        buffer[offset++] = (uint8_t)len;
        for (int i = start; i < end; i++) {
            buffer[offset++] = domain.charAt(i);
        }
        start = end + 1;
        end = domain.indexOf('.', start);
    }
    
    // Last label
    int len = domain.length() - start;
    if (len > 0) {
        if (offset + len + 2 > maxSize) return false;  // Buffer overflow check
        
        buffer[offset++] = (uint8_t)len;
        for (int i = start; i < domain.length(); i++) {
            buffer[offset++] = domain.charAt(i);
        }
    }
    
    if (offset >= maxSize) return false;  // Buffer overflow check
    buffer[offset++] = 0; // Null terminator
    
    return true;
}

uint16_t DNSServer::extractUint16(uint8_t* buffer, size_t offset) {
    return (buffer[offset] << 8) | buffer[offset + 1];
}

void DNSServer::insertUint16(uint8_t* buffer, size_t offset, uint16_t value) {
    buffer[offset] = (value >> 8) & 0xFF;
    buffer[offset + 1] = value & 0xFF;
}

uint32_t DNSServer::extractUint32(uint8_t* buffer, size_t offset) {
    return ((uint32_t)buffer[offset] << 24) | 
           ((uint32_t)buffer[offset + 1] << 16) |
           ((uint32_t)buffer[offset + 2] << 8) | 
           buffer[offset + 3];
}

void DNSServer::insertUint32(uint8_t* buffer, size_t offset, uint32_t value) {
    buffer[offset] = (value >> 24) & 0xFF;
    buffer[offset + 1] = (value >> 16) & 0xFF;
    buffer[offset + 2] = (value >> 8) & 0xFF;
    buffer[offset + 3] = value & 0xFF;
}

void DNSServer::sendBlockedResponse(IPAddress clientIP, uint16_t clientPort, 
                                    uint8_t* queryBuffer, size_t queryLen) {
    // Copy query buffer
    uint8_t response[512];
    memcpy(response, queryBuffer, queryLen);
    
    // Modify flags: QR=1 (response), AA=1 (authoritative), RCODE=0 (no error)
    uint16_t flags = extractUint16(response, 2);
    flags |= 0x8400; // Set QR and AA bits
    insertUint16(response, 2, flags);
    
    // Set answer count to 1
    insertUint16(response, 6, 1);
    
    // Add answer record
    size_t offset = queryLen;
    
    // Name pointer to question (compression)
    response[offset++] = 0xC0;
    response[offset++] = 0x0C;
    
    // Type A
    insertUint16(response, offset, DNS_TYPE_A);
    offset += 2;
    
    // Class IN
    insertUint16(response, offset, DNS_CLASS_IN);
    offset += 2;
    
    // TTL (60 seconds)
    insertUint32(response, offset, 60);
    offset += 4;
    
    // Data length (4 bytes for IPv4)
    insertUint16(response, offset, 4);
    offset += 2;
    
    // Return 0.0.0.0 for blocked domains
    response[offset++] = 0;
    response[offset++] = 0;
    response[offset++] = 0;
    response[offset++] = 0;
    
    udp.beginPacket(clientIP, clientPort);
    udp.write(response, offset);
    udp.endPacket();
}

void DNSServer::forwardQuery(IPAddress clientIP, uint16_t clientPort, 
                            uint8_t* queryBuffer, size_t queryLen) {
    // Parse upstream DNS IP
    IPAddress upstreamDNS;
    upstreamDNS.fromString(UPSTREAM_DNS_IP);
    
    // Forward query to upstream DNS using reusable socket
    upstreamUdp.beginPacket(upstreamDNS, UPSTREAM_DNS_PORT);
    upstreamUdp.write(queryBuffer, queryLen);
    upstreamUdp.endPacket();
    
    // Wait for response with configurable timeout
    unsigned long startTime = millis();
    while (millis() - startTime < DNS_FORWARD_TIMEOUT) {
        int packetSize = upstreamUdp.parsePacket();
        if (packetSize > 0) {
            uint8_t responseBuffer[512];
            int len = upstreamUdp.read(responseBuffer, sizeof(responseBuffer));
            
            // Forward response back to client
            udp.beginPacket(clientIP, clientPort);
            udp.write(responseBuffer, len);
            udp.endPacket();
            
            return;
        }
        delay(DNS_FORWARD_POLL_INTERVAL);
    }
    
    // Timeout - send SERVFAIL response
    uint8_t response[512];
    memcpy(response, queryBuffer, queryLen);
    uint16_t flags = extractUint16(response, 2);
    flags |= 0x8002; // QR=1, RCODE=SERVFAIL
    insertUint16(response, 2, flags);
    
    udp.beginPacket(clientIP, clientPort);
    udp.write(response, queryLen);
    udp.endPacket();
}
