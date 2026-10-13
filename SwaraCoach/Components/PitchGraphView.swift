import SwiftUI

/// Scrolling karaoke-style pitch graph, drawn with Canvas every frame.
/// Target notes scroll right-to-left past a fixed playhead; the singer's pitch is the line ending at the playhead.
struct PitchGraphView: View {
    let melody: Melody
    let store: SampleStore
    let startDate: Date
    var secondsVisible: Double = 6

    @ScaledMetric private var rowHeight: CGFloat = 12

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = max(0, timeline.date.timeIntervalSince(startDate))
                let playheadX = size.width * 0.3
                let pixelsPerSecond = size.width / secondsVisible
                let low = Double(melody.lowestMidi - 3)
                let high = Double(melody.highestMidi + 3)

                func y(_ midi: Double) -> CGFloat {
                    let clamped = min(max(midi, low), high)
                    return size.height - CGFloat((clamped - low) / (high - low)) * size.height
                }
                func x(_ time: Double) -> CGFloat { playheadX + CGFloat(time - now) * pixelsPerSecond }

                // Faint guide lines for each note of the target range
                for midi in Int(low)...Int(high) where midi % 12 == 0 || midi % 12 == 7 {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y(Double(midi))))
                    line.addLine(to: CGPoint(x: size.width, y: y(Double(midi))))
                    context.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 1)
                }

                // Target notes (only those on screen)
                for note in melody.notes {
                    let start = note.start * melody.secondsPerBeat
                    let length = note.length * melody.secondsPerBeat
                    guard start + length > now - playheadX / pixelsPerSecond, start < now + secondsVisible else { continue }
                    let rect = CGRect(x: x(start), y: y(Double(note.midi)) - rowHeight / 2,
                                      width: CGFloat(length) * pixelsPerSecond, height: rowHeight)
                    let active = start <= now && now < start + length
                    context.fill(Path(roundedRect: rect, cornerRadius: rowHeight / 2),
                                 with: .color(Theme.brandLight.opacity(active ? 0.9 : 0.4)))
                }

                // The singer's pitch: newest samples only
                var path = Path()
                var drawing = false
                var lastPoint: CGPoint?
                var lastMidi: Double?
                for sample in store.samples.suffix(Int(secondsVisible * 60)) where sample.time > now - secondsVisible {
                    guard let midi = sample.midi, sample.isSinging else { drawing = false; continue }
                    let point = CGPoint(x: x(sample.time), y: y(midi))
                    if drawing { path.addLine(to: point) } else { path.move(to: point); drawing = true }
                    lastPoint = point
                    lastMidi = midi
                }
                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                // Playhead
                var playhead = Path()
                playhead.move(to: CGPoint(x: playheadX, y: 0))
                playhead.addLine(to: CGPoint(x: playheadX, y: size.height))
                context.stroke(playhead, with: .color(.white.opacity(0.4)), lineWidth: 1)

                // Dot at the end of the line, coloured by how close the singer is to the current target
                if let point = lastPoint, let midi = lastMidi {
                    var colour = Color.white
                    if let target = melody.targetMidi(at: now) {
                        colour = Theme.color(forCents: ScoreCalculator.centsError(sung: midi, target: target))
                    }
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(colour))
                }
            }
        }
        .background(Theme.stage)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pitch graph. Purple bars are the notes to sing, the white line is your voice.")
    }
}
