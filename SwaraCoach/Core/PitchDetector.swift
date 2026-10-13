import Accelerate
import Foundation

/// Monophonic pitch detection with the YIN algorithm (de Cheveigné & Kawahara, 2002).
///
/// Idea: a periodic signal looks like itself when shifted by one period. For every shift ("lag") we measure how
/// different the signal is from its shifted copy, normalise that, and take the first lag where the difference
/// is small. The period in samples converts to a frequency: f = sampleRate / lag.
/// The inner loop uses Accelerate (vDSP) so it runs on the CPU's vector unit.
struct PitchDetector {
    var minFrequency: Double = 70      // about C#2, low male voice
    var maxFrequency: Double = 1100    // about C#6, high soprano
    var threshold: Float = 0.15        // YIN absolute threshold: lower is stricter
    var silenceRMS: Float = 0.01       // below this level the input counts as silence

    /// Returns the fundamental frequency in Hz, or nil for silence / unclear sound.
    func detect(samples: [Float], sampleRate: Double) -> Double? {
        let n = samples.count
        guard n >= 64, sampleRate > 0 else { return nil }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(n))
        guard rms > silenceRMS else { return nil }

        let minLag = max(2, Int(sampleRate / maxFrequency))
        let maxLag = min(n / 2, Int(sampleRate / minFrequency))
        guard maxLag > minLag + 2 else { return nil }
        let window = n - maxLag

        // Step 1: difference function d(lag) = sum over i of (x[i] - x[i + lag])^2.
        var diff = [Float](repeating: 0, count: maxLag + 1)
        var scratch = [Float](repeating: 0, count: window)
        samples.withUnsafeBufferPointer { x in
            let base = x.baseAddress!
            for lag in 1...maxLag {
                // scratch = x[0..<window] - x[lag..<lag + window]
                vDSP_vsub(base + lag, 1, base, 1, &scratch, 1, vDSP_Length(window))
                var sum: Float = 0
                vDSP_svesq(scratch, 1, &sum, vDSP_Length(window))
                diff[lag] = sum
            }
        }

        // Step 2: cumulative mean normalised difference, which removes the "lag 0 looks perfect" bias.
        var cmnd = [Float](repeating: 1, count: maxLag + 1)
        var running: Float = 0
        for lag in 1...maxLag {
            running += diff[lag]
            cmnd[lag] = running > 0 ? diff[lag] * Float(lag) / running : 1
        }

        // Step 3: first lag that dips below the threshold, then walk down to the bottom of that dip.
        var lag = minLag
        while lag < maxLag {
            if cmnd[lag] < threshold {
                while lag + 1 < maxLag && cmnd[lag + 1] < cmnd[lag] { lag += 1 }
                // Step 4: parabolic interpolation around the minimum for sub-sample accuracy.
                let a = cmnd[lag - 1], b = cmnd[lag], c = cmnd[lag + 1]
                let denominator = a + c - 2 * b
                let shift = denominator != 0 ? Double((a - c) / (2 * denominator)) : 0
                return sampleRate / (Double(lag) + shift)
            }
            lag += 1
        }
        return nil
    }
}
