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
        let args = CommandLine.arguments

        // --list or no arguments: show display and window lists
        if args.count < 2 || args[1] == "--list" {
            let displays = try await WindowLister.getDisplays()
            let windows = try await WindowLister.getWindows()

            if displays.isEmpty && windows.isEmpty {
                fputs("Nothing found. Make sure Screen Recording permission is granted.\n", stderr)
                exit(1)
            }

            fputs("Available displays:\n", stderr)
            WindowLister.printDisplayList(displays)
            fputs("\nAvailable windows:\n", stderr)
            WindowLister.printWindowList(windows)
            if args.count < 2 {
                fputs("\nUsage: mado <window-number> [--delay <seconds>]\n", stderr)
                fputs("       mado --screen [display-number] [--delay <seconds>]\n", stderr)
                fputs("       mado --list\n", stderr)
            }
            exit(0)
        }

        // Parse arguments
        var windowArg: String?
        var screenMode = false
        var displayArg: String?
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
            } else if args[i] == "--screen" {
                screenMode = true
                if i + 1 < args.count, Int(args[i + 1]) != nil {
                    displayArg = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            } else {
                windowArg = args[i]
                i += 1
            }
        }

        let rec: Recorder

        if screenMode {
            let displays = try await WindowLister.getDisplays()

            if displays.isEmpty {
                fputs("No displays found. Make sure Screen Recording permission is granted.\n", stderr)
                exit(1)
            }

            // Default to the first display when no number is given
            let index = displayArg.flatMap(Int.init) ?? 1
            guard index >= 1, index <= displays.count else {
                fputs("Invalid display number.\n", stderr)
                fputs("Run 'mado --list' to see available displays.\n", stderr)
                exit(1)
            }

            let selectedDisplay = displays[index - 1]
            let w = Int(selectedDisplay.frame.width)
            let h = Int(selectedDisplay.frame.height)
            fputs("Selected: Display \(selectedDisplay.displayID) (\(w)x\(h))\n", stderr)

            rec = try Recorder(display: selectedDisplay)
        } else {
            let windows = try await WindowLister.getWindows()

            if windows.isEmpty {
                fputs("No windows found. Make sure Screen Recording permission is granted.\n", stderr)
                exit(1)
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

            rec = try Recorder(window: selectedWindow)
        }

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
