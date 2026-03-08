import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    @Published var isOnboarded: Bool {
        didSet { UserDefaults.standard.set(isOnboarded, forKey: "isOnboarded") }
    }
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }
    @Published var apiTimeout: TimeInterval {
        didSet { UserDefaults.standard.set(apiTimeout, forKey: "apiTimeout") }
    }
    @Published var hapticEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticEnabled, forKey: "hapticEnabled") }
    }

    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:7700"
        self.isOnboarded = UserDefaults.standard.bool(forKey: "isOnboarded")
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let timeout = UserDefaults.standard.double(forKey: "apiTimeout")
        self.apiTimeout = timeout > 0 ? timeout : 30
        let hapticStored = UserDefaults.standard.object(forKey: "hapticEnabled")
        self.hapticEnabled = hapticStored != nil ? UserDefaults.standard.bool(forKey: "hapticEnabled") : true
    }
}
