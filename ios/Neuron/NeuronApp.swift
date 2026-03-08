import SwiftUI

@main
struct NeuronApp: App {
    @StateObject private var api = APIClient.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            if settings.isOnboarded {
                ContentView()
                    .environmentObject(api)
                    .environmentObject(settings)
            } else {
                OnboardingView()
                    .environmentObject(api)
                    .environmentObject(settings)
            }
        }
    }
}
