import SwiftUI

@main
struct GooyaApp: App {
    init() { DebugLog.install() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
