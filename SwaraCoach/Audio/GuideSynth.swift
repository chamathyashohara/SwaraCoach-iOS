import AVFoundation

/// A tiny sine-wave synthesizer that plays the guide melody. Generating the tone ourselves means there are no
/// audio files and no copyright issues. It runs on the same engine as the microphone input.
final class GuideSynth {
    private var node: AVAudioSourceNode!
    private var frequency: Double = 440
    private var targetAmplitude: Float = 0

    init(engine: AVAudioEngine) {
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = hardwareRate > 0 ? hardwareRate : 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        var phase = 0.0
        var amplitude: Float = 0

        node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let increment = 2 * Double.pi * self.frequency / sampleRate
            let target = self.targetAmplitude
            for frame in 0..<Int(frameCount) {
                amplitude += (target - amplitude) * 0.002          // short fade in / out avoids clicks
                let value = Float(sin(phase)) * amplitude
                phase += increment
                if phase > 2 * Double.pi { phase -= 2 * Double.pi }
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    /// Sounds the given MIDI note, or silence for nil.
    func play(midi: Int?) {
        if let midi {
            frequency = Note.frequency(forMidi: Double(midi))
            targetAmplitude = 0.22
        } else {
            targetAmplitude = 0
        }
    }

    func silence() { targetAmplitude = 0 }
}
