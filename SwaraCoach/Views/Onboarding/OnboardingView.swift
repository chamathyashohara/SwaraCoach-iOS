import SwiftUI

/// Three-page introduction that ends with the microphone permission request.
struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0
    @State private var pulse = false
    @State private var permissionDenied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            TabView(selection: $page) {
                pageView(icon: "waveform", title: "Sing in tune.\nSee your voice.",
                         text: "SwaraCoach listens to you sing and shows your pitch live against the melody.").tag(0)
                pageView(icon: "headphones", title: "Use headphones",
                         text: "Headphones stop the guide tone from leaking into the microphone, so only your voice is scored.").tag(1)
                pageView(icon: "mic.fill", title: "Allow the microphone",
                         text: "Your voice is analysed on your device. Audio is never recorded or sent anywhere.").tag(2)
            }
            .tabViewStyle(.page)
            .animation(reduceMotion ? nil : .easeInOut, value: page)

            if permissionDenied {
                Text("Microphone access is off. You can turn it on later in Settings > SwaraCoach.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }

            Button {
                if page < 2 { page += 1 } else { Task { await finish() } }
            } label: {
                Text(page < 2 ? "Next" : (permissionDenied ? "Continue anyway" : "Allow microphone & start"))
                    .font(.headline).frame(maxWidth: .infinity).padding()
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("onboardingNext")
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } } }
    }

    private func pageView(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Theme.brand.opacity(0.15)).frame(width: 180, height: 180).scaleEffect(pulse ? 1.12 : 0.95)
                Image(systemName: icon).font(.system(size: 72)).foregroundStyle(Theme.brand)
            }
            .accessibilityHidden(true)
            Text(title).font(.system(.largeTitle, design: .rounded).bold()).multilineTextAlignment(.center)
            Text(text).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
    }

    private func finish() async {
        if AppEnvironment.isUITesting { onFinish(); return }
        if permissionDenied { onFinish(); return }          // second tap: continue without the microphone
        let granted = MicPermission.isGranted ? true : await MicPermission.request()
        if granted { onFinish() } else { permissionDenied = true }
    }
}
