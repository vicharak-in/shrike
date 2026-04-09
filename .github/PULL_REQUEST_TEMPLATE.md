## What does this PR do?

<!-- Describe your changes in 1-3 sentences. -->


## Type of change

- [ ] New example
- [ ] Bug fix
- [ ] Documentation update
- [ ] Firmware improvement
- [ ] Tooling / CI
- [ ] Other

## Board(s) tested on

- [ ] Shrike-Lite (RP2040)
- [ ] Shrike (RP2350)
- [ ] Shrike-fi (ESP32-S3)
- [ ] Not hardware-dependent

## Checklist

### For all PRs:
- [ ] I have tested my changes
- [ ] My code follows the project's style guidelines
- [ ] I have updated relevant documentation (if applicable)

### For new examples:
- [ ] Follows the [standard folder structure](CONTRIBUTING.md#folder-structure) (`ffpga/`, `firmware/`, `bitstream/`, `README.md`)
- [ ] Includes pre-built bitstream in `bitstream/`
- [ ] Includes README with difficulty level, compatibility table, and expected output
- [ ] Firmware is platform-agnostic (`#ifdef` / `sys.platform`) — see [guide](docs/platform_agnostic_guide.md)
- [ ] Tested with ShrikeFlash

### For firmware changes:
- [ ] Works on RP2040
- [ ] Works on ESP32-S3 (or marked as untested in README)
- [ ] No hardcoded pin numbers (uses platform config block)

## Related issue

<!-- Link to the issue this fixes, e.g., Fixes #42. Leave blank if none. -->


## Screenshots / serial output

<!-- If applicable, paste evidence that it works. -->
