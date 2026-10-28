import SwiftUI

@main
struct MafiaGameApp: App {
    /// The game runs on the device against bots; see `Local/`.
    @State private var store = GameStore(service: LocalGameService(), identity: IdentityStore())

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .task {
                    guard !isRunningTests else { return }
                    store.start()
                }
        }
    }
}
