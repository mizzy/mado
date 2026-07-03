# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mado is a macOS CLI tool for recording a specific window or an entire display as MP4 (H.264) video using Apple's ScreenCaptureKit framework. It targets macOS 13.0+ and requires Swift 5.9+. No external dependencies — only Apple system frameworks.

## Build & Run

```bash
# Build (release)
swift build -c release

# Build (debug)
swift build

# Install
cp .build/release/mado /usr/local/bin/

# Usage
mado --list              # List recordable displays and windows
mado <window_number>     # Record a window
mado --screen [display_number]  # Record an entire display (defaults to the first)
mado <window_number> --delay <seconds>  # Record with countdown
```

No test suite or linter is currently configured.

## Architecture

Four source files in `Sources/mado/`:

- **main.swift** — Entry point. Initializes NSApplication (required for ScreenCaptureKit in CLI context), parses CLI args, orchestrates the list→select→countdown→record flow using async/await.
- **WindowLister.swift** — Enumerates displays and on-screen windows via `SCShareableContent`, filtering out windows without apps/titles and mado itself. Provides `getDisplays()`/`printDisplayList()` and `getWindows()`/`printWindowList()`.
- **Recorder.swift** — Core recording engine. Implements `SCStreamOutput`/`SCStreamDelegate`. Configures SCStream (2x scale, BGRA, 30 FPS) and writes H.264 MP4 via AVAssetWriter. Output files are named `mado-{ISO8601_timestamp}.mp4`.
- **SignalHandler.swift** — Intercepts SIGINT via DispatchSource for graceful recorder shutdown instead of hard exit.
