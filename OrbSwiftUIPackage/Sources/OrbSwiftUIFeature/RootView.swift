import SwiftUI

public struct RootView: View {
    @Environment(AuthService.self) private var authService

    public init() {}

    public var body: some View {
        Group {
            if authService.isLoading {
                ZStack {
                    NColor.background.ignoresSafeArea()
                    ProgressView()
                }
            } else if authService.session != nil {
                RecordScreen()
            } else {
                AuthScreen()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.session != nil)
    }
}
