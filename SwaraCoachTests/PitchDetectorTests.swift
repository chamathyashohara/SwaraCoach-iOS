import XCTest
@testable import SwaraCoach

/// Generates a perfect sine wave so the detector can be tested without a microphone.
func sine(_ hz: Double, sampleRate: Double = 44_100, count: Int = 2048, amplitude: Double = 0.5) -> [Float] {
    (0..<count).map { Float(amplitude * sin(2 * .pi * hz * Double($0) / sampleRate)) }
}

final class PitchDetectorTests: XCTestCase {
    let detector = PitchDetector()

    func testDetectsPureTonesWithinOnePercent() throws {
        for hz in [110.0, 196.0, 261.63, 440.0, 880.0] {
            let detected = try XCTUnwrap(detector.detect(samples: sine(hz), sampleRate: 44_100), "no pitch for \(hz) Hz")
            XCTAssertEqual(detected, hz, accuracy: hz * 0.01, "wrong pitch for \(hz) Hz")
        }
    }

    func testWorksAt48kHz() throws {
        let detected = try XCTUnwrap(detector.detect(samples: sine(330, sampleRate: 48_000), sampleRate: 48_000))
        XCTAssertEqual(detected, 330, accuracy: 3.3)
    }

    func testSilenceReturnsNil() {
        XCTAssertNil(detector.detect(samples: [Float](repeating: 0, count: 2048), sampleRate: 44_100))
    }

    func testQuietNoiseFloorReturnsNil() {
        XCTAssertNil(detector.detect(samples: sine(440, amplitude: 0.005), sampleRate: 44_100))
    }

    func testHarmonicRichToneFindsFundamental() throws {
        let hz = 220.0
        let samples: [Float] = (0..<2048).map { i in
            let t = Double(i) / 44_100
            let value = (1.0 * sin(2 * .pi * hz * t) + 0.6 * sin(2 * .pi * 2 * hz * t) + 0.4 * sin(2 * .pi * 3 * hz * t)) * 0.2
            return Float(value)
        }
        let detected = try XCTUnwrap(detector.detect(samples: samples, sampleRate: 44_100))
        XCTAssertEqual(detected, hz, accuracy: hz * 0.01)
    }

    func testTooShortBufferReturnsNil() {
        XCTAssertNil(detector.detect(samples: sine(440, count: 16), sampleRate: 44_100))
    }

    func testPerformanceOfOneWindow() {
        let samples = sine(220)
        measure { for _ in 0..<50 { _ = detector.detect(samples: samples, sampleRate: 44_100) } }
    }
}

final class PitchSmootherTests: XCTestCase {
    func testMedianRemovesSingleSpike() throws {
        var smoother = PitchSmoother(size: 5)
        var last: Double?
        for value in [60.0, 60.1, 60.0, 72.0, 60.1] { last = smoother.smooth(value) }
        XCTAssertEqual(try XCTUnwrap(last), 60.0, accuracy: 0.2)
    }

    func testSilenceForgetsHistory() {
        var smoother = PitchSmoother(size: 5)
        _ = smoother.smooth(60)
        for _ in 0..<3 { XCTAssertNil(smoother.smooth(nil)) }
        // After silence, a new, distant note is accepted straight away.
        XCTAssertEqual(smoother.smooth(72) ?? 0, 72, accuracy: 0.01)
    }

    func testPersistentJumpIsAcceptedAfterThreeFrames() {
        var smoother = PitchSmoother(size: 5)
        for _ in 0..<5 { _ = smoother.smooth(60) }
        var value = 0.0
        for _ in 0..<8 { value = smoother.smooth(72) ?? value }
        XCTAssertEqual(value, 72, accuracy: 0.01)
    }
}
