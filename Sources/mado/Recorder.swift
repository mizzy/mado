import AVFoundation
import CoreMedia
import ScreenCaptureKit

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream!
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let outputURL: URL
    private let queue = DispatchQueue(label: "com.mado.capture")
    private var isRecording = false
    private var sessionStarted = false

    private let streamFilter: SCContentFilter
    private let streamConfig: SCStreamConfiguration

    init(window: SCWindow) throws {
        let scaleFactor = 2.0 // Retina
        let width = Int(window.frame.width * scaleFactor)
        let height = Int(window.frame.height * scaleFactor)

        // Stream configuration
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = false
        self.streamConfig = config

        // Content filter for the specific window
        self.streamFilter = SCContentFilter(desktopIndependentWindow: window)

        // Set up AVAssetWriter
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "mado-\(timestamp).mp4"
        self.outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(filename)

        self.assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        self.videoInput.expectsMediaDataInRealTime = true

        self.assetWriter.add(self.videoInput)

        super.init()

        // Create stream with self as delegate (must be after super.init)
        self.stream = SCStream(filter: streamFilter, configuration: streamConfig, delegate: self)
        try self.stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
    }

    func start() async throws {
        assetWriter.startWriting()
        isRecording = true
        try await stream.startCapture()
        fputs("Recording... Press Ctrl+C to stop.\n", stderr)
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false

        stream.stopCapture { [self] error in
            if let error {
                fputs("Warning: stopCapture error: \(error.localizedDescription)\n", stderr)
            }
            videoInput.markAsFinished()
            assetWriter.finishWriting { [self] in
                if assetWriter.status == .failed {
                    fputs("Error: \(assetWriter.error?.localizedDescription ?? "unknown")\n", stderr)
                } else {
                    print("\(outputURL.path)")
                }
                exit(0)
            }
        }
    }

    // MARK: - SCStreamOutput

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, isRecording else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // Check frame status
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer, createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
            let statusValue = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: statusValue),
            status == .complete
        else { return }

        if !sessionStarted {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        if videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        fputs("Stream stopped with error: \(error.localizedDescription)\n", stderr)
        stop()
    }
}
