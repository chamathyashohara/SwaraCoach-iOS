import SwiftUI

/// Three tabs, each with its own NavigationStack. Onboarding is shown full screen on first launch.
struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        TabView {
            NavigationStack { LibraryView() }
                .tabItem { Label("Sing", systemImage: "music.mic") }
            NavigationStack { TunerView() }
                .tabItem { Label("Tuner", systemImage: "tuningfork") }
            NavigationStack { ProgressDashboardView() }
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { if !$0 { hasOnboarded = true } })) {
            OnboardingView { hasOnboarded = true }
        }
    }
}
