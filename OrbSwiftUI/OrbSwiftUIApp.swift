import SwiftUI
import OrbSwiftUIFeature

@main
struct OrbSwiftUIApp: App {
    @State private var authService = AuthService()

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
        }
    }
}
