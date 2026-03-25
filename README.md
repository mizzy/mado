# mado

A macOS CLI tool for recording a specific window as MP4 (H.264) using ScreenCaptureKit.

## Requirements

- macOS 13.0+
- Swift 5.9+

## Install

```bash
swift build -c release
cp .build/release/mado /usr/local/bin/
```

## Usage

```bash
# List available windows
mado

# Record a window (Ctrl+C to stop)
mado 3

# Start recording after a countdown
mado 3 --delay 5
```

The output file is saved to the current directory as `mado-{timestamp}.mp4`.

## Permissions

Screen Recording permission is required. On first run, grant permission to your terminal app (Terminal.app / iTerm2 / etc.) in System Settings > Privacy & Security > Screen Recording.
