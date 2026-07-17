#include "WebServer.h"
#include "config.h"
#include <ArduinoJson.h>

PiHoleWebServer::PiHoleWebServer(DNSServer* dns, BlocklistManager* blocklist) 
    : dnsServer(dns), blocklistManager(blocklist) {
    server = new AsyncWebServer(WEB_SERVER_PORT);
}

bool PiHoleWebServer::begin(uint16_t port) {
    // Root page
    server->on("/", HTTP_GET, [this](AsyncWebServerRequest* request) {
        handleRoot(request);
    });
    
    // API endpoints
    server->on("/api/stats", HTTP_GET, [this](AsyncWebServerRequest* request) {
        handleStats(request);
    });
    
    server->on("/api/blocklist", HTTP_GET, [this](AsyncWebServerRequest* request) {
        handleBlocklist(request);
    });
    
    server->on("/api/add", HTTP_POST, [this](AsyncWebServerRequest* request) {
        handleAddDomain(request);
    });
    
    server->on("/api/remove", HTTP_POST, [this](AsyncWebServerRequest* request) {
        handleRemoveDomain(request);
    });
    
    server->on("/api/reset", HTTP_POST, [this](AsyncWebServerRequest* request) {
        handleResetStats(request);
    });
    
    server->begin();
    Serial.printf("Web Server started on port %d\n", port);
    return true;
}

void PiHoleWebServer::handleRoot(AsyncWebServerRequest* request) {
    String html = getHTMLHeader();
    
    html += "<div class='container'>";
    html += "<h1>Pi-hole ESP32</h1>";
    html += "<div class='stats-grid'>";
    
    // Statistics cards
    html += "<div class='stat-card'>";
    html += "<h3>Total Queries</h3>";
    html += "<p class='stat-value' id='totalQueries'>-</p>";
    html += "</div>";
    
    html += "<div class='stat-card'>";
    html += "<h3>Blocked Queries</h3>";
    html += "<p class='stat-value' id='blockedQueries'>-</p>";
    html += "</div>";
    
    html += "<div class='stat-card'>";
    html += "<h3>Block Rate</h3>";
    html += "<p class='stat-value' id='blockRate'>-</p>";
    html += "</div>";
    
    html += "<div class='stat-card'>";
    html += "<h3>Blocklist Size</h3>";
    html += "<p class='stat-value' id='blocklistSize'>-</p>";
    html += "</div>";
    
    html += "</div>"; // stats-grid
    
    // Add domain form
    html += "<div class='form-section'>";
    html += "<h2>Add Domain to Blocklist</h2>";
    html += "<input type='text' id='domainInput' placeholder='example.com'>";
    html += "<button onclick='addDomain()'>Add Domain</button>";
    html += "</div>";
    
    // Blocklist display
    html += "<div class='blocklist-section'>";
    html += "<h2>Blocklist</h2>";
    html += "<div id='blocklistContainer'>Loading...</div>";
    html += "</div>";
    
    html += "</div>"; // container
    
    // JavaScript
    html += "<script>";
    html += "function updateStats() {";
    html += "  fetch('/api/stats').then(r=>r.json()).then(data=>{";
    html += "    document.getElementById('totalQueries').textContent=data.totalQueries;";
    html += "    document.getElementById('blockedQueries').textContent=data.blockedQueries;";
    html += "    document.getElementById('blockRate').textContent=data.blockRate+'%';";
    html += "    document.getElementById('blocklistSize').textContent=data.blocklistSize;";
    html += "  });";
    html += "}";
    
    html += "function updateBlocklist() {";
    html += "  fetch('/api/blocklist').then(r=>r.json()).then(data=>{";
    html += "    let html='<ul>';";
    html += "    data.domains.forEach(d=>{";
    html += "      const safeD = d.replace(/</g,'&lt;').replace(/>/g,'&gt;');";  // HTML escape
    html += "      html+='<li>'+safeD+' <button onclick=\"removeDomain(\\''+encodeURIComponent(d)+'\\')\"'>Remove</button></li>';";
    html += "    });";
    html += "    html+='</ul>';";
    html += "    document.getElementById('blocklistContainer').innerHTML=html;";
    html += "  });";
    html += "}";
    
    html += "function addDomain() {";
    html += "  const domain = document.getElementById('domainInput').value;";
    html += "  if(!domain) return;";
    html += "  fetch('/api/add?domain='+encodeURIComponent(domain),{method:'POST'})";
    html += "    .then(r=>r.json())";
    html += "    .then(data=>{alert(data.message);updateBlocklist();updateStats();});";
    html += "  document.getElementById('domainInput').value='';";
    html += "}";
    
    html += "function removeDomain(domain) {";
    html += "  fetch('/api/remove?domain='+encodeURIComponent(domain),{method:'POST'})";
    html += "    .then(r=>r.json())";
    html += "    .then(data=>{alert(data.message);updateBlocklist();updateStats();});";
    html += "}";
    
    html += "setInterval(updateStats, 5000);";
    html += "updateStats();";
    html += "updateBlocklist();";
    html += "</script>";
    
    html += getHTMLFooter();
    
    request->send(200, "text/html", html);
}

