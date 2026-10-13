import Foundation

/// Median filter over the last few pitch readings. It removes single-frame spikes and octave glitches that
/// pitch detectors produce on real voices, without delaying the line much.
struct PitchSmoother {
    private var history: [Double] = []
    private var misses = 0
    private var outliers = 0
    let size: Int

    init(size: Int = 5) { self.size = max(1, size) }

    /// Feed one raw reading (MIDI, fractional) or nil; returns the smoothed value or nil.
    mutating func smooth(_ midi: Double?) -> Double? {
        guard let value = midi else {
            misses += 1
            if misses >= 3 { history.removeAll() }   // silence long enough: forget the old note
            return nil
        }
        misses = 0
        if let last = history.last, abs(value - last) > 11 {
            // A jump of about an octave in one frame is almost always a detector error. Ignore it unless it persists.
            outliers += 1
            if outliers < 3 { return median() }
            history.removeAll()
        }
        outliers = 0
        history.append(value)
        if history.count > size { history.removeFirst() }
        return median()
    }

    private func median() -> Double? {
        guard !history.isEmpty else { return nil }
        return history.sorted()[history.count / 2]
    }
}
