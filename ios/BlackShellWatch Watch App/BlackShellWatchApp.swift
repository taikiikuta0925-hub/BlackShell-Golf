import SwiftUI

@main
struct BlackShellWatchApp: App {
  @StateObject private var roundStore = WatchRoundStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(roundStore)
    }
  }
}
