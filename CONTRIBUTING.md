# Contributing to Shrike

Thanks for your interest in contributing to Shrike! We're building the most accessible FPGA learning ecosystem in the world — and we need your help to get there.

Whether you're fixing a bug, adding an example, improving docs, or sharing a project you built — every contribution matters.

---

## Ways to Contribute

**Add an FPGA example** — This is the single most valuable contribution you can make. New examples directly help learners. See [Submitting an Example](#submitting-an-example) below.

**Report a bug** — Something broken? [Open a bug report](../../issues/new?template=bug_report.md). Include your board variant, firmware version, and steps to reproduce.

**Improve documentation** — Found something unclear in the docs? Fix it. Typos, better wording, missing steps — all welcome as PRs against the `docs/` folder.

**Suggest a feature or example idea** — Head to [Discussions](../../discussions) and post in the Ideas category.

**Share your project** — Built something cool with Shrike? Post it in the [Show & Tell](../../discussions) category. We feature community projects in our gallery.

---

## Getting Started

### Hardware 

Off-Course You will need a hardware , you can get any of the family member. 

We also contribute hardware from time to time , if you have a idea that might be worthy of this don't hesitate to approach us.   

### Software You'll Need

| Tool | What it's for | Link |
|------|--------------|------|
| Go Configure Software Hub (GCSH) | Synthesizing FPGA bitstreams | [Download](https://www.renesas.com/en/software-tool/go-configure-software-hub) |
| Arduino IDE 2.x | Compiling and uploading MCU firmware | [Download](https://www.arduino.cc/en/software) |
| Shrike arduino library | Arduino Support library for Shrike | [GitHub](https://github.com/vicharak-in/shrike_arduino) |
| Sphinx + MyST | Building the documentation site locally | `pip install sphinx myst-parser` |
| Git | Version control | [Download](https://git-scm.com/) |

### Arduino IDE Board Packages

Install the board package for your Shrike variant:

| Board | Board Package | Board Manager URL |
|-------|--------------|-------------------|
| Shrike-Lite (RP2040) | Raspberry Pi Pico/RP2040 by Earle Philhower | `https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json` |
| Shrike (RP2350) | Raspberry Pi Pico/RP2040 by Earle Philhower | Same as above (supports RP2350) |
| Shrike-fi (ESP32-S3) | ESP32 by Espressif | `https://espressif.github.io/arduino-esp32/package_esp32_index.json` |

### Fork, Branch, Build, PR

```bash
# 1. Fork the repo on GitHub, then clone your fork
git clone https://github.com/<your-username>/shrike.git
cd shrike

# 2. Create a branch for your changes
git checkout -b feat/my-new-example

# 3. Make your changes, test on hardware

# 4. Commit with a clear message
git add .
git commit -m "feat: add PWM LED dimmer example"

# 5. Push and open a PR
git push origin feat/my-new-example
```

Then open a Pull Request against `main` on the upstream repo.

---

## Submitting an Example

Examples are the heart of this project. Here's how to submit a great one.

### Folder Structure

Every example must follow this structure:

```
examples/
└── your_example_name/
    ├── README.md              # Required — what it does, how to use it
    ├── ffpga/
    │   ├── src/
    │       └── *.v            # Verilog source files
    │
    |── images/
    │       └── output.JPG     # Photo or screenshot of expected result
    ├── firmware/
    │   ├── arduino-ide/
    │   │   └── your_example.ino
    │   └── micropython/
    │       └── your_example.py
    ├── bitstream/
    │   └── your_example.bin   # Pre-built bitstream
    └── your_example.ffpga     # GCSH project file
```

### Example README Template

Use this template for your example's README:

```markdown
# Example Name

**Difficulty:** Beginner / Intermediate / Advanced
**Uses MCU:** Yes / No
**External Hardware:** None / List what's needed

## Overview

2-3 sentences: what this example does and what you'll learn from it.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` | ✅ Tested |
| Shrike (RP2350) | `firmware/arduino-ide/` | ✅ Tested |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

Describe any wiring needed. Include a diagram if external
components are involved. If no external hardware is needed,
say "No external hardware required."

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Upload `bitstream/your_example.bin` using ShrikeFlash
3. Expected result: <what the user should see>

## Build From Source

### FPGA (Verilog)
1. Open `your_example.ffpga` in Go Configure Software Hub
2. Click Synthesize → Generate Bitstream
3. Output will be in `ffpga/build/`

### Firmware (Arduino)
1. Open `firmware/arduino-ide/your_example.ino` in Arduino IDE
2. Select your board (Raspberry Pi Pico or ESP32-S3)
3. Upload

## How It Works

Brief technical explanation of the Verilog logic and/or
firmware. Keep it educational — explain *why*, not just *what*.

## Expected Output

Describe or show what happens when the example runs correctly.
Include a photo, serial output, or link to a video.
```

### Pre-Built Bitstreams

Every example **must** include a pre-built `.bin` file in the `bitstream/` folder. This lets beginners try the example immediately without installing GCSH.

Build the bitstream in GCSH, copy the output `.bin` file into `bitstream/`, and commit it.

### Platform-Agnostic Firmware

If your example includes MCU firmware, write it to support all Shrike boards from a single source file using compile-time (`#ifdef`) or runtime (`sys.platform`) detection.

See the [Platform-Agnostic Firmware Guide](docs/platform_agnostic_guide.md) for patterns and examples.

### Naming Conventions

- Folder names: `snake_case` (e.g., `uart_sum`, `led_chaser`, `pwm_dimmer`)
- Verilog files: `snake_case.v` (e.g., `uart_rx.v`, `top.v`)
- Arduino sketches: `snake_case.ino` matching the folder name
- MicroPython scripts: `snake_case.py` matching the folder name
- Bitstream files: match the example folder name (e.g., `uart_sum.bin`)

---

## Submitting a Bug Fix or Improvement

1. Check [open issues](../../issues) to see if someone already reported it
2. If not, [open an issue](../../issues/new) first so we can discuss the approach
3. Fork, branch, fix, test on hardware, submit PR
4. Reference the issue number in your PR description (e.g., `Fixes #42`)

---

## Documentation Contributions

The documentation site is built with Sphinx and MyST Markdown. Source files live in `docs/`.

### Building Docs Locally

```bash
cd docs
pip install -r requirements.txt
make html
# Open _build/html/index.html in your browser
```

### What We're Looking For

- Clearer explanations of existing content
- New troubleshooting entries (every common question should be documented)
- Translations
- Wiring diagrams and visual aids

---

## Pull Request Guidelines

### Good PRs

- **Focused** — One feature, one fix, or one example per PR
- **Tested** — Verified on actual hardware (state which board you tested on)
- **Documented** — Include a README for examples; update docs if behavior changes
- **Complete** — Include the bitstream, firmware, and images

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add SPI loopback example
fix: correct pin mapping for ESP32-S3 in ultrasonic example
docs: add troubleshooting entry for LittleFS upload failure
refactor: extract platform config into shared header
```

Prefixes: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

### What to Avoid

We appreciate enthusiasm, but please avoid PRs for:

- Minor rewording that doesn't improve clarity
- Typo fixes in comments (open an issue instead; we batch these)
- Formatting-only changes (indentation, whitespace)
- Changes that haven't been tested on hardware

These create noise in the review queue. If you spot something small, open an **issue** so we can batch improvements together.

---

## Code Style

### Verilog

Follow the [Verilog Style Guide](https://vicharak-in.github.io/shrike/verilog_style_guide.html) in the documentation. Key points:

- Use `snake_case` for signal and module names
- One module per file
- Comment the purpose of each module at the top
- Use parameterized designs where it makes sense

### Arduino / C++

- Use `camelCase` for variables and functions
- Use `UPPER_CASE` for `#define` constants and pin definitions
- Keep platform-specific code in a clearly marked block at the top
- Use `Serial.println()` for debug output — it helps users troubleshoot

### MicroPython

- Follow PEP 8
- Use `snake_case` for variables and functions
- Keep platform config in a dict at the top of the file
- Add docstrings to functions

---

## Community

### Where to Find Us

- **Discord** — [Join](https://discord.com/invite/EhQy97CQ9G) for real-time help and discussion
- **GitHub Discussions** — For longer-form questions, ideas, and show & tell
- **Twitter/X** — [@Vicharak_In](https://x.com/Vicharak_In)
- **Forum** — [discuss.vicharak.in](https://discuss.vicharak.in/)


## License

By contributing to Shrike, you agree that your contributions will be licensed under the [GNU General Public License v2.0](LICENSE.md), the same license that covers the project.

---

Thank you for helping make FPGA technology accessible to everyone.
