import Foundation
import AppKit
import AVFoundation
import AstraCore

struct WorkspaceAttachmentImport {
    static func chooseImageFileURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Attach"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func ensureAttachmentsDirectory() throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = baseURL
            .appendingPathComponent("AstraNotes", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func importImage(from sourceURL: URL) throws -> (storagePath: String, byteSize: Int) {
        let attachmentsDirectory = try ensureAttachmentsDirectory()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destinationURL = attachmentsDirectory.appendingPathComponent("image-\(UUID().uuidString).\(fileExtension)")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
        return (destinationURL.path, values.fileSize ?? 0)
    }

    static func reveal(at storagePath: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: storagePath)])
    }

    static func open(at storagePath: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: storagePath))
    }
}

@MainActor
final class AudioRecordingController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false

    private var recorder: AVAudioRecorder?
    private var currentRecordingURL: URL?

    func start() async throws {
        guard !isRecording else {
            return
        }

        let granted = await requestMicrophoneAccess()
        guard granted else {
            throw RecordingError.microphonePermissionDenied
        }

        let attachmentsDirectory = try WorkspaceAttachmentImport.ensureAttachmentsDirectory()
        let outputURL = attachmentsDirectory.appendingPathComponent("recording-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw RecordingError.startFailed
        }

        self.recorder = recorder
        currentRecordingURL = outputURL
        isRecording = true
    }

    func stop() throws -> (storagePath: String, byteSize: Int) {
        guard isRecording, let recorder, let currentRecordingURL else {
            throw RecordingError.notRecording
        }

        recorder.stop()
        self.recorder = nil
        self.currentRecordingURL = nil
        isRecording = false

        let values = try currentRecordingURL.resourceValues(forKeys: [.fileSizeKey])
        return (currentRecordingURL.path, values.fileSize ?? 0)
    }

    func cancel() {
        recorder?.stop()
        if let currentRecordingURL {
            try? FileManager.default.removeItem(at: currentRecordingURL)
        }
        recorder = nil
        currentRecordingURL = nil
        isRecording = false
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}

enum RecordingError: Error {
    case microphonePermissionDenied
    case startFailed
    case notRecording
}
