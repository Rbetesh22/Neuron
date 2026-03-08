import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var step = 0

    var body: some View {
        switch step {
        case 0: ServerSetupStep(onNext: { step = 1 })
        case 1: WelcomeStep(onFinish: { settings.isOnboarded = true })
        default: EmptyView()
        }
    }
}

// MARK: - Step 1: Server URL

struct ServerSetupStep: View {
    @EnvironmentObject var settings: AppSettings
    let onNext: () -> Void

    @State private var serverInput = ""
    @State private var isTesting = false
    @State private var testResult: Bool? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(UIColor.label))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text("N")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(UIColor.systemBackground))
                        )

                    VStack(spacing: 6) {
                        Text("Welcome to Neuron")
                            .font(.system(size: 26, weight: .bold))
                            .tracking(-0.4)
                        Text("Enter your server address to get started.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // Server URL input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("http://192.168.1.x:7700", text: $serverInput)
                        .font(.system(size: 15))
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor, lineWidth: 1)
                        )

                    if let result = testResult {
                        Label(
                            result ? "Connected successfully" : "Could not connect — check address",
                            systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .font(.system(size: 13))
                        .foregroundStyle(result ? Color.green : Color.red)
                        .animation(.spring(), value: testResult)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Mac's local IP, or a hosted URL (e.g. Railway/Fly.io)")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                            Text("Find your Mac's IP: System Settings → Wi-Fi → Details")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.quaternary)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if isTesting { ProgressView().tint(.white) }
                            else { Text("Test Connection") }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(serverInput.isEmpty ? Color(UIColor.systemGray4) : Color(UIColor.label))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(serverInput.isEmpty || isTesting)

                    if testResult == true {
                        Button("Continue") { onNext() }
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .animation(.spring(), value: testResult)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear { serverInput = settings.serverURL }
    }

    private var borderColor: Color {
        if let result = testResult {
            return result ? Color.green : Color.red
        }
        return Color(UIColor.separator)
    }

    private func testConnection() async {
        let url = serverInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        isTesting = true
        // Persist immediately so APIClient picks it up
        settings.serverURL = url
        do {
            _ = try await APIClient.shared.status()
            testResult = true
        } catch {
            testResult = false
        }
        isTesting = false
    }
}

// MARK: - Step 2: Welcome / integrations overview

struct WelcomeStep: View {
    let onFinish: () -> Void

    private let integrations: [(String, String, String)] = [
        ("Google Calendar & Gmail", "calendar.badge.clock", "Your schedule, emails, and context"),
        ("Canvas LMS", "graduationcap", "Courses, assignments, and deadlines"),
        ("Readwise", "books.vertical", "Highlights and articles you've saved"),
        ("GoodNotes", "pencil.and.outline", "Handwritten notes from iCloud"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("You're connected!")
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.4)
                    Text("Neuron works best with your integrations.\nConnect them anytime from the Library tab.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(spacing: 10) {
                    ForEach(integrations, id: \.0) { name, icon, desc in
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(desc)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                Button("Start using Neuron") { onFinish() }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.label))
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