void PiHoleWebServer::handleStats(AsyncWebServerRequest* request) {
    request->send(200, "application/json", getStatsJSON());
}

void PiHoleWebServer::handleBlocklist(AsyncWebServerRequest* request) {
    request->send(200, "application/json", getBlocklistJSON());
}

void PiHoleWebServer::handleAddDomain(AsyncWebServerRequest* request) {
    if (!request->hasParam("domain")) {
        request->send(400, "application/json", "{\"success\":false,\"message\":\"No domain specified\"}");
        return;
    }
    
    String domain = request->getParam("domain")->value();
    bool success = blocklistManager->addDomain(domain);
    
    JsonDocument doc;
    doc["success"] = success;
    doc["message"] = success ? "Domain added successfully" : "Failed to add domain";
    
    String response;
    serializeJson(doc, response);
    request->send(success ? 200 : 400, "application/json", response);
}

void PiHoleWebServer::handleRemoveDomain(AsyncWebServerRequest* request) {
    if (!request->hasParam("domain")) {
        request->send(400, "application/json", "{\"success\":false,\"message\":\"No domain specified\"}");
        return;
    }
    
    String domain = request->getParam("domain")->value();
    bool success = blocklistManager->removeDomain(domain);
    
    JsonDocument doc;
    doc["success"] = success;
    doc["message"] = success ? "Domain removed successfully" : "Failed to remove domain";
    
    String response;
    serializeJson(doc, response);
    request->send(success ? 200 : 400, "application/json", response);
}

void PiHoleWebServer::handleResetStats(AsyncWebServerRequest* request) {
    dnsServer->resetStats();
    request->send(200, "application/json", "{\"success\":true,\"message\":\"Statistics reset\"}");
}

String PiHoleWebServer::getStatsJSON() {
    JsonDocument doc;
    
    uint32_t total = dnsServer->getTotalQueries();
    uint32_t blocked = dnsServer->getBlockedQueries();
    
    doc["totalQueries"] = total;
    doc["blockedQueries"] = blocked;
    doc["forwardedQueries"] = dnsServer->getForwardedQueries();
    doc["cachedQueries"] = dnsServer->getCachedQueries();
    doc["blocklistSize"] = blocklistManager->getBlocklistSize();
    
    float blockRate = 0;
    if (total > 0) {
        blockRate = (blocked * 100.0) / total;
    }
    doc["blockRate"] = String(blockRate, 1);
    
    String response;
    serializeJson(doc, response);
    return response;
}

String PiHoleWebServer::getBlocklistJSON() {
    JsonDocument doc;
    JsonArray domains = doc["domains"].to<JsonArray>();
    
    std::vector<String> blocklist = blocklistManager->getBlocklist();
    for (const String& domain : blocklist) {
        domains.add(domain);
    }
    
    String response;
    serializeJson(doc, response);
    return response;
}

String PiHoleWebServer::getHTMLHeader() {
    String html = "<!DOCTYPE html><html><head>";
    html += "<meta charset='UTF-8'>";
    html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
    html += "<title>Pi-hole ESP32</title>";
    html += "<style>";
    html += "body{font-family:Arial,sans-serif;margin:0;padding:20px;background:#f5f5f5;}";
    html += ".container{max-width:1200px;margin:0 auto;}";
    html += "h1{color:#333;text-align:center;}";
    html += ".stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;margin:20px 0;}";
    html += ".stat-card{background:white;padding:20px;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.1);}";
    html += ".stat-card h3{margin:0 0 10px 0;color:#666;font-size:14px;}";
    html += ".stat-value{font-size:32px;font-weight:bold;color:#96BF48;margin:0;}";
    html += ".form-section{background:white;padding:20px;border-radius:8px;margin:20px 0;box-shadow:0 2px 4px rgba(0,0,0,0.1);}";
    html += "input{padding:10px;width:calc(100% - 120px);border:1px solid #ddd;border-radius:4px;}";
    html += "button{padding:10px 20px;background:#96BF48;color:white;border:none;border-radius:4px;cursor:pointer;}";
    html += "button:hover{background:#7fa037;}";
    html += ".blocklist-section{background:white;padding:20px;border-radius:8px;margin:20px 0;box-shadow:0 2px 4px rgba(0,0,0,0.1);}";
    html += "ul{list-style:none;padding:0;}";
    html += "li{padding:10px;border-bottom:1px solid #eee;display:flex;justify-content:space-between;}";
    html += "li button{padding:5px 10px;font-size:12px;}";
    html += "</style>";
    html += "</head><body>";
    return html;
}

String PiHoleWebServer::getHTMLFooter() {
    return "</body></html>";
}
