# Configuration Setup

## Quick Start

1. **Copy the template file:**
   ```bash
   cp config.h.template config.h
   ```

2. **Edit config.h with your settings:**
   - Set your WiFi SSID and password
   - Optionally configure DNS settings
   - Optionally adjust other parameters

3. **Build and upload to ESP32**

## Important Notes

- **config.h is in .gitignore** - Your actual credentials will NOT be committed to Git
- **config.h.template** - Template file with placeholders (safe to commit)
- **config.h.example** - Alternative example with detailed comments (safe to commit)

## Never Commit Credentials!

The actual `config.h` file with your WiFi password should NEVER be committed to version control. This is why it's in `.gitignore`.

Always use the template:
```bash
cp config.h.template config.h
# Edit config.h with your credentials
```

## Configuration Options

See `config.h.template` or `config.h.example` for all available configuration options with detailed comments.
