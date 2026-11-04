#ifndef BLOCKLIST_H
#define BLOCKLIST_H

#include <Arduino.h>
#include <vector>
#include <LittleFS.h>

class BlocklistManager {
public:
    BlocklistManager();
    bool begin();
    bool loadBlocklist(const String& filename);
    bool saveBlocklist(const String& filename);
    bool isBlocked(const String& domain);
    bool addDomain(const String& domain);
    bool removeDomain(const String& domain);
    void clearBlocklist();
    size_t getBlocklistSize() { return blocklist.size(); }
    std::vector<String> getBlocklist() { return blocklist; }
    
private:
    std::vector<String> blocklist;
    bool matchesDomain(const String& domain, const String& pattern);
    String normalizeDomain(const String& domain);
};

#endif // BLOCKLIST_H
