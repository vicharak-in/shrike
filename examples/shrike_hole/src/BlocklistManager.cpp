#include "BlocklistManager.h"
#include "config.h"

BlocklistManager::BlocklistManager() {
}

bool BlocklistManager::begin() {
    if (!LittleFS.begin(true)) {
        Serial.println("Failed to mount LittleFS");
        return false;
    }
    
    Serial.println("LittleFS mounted successfully");
    
    // Load default blocklist if it exists
    if (LittleFS.exists(BLOCKLIST_FILE)) {
        return loadBlocklist(BLOCKLIST_FILE);
    } else {
        Serial.println("No blocklist file found, starting with empty blocklist");
        return true;
    }
}

bool BlocklistManager::loadBlocklist(const String& filename) {
    File file = LittleFS.open(filename, "r");
    if (!file) {
        Serial.printf("Failed to open blocklist file: %s\n", filename.c_str());
        return false;
    }
    
    blocklist.clear();
    int count = 0;
    
    while (file.available() && count < MAX_BLOCKLIST_ENTRIES) {
        String line = file.readStringUntil('\n');
        line.trim();
        
        // Skip empty lines and comments
        if (line.length() > 0 && !line.startsWith("#")) {
            blocklist.push_back(normalizeDomain(line));
            count++;
        }
    }
    
    file.close();
    Serial.printf("Loaded %d domains into blocklist\n", count);
    return true;
}

bool BlocklistManager::saveBlocklist(const String& filename) {
    File file = LittleFS.open(filename, "w");
    if (!file) {
        Serial.printf("Failed to create blocklist file: %s\n", filename.c_str());
        return false;
    }
    
    file.println("# Pi-hole ESP32 Blocklist");
    file.println("# One domain per line");
    file.println();
    
    for (const String& domain : blocklist) {
        file.println(domain);
    }
    
    file.close();
    Serial.printf("Saved %d domains to blocklist\n", blocklist.size());
    return true;
}

bool BlocklistManager::isBlocked(const String& domain) {
    String normalizedDomain = normalizeDomain(domain);
    
    for (const String& pattern : blocklist) {
        if (matchesDomain(normalizedDomain, pattern)) {
            return true;
        }
    }
    
    return false;
}

bool BlocklistManager::addDomain(const String& domain) {
    if (blocklist.size() >= MAX_BLOCKLIST_ENTRIES) {
        Serial.println("Blocklist is full");
        return false;
    }
    
    // Validate domain format
    if (domain.length() == 0 || domain.length() > 253) {
        Serial.println("Invalid domain length");
        return false;
    }
    
    // Check for valid characters (alphanumeric, dots, hyphens)
    for (size_t i = 0; i < domain.length(); i++) {
        char c = domain.charAt(i);
        if (!isalnum(c) && c != '.' && c != '-') {
            Serial.printf("Invalid character in domain: %c\n", c);
            return false;
        }
    }
    
    String normalizedDomain = normalizeDomain(domain);
    
    // Check if already in blocklist
    for (const String& d : blocklist) {
        if (d.equalsIgnoreCase(normalizedDomain)) {
            Serial.printf("Domain already in blocklist: %s\n", domain.c_str());
            return false;
        }
    }
    
    blocklist.push_back(normalizedDomain);
    Serial.printf("Added domain to blocklist: %s\n", normalizedDomain.c_str());
    
    // Save to file
    return saveBlocklist(BLOCKLIST_FILE);
}

bool BlocklistManager::removeDomain(const String& domain) {
    String normalizedDomain = normalizeDomain(domain);
    
    for (auto it = blocklist.begin(); it != blocklist.end(); ++it) {
        if (it->equalsIgnoreCase(normalizedDomain)) {
            blocklist.erase(it);
            Serial.printf("Removed domain from blocklist: %s\n", normalizedDomain.c_str());
            
            // Save to file
            return saveBlocklist(BLOCKLIST_FILE);
        }
    }
    
    Serial.printf("Domain not found in blocklist: %s\n", domain.c_str());
    return false;
}

void BlocklistManager::clearBlocklist() {
    blocklist.clear();
    saveBlocklist(BLOCKLIST_FILE);
    Serial.println("Blocklist cleared");
}

bool BlocklistManager::matchesDomain(const String& domain, const String& pattern) {
    // Exact match
    if (domain.equalsIgnoreCase(pattern)) {
        return true;
    }
    
    // Wildcard match (subdomain blocking)
    // Pattern "example.com" should block "www.example.com" and "sub.example.com"
    if (domain.endsWith("." + pattern)) {
        return true;
    }
    
    return false;
}

String BlocklistManager::normalizeDomain(const String& domain) {
    String normalized = domain;
    normalized.toLowerCase();
    normalized.trim();
    
    // Remove trailing dot if present
    if (normalized.endsWith(".")) {
        normalized = normalized.substring(0, normalized.length() - 1);
    }
    
    // Note: We don't remove www. prefix to allow users to block
    // www.example.com specifically if they want to
    // The subdomain matching logic in matchesDomain() will handle
    // blocking subdomains when the parent domain is blocked
    
    return normalized;
}
