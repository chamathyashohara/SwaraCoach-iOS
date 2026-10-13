import AVFoundation
import SoundAnalysis

/// Uses Apple's built-in on-device sound classifier (SoundAnalysis, Core ML) to decide whether the
/// user is singing, talking or just making noise. Only singing is scored.
final class SingingClassifier: NSObject, SNResultsObserving {
    private var analyzer: SNAudioStreamAnalyzer?
    private let queue = DispatchQueue(label: "swaracoach.soundanalysis")
    private var singingLabels: Set<String> = []
    /// Called on the analysis queue.
    var onResult: ((SingingState) -> Void)?
    /// Minimum confidence of a singing label to count as singing. To be calibrated on a real device.
    var threshold = 0.35

    func start(format: AVAudioFormat) {
        do {
            let analyzer = SNAudioStreamAnalyzer(format: format)
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.overlapFactor = 0.5
            // Choose labels from what this model really knows, instead of guessing names.
            singingLabels = Set(request.knownClassifications.filter { id in
                let l = id.lowercased()
                return l.contains("sing") || l.contains("hum") || l.contains("choir") || l.contains("yodel")
            })
            try analyzer.add(request, withObserver: self)
            self.analyzer = analyzer
        } catch {
            // The app still works without the classifier: every pitch counts as singing.
            analyzer = nil
            print("SoundAnalysis unavailable: \(error)")
        }
    }

    /// True when classification is running. If false, the app treats all pitched sound as singing.
    var isAvailable: Bool { analyzer != nil && !singingLabels.isEmpty }

    /// Copies the buffer (the audio engine reuses its buffers) and analyses it on the background queue.
    func analyze(copyOf buffer: AVAudioPCMBuffer, at position: AVAudioFramePosition) {
        guard analyzer != nil,
              let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength),
              let source = buffer.floatChannelData, let target = copy.floatChannelData else { return }
        copy.frameLength = buffer.frameLength
        for channel in 0..<Int(buffer.format.channelCount) {
            memcpy(target[channel], source[channel], Int(buffer.frameLength) * MemoryLayout<Float>.size)
        }
        queue.async { [weak self] in self?.analyzer?.analyze(copy, atAudioFramePosition: position) }
    }

    func stop() {
        queue.async { [weak self] in
            self?.analyzer?.completeAnalysis()
            self?.analyzer = nil
        }
    }

    // MARK: SNResultsObserving

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult, let top = result.classifications.first else { return }
        let singing = singingLabels.compactMap { result.classification(forIdentifier: $0)?.confidence }.max() ?? 0
        let state = SingingState(isSinging: singing > threshold, label: top.identifier, confidence: singing)
        onResult?(state)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed: \(error)")
    }
}
