#ifndef CONFIG_H
#define CONFIG_H

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// IMPORTANT: This is a template configuration file. Before uploading
// to your ESP32, you MUST change the WiFi credentials below!
// Copy this file to config.h and modify with your settings.
// DO NOT commit actual credentials to version control!
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// WiFi Configuration
// CHANGE THESE to match your network!
#define WIFI_SSID "Galaxy F15 5G 26DE"  // Your WiFi SSID
#define WIFI_PASSWORD "Dev111@%"

// DNS Server Configuration
#define DNS_PORT 53
#define UPSTREAM_DNS_IP "..."  // Google DNS as default upstream
#define UPSTREAM_DNS_PORT 53

// Web Server Configuration
#define WEB_SERVER_PORT 80
#define WEB_PASSWORD "admin"  // Default password for web interface

// DNS Cache Configuration
#define DNS_CACHE_SIZE 50
#define DNS_CACHE_TTL 300  // 5 minutes in seconds

// DNS Forwarding Configuration
#define DNS_FORWARD_TIMEOUT 2000  // Timeout for upstream DNS queries (milliseconds)
#define DNS_FORWARD_POLL_INTERVAL 10  // Poll interval while waiting for response (milliseconds)

// Blocklist Configuration
#define MAX_BLOCKLIST_ENTRIES 1000
#define BLOCKLIST_FILE "/blocklist.txt"

// Statistics Configuration
#define STATS_RESET_HOUR 0  // Reset stats at midnight

// Hostname Configuration
#define DEVICE_HOSTNAME "pihole-esp32"

// Debug Configuration
#define DEBUG_ENABLED true

#endif // CONFIG_H
