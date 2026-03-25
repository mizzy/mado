import AppKit
import Foundation

// NSApplication is needed for ScreenCaptureKit to work in a CLI context
// It initializes the required CoreGraphics connection
let app = NSApplication.shared

var recorder: Recorder?

// Set up signal handler for clean shutdown
SignalHandler.setup {
    recorder?.stop()
}

// Use a background task for the async flow
Task {
    do {
        // Get available windows
        let windows = try await WindowLister.getWindows()

        if windows.isEmpty {
            fputs("No windows found. Make sure Screen Recording permission is granted.\n", stderr)
            exit(1)
        }

        let args = CommandLine.arguments

        // --list or no arguments: show window list
        if args.count < 2 || args[1] == "--list" {
            fputs("Available windows:\n", stderr)
            WindowLister.printWindowList(windows)
            if args.count < 2 {
                fputs("\nUsage: mado <window-number> [--delay <seconds>]\n", stderr)
                fputs("       mado --list\n", stderr)
            }
            exit(0)
        }

        // Parse arguments
        var windowArg: String?
        var delay: UInt32 = 0

        var i = 1
        while i < args.count {
            if args[i] == "--delay", i + 1 < args.count {
                guard let d = UInt32(args[i + 1]) else {
                    fputs("Invalid delay value: \(args[i + 1])\n", stderr)
                    exit(1)
                }
                delay = d
                i += 2
            } else {
                windowArg = args[i]
                i += 1
            }
        }

        // Parse window number
        guard let windowStr = windowArg, let index = Int(windowStr),
              index >= 1, index <= windows.count else {
            fputs("Invalid window number.\n", stderr)
            fputs("Run 'mado --list' to see available windows.\n", stderr)
            exit(1)
        }

        let selectedWindow = windows[index - 1]
        let appName = selectedWindow.owningApplication?.applicationName ?? "Unknown"
        let title = selectedWindow.title ?? "Untitled"
        fputs("Selected: \(appName) - \(title)\n", stderr)

        // Set up recorder
        let rec = try Recorder(window: selectedWindow)
        recorder = rec

        // Countdown before recording
        if delay > 0 {
            for remaining in stride(from: delay, through: 1, by: -1) {
                fputs("Starting in \(remaining)...\n", stderr)
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        // Start recording
        try await rec.start()
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

// Run the main event loop (required for ScreenCaptureKit frame delivery)
app.run()
