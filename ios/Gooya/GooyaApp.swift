import SwiftUI

@main
struct GooyaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
