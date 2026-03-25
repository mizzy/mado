import Foundation

enum SignalHandler {
    private static var source: DispatchSourceSignal?

    static func setup(handler: @escaping () -> Void) {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            handler()
        }
        source.resume()
        self.source = source
    }
}
