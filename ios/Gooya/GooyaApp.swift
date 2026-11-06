import SwiftUI

@main
struct GooyaApp: App {
    var body: some Scene {
        WindowGroup {
            StudioView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
