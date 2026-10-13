import SwiftData
import SwiftUI

/// Voice range test: hold your lowest and then your highest comfortable note for 2 seconds each.
struct RangeTestView: View {
    @State private var model = RangeTestViewModel()
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 24) {
            switch model.step {
            case .low: stepView(number: 1, title: "Sing your lowest\ncomfortable note", icon: "arrow.down.circle")
            case .high: stepView(number: 2, title: "Now sing your highest\ncomfortable note", icon: "arrow.up.circle")
            case .done: doneView
            }
            if let error = model.errorMessage {
                Text(error).foregroundStyle(Theme.off).multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Voice range")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    private func stepView(number: Int, title: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Text("STEP \(number) OF 2").font(.caption.bold()).foregroundStyle(.secondary)
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(Theme.brand).accessibilityHidden(true)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text("Hold it for 2 seconds on “aah”").foregroundStyle(.secondary)
            Text(model.currentName).font(.system(.largeTitle, design: .rounded).bold())
            ProgressView(value: model.holdProgress).tint(Theme.brand)
                .accessibilityLabel("Hold progress")
            if let low = model.lowestMidi {
                Text("Lowest: \(Note.name(forMidi: low))").foregroundStyle(.secondary)
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(Theme.inTune)
            if let low = model.lowestMidi, let high = model.highestMidi, let type = model.voiceType {
                Text("\(Note.name(forMidi: low)) – \(Note.name(forMidi: high))").font(.title.bold())
                Text(type.rawValue).font(.title2).foregroundStyle(Theme.brand)
            }
            Button("Save my range") { model.save(in: context) }.buttonStyle(.borderedProminent)
            Button("Test again") { model.restart(); Task { await model.start() } }
        }
    }
}
