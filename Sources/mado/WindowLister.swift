import ScreenCaptureKit

enum WindowLister {
    static func getWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        return content.windows.filter { window in
            guard let app = window.owningApplication else { return false }
            guard let title = window.title, !title.isEmpty else { return false }
            // Exclude this process itself
            guard app.processID != ProcessInfo.processInfo.processIdentifier else { return false }
            return true
        }
    }

    static func printWindowList(_ windows: [SCWindow]) {
        for (index, window) in windows.enumerated() {
            let appName = window.owningApplication?.applicationName ?? "Unknown"
            let title = window.title ?? "Untitled"
            let w = Int(window.frame.width)
            let h = Int(window.frame.height)
            fputs("[\(index + 1)] \(appName) - \(title) (\(w)x\(h))\n", stderr)
        }
    }
}
