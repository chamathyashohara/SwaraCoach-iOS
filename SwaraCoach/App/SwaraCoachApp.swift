import SwiftData
import SwiftUI

@main
struct SwaraCoachApp: App {
    private let container: ModelContainer

    init() {
        // UI tests use an in-memory store so every launch starts empty and nothing is saved to disk.
        do {
            container = try Persistence.makeContainer(inMemory: AppEnvironment.isUITesting)
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.brand)
        }
        .modelContainer(container)
    }
}
