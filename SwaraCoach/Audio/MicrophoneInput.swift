import AVFoundation
import Foundation

/// Real microphone input: AVAudioEngine tap -> sample buffer -> YIN pitch detection, plus SoundAnalysis classification.
///
/// Threading: the tap callback runs on a real-time audio thread. It only copies the samples and hands them to a serial
/// analysis queue. Pitch maths and classification run on that queue; results are delivered on the main queue.
final class MicrophoneInput: AudioInput {
    let audioEngine = AVAudioEngine()
    var engine: AVAudioEngine? { audioEngine }

    var onReading: ((PitchReading) -> Void)?
    var onClassification: ((SingingState) -> Void)?

    private let queue = DispatchQueue(label: "swaracoach.analysis", qos: .userInitiated)
    private let detector = PitchDetector()
    private let classifier = SingingClassifier()
    private var smoother = PitchSmoother(size: 5)

    /// iOS may deliver buffers of any size, so we collect samples and analyse a fixed window every `hop` samples.
    private let windowSize = 2048
    private let hop = 1024
    private var pending: [Float] = []
    private var framesConsumed = 0   // samples already moved past by the hop (gives the time axis)
    private var running = false

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Without permission or a microphone the format is empty; installing a tap with it would crash.
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioError.noInput }
        let sampleRate = format.sampleRate

        pending.removeAll(keepingCapacity: true)
        framesConsumed = 0
        smoother = PitchSmoother(size: 5)
        running = true

        classifier.onResult = { [weak self] state in
            DispatchQueue.main.async { self?.onClassification?(state) }
        }
        classifier.start(format: format)

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
            guard let self, let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: count))
            self.classifier.analyze(copyOf: buffer, at: time.sampleTime)
            self.queue.async { self.process(samples, sampleRate: sampleRate) }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() {
        guard running else { return }
        running = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        classifier.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Runs on the analysis queue.
    private func process(_ samples: [Float], sampleRate: Double) {
        pending.append(contentsOf: samples)
        while pending.count >= windowSize {
            let window = Array(pending[0..<windowSize])
            let frequency = detector.detect(samples: window, sampleRate: sampleRate)
            let midi = smoother.smooth(frequency.map { Note(frequency: $0).midi })
            // Time at the middle of the window.
            let time = (Double(framesConsumed) + Double(windowSize) / 2) / sampleRate
            let reading = PitchReading(time: time, midi: midi, frequency: midi.map { Note.frequency(forMidi: $0) })
            DispatchQueue.main.async { [weak self] in self?.onReading?(reading) }
            pending.removeFirst(hop)
            framesConsumed += hop
        }
    }
}
