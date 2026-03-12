import SwiftUI

@main
struct IstanbulApp: App {
    @State private var soundManager = SoundManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(soundManager)
        } label: {
            Image("TrayIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)

        Window("About Istanbul", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
