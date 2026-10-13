import AVFoundation
import Foundation

/// One pitch measurement. `time` is seconds since the input started.
struct PitchReading {
    var time: Double
    var midi: Double?
    var frequency: Double?
}

/// Output of the SoundAnalysis classifier.
struct SingingState: Equatable {
    var isSinging: Bool
    var label: String        // top label, e.g. "speech"
    var confidence: Double   // confidence of the singing labels (0...1)

    static let idle = SingingState(isSinging: false, label: "Listening", confidence: 0)
}

/// Anything that can supply pitch readings and singing classification: the real microphone or a simulator.
/// Both callbacks are always delivered on the main queue.
protocol AudioInput: AnyObject {
    var onReading: ((PitchReading) -> Void)? { get set }
    var onClassification: ((SingingState) -> Void)? { get set }
    /// The engine the guide-melody synth should attach to (nil for simulated input).
    var engine: AVAudioEngine? { get }
    func start() throws
    func stop()
}

enum AudioError: LocalizedError {
    case noInput
    var errorDescription: String? { "No microphone input is available. Check microphone permission in Settings." }
}

enum MicPermission {
    static var isGranted: Bool { AVAudioApplication.shared.recordPermission == .granted }
    static var isDenied: Bool { AVAudioApplication.shared.recordPermission == .denied }

    /// Asks for microphone access (shows the system prompt the first time).
    static func request() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

/// Chooses real or simulated audio. UI tests launch the app with `-uiTesting`, which cannot use a real microphone.
enum AppEnvironment {
    static let isUITesting = CommandLine.arguments.contains("-uiTesting")

    static func makeInput(for melody: Melody?) -> AudioInput {
        isUITesting ? SimulatedInput(melody: melody) : MicrophoneInput()
    }
}
