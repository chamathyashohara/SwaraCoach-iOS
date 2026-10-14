import AVFoundation

/// Reads an audio file the user picked and extracts its melody. Only the notes are kept; the audio itself is
/// never copied or stored by the app.
enum AudioFileAnalyzer {
    enum AnalysisError: LocalizedError {
        case unreadable
        case noMelody

        var errorDescription: String? {
            switch self {
            case .unreadable: return "That file could not be read as audio."
            case .noMelody: return "No clear melody was found. This works best with a solo voice, humming or a single instrument, without a band behind it."
            }
        }
    }

    /// Decodes up to the first 90 seconds, mixes to mono, lowers the sample rate to about 22 kHz (cheaper for the
    /// pitch detector and plenty for notes below C6) and extracts the melody. Run it off the main thread.
    static func extractMelody(from url: URL, settings: MelodyExtractor.Settings = MelodyExtractor.Settings()) throws -> [MelodyNote] {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) } catch { throw AnalysisError.unreadable }

        let format = file.processingFormat
        let wanted = min(Double(file.length), settings.maxSeconds * format.sampleRate)
        let frameCount = AVAudioFrameCount(wanted)
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AnalysisError.unreadable
        }
        do { try file.read(into: buffer, frameCount: frameCount) } catch { throw AnalysisError.unreadable }
        guard let channels = buffer.floatChannelData else { throw AnalysisError.unreadable }

        let length = Int(buffer.frameLength)
        let channelCount = max(1, Int(format.channelCount))
        let factor = max(1, Int(format.sampleRate / 22050))
        let outCount = length / factor
        guard outCount > settings.windowSize else { throw AnalysisError.noMelody }

        var mono = [Float](repeating: 0, count: outCount)
        for i in 0..<outCount {
            var sum: Float = 0
            for c in 0..<channelCount {
                for k in 0..<factor { sum += channels[c][i * factor + k] }
            }
            mono[i] = sum / Float(channelCount * factor)
        }

        let notes = MelodyExtractor.extract(samples: mono, sampleRate: format.sampleRate / Double(factor), settings: settings)
        guard notes.count >= 3 else { throw AnalysisError.noMelody }
        return notes
    }
}
