import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject var api: APIClient
    @State private var status: StatusResponse? = nil
    @State private var noteText = ""
    @State private var urlText = ""
    @State private var isIngesting = false
    @State private var isSyncing = false
    @State private var toast: String? = nil
    @State private var selectedSegment = 0
    @State private var showSettings = false
    @FocusState private var noteEditorFocused: Bool
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let s = status {
                        StatsCard(status: s)
                    }

                    Picker("", selection: $selectedSegment) {
                        Text("Note").tag(0)
                        Text("URL").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if selectedSegment == 0 {
                        NoteInputCard(
                            text: $noteText,
                            isIngesting: $isIngesting,
                            isFocused: $noteEditorFocused
                        ) {
                            await ingestNote()
                        }
                    } else {
                        URLInputCard(
                            text: $urlText,
                            isIngesting: $isIngesting,
                            isFocused: $urlFieldFocused
                        ) {
                            await ingestURL()
                        }
                    }

                    if let s = status, !s.sources.isEmpty {
                        SourcesCard(sources: s.sources)
                    }

                    // Sync sources button
                    Button {
                        Task { await syncSources() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(isSyncing ? "Syncing…" : "Sync sources")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSyncing)
                }
                .padding(.vertical, 16)
                .padding(.bottom, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            // Avoid keyboard obscuring content
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await loadStatus() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task { await loadStatus() }
            .overlay(alignment: .bottom) {
                if let t = toast {
                    Text(t)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.label))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toast)
        }
    }

    private func loadStatus() async {
        status = try? await api.status()
    }

    private func ingestNote() async {
        let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        isIngesting = true
        do {
            try await api.ingestNote(t)
            noteText = ""
            noteEditorFocused = false   // dismiss keyboard
            await loadStatus()
            triggerSuccessHaptic()
            showToast("Saved to library")
        } catch {
            showToast("Failed to save")
        }
        isIngesting = false
    }

    private func ingestURL() async {
        let u = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        isIngesting = true
        do {
            try await api.ingestURL(u)
            urlText = ""
            urlFieldFocused = false     // dismiss keyboard
            await loadStatus()
            triggerSuccessHaptic()
            showToast("Link saved to library")
        } catch {
            showToast("Failed to save link")
        }
        isIngesting = false
    }

    private func syncSources() async {
        isSyncing = true
        do {
            try await api.refresh()
            await loadStatus()
            triggerSuccessHaptic()
            showToast("Sources synced")
        } catch {
            showToast("Sync failed")
        }
        isSyncing = false
    }

    private func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func showToast(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { toast = nil }
    }
}

struct StatsCard: View {
    let status: StatusResponse

    var body: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(status.total_chunks)", label: "passages")
            Divider().frame(height: 40).padding(.horizontal, 20)
            StatPill(value: "\(status.sources.count)", label: "sources")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

struct NoteInputCard: View {
    @Binding var text: String
    @Binding var isIngesting: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSave: () async -> Void

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Note", systemImage: "square.and.pencil")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.8)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Jot something down…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(UIColor.placeholderText))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .focused(isFocused)
            }
            .padding(10)
            .background(Color(UIColor.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            SaveButton(isEmpty: isEmpty, isIngesting: isIngesting) {
                Task { await onSave() }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
}

struct URLInputCard: View {
    @Binding var text: String
    @Binding var isIngesting: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSave: () async -> Void

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Save a Link", systemImage: "link")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 8) {
                TextField("https://…", text: $text)
                    .font(.system(size: 15))
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused(isFocused)

                // Paste button for quick clipboard fill
                if let clip = UIPasteboard.general.string,
                   (clip.hasPrefix("http://") || clip.hasPrefix("https://")),
                   text.isEmpty {
                    Button("Paste") {
                        text = clip
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(UIColor.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            SaveButton(isEmpty: isEmpty, isIngesting: isIngesting) {
                Task { await onSave() }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
}

struct SaveButton: View {
    let isEmpty: Bool
    let isIngesting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isIngesting {
                    ProgressView().tint(.white)
                } else {
                    Text("Save to Library")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isEmpty ? Color(UIColor.systemGray4) : Color(UIColor.label))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isEmpty || isIngesting)
    }
}

struct SourcesCard: View {
    let sources: [String: Int]

    private var sorted: [(String, Int)] {
        sources.sorted { $0.value > $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sources", systemImage: "folder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(sorted, id: \.0) { name, count in
                HStack(spacing: 10) {
                    Text(sourceIcon(name))
                        .font(.system(size: 16))
                        .frame(width: 24)
                    Text(sourceName(name))
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(count) passages")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func sourceName(_ key: String) -> String {
        switch key.lowercased() {
        case "google_calendar": return "Google Calendar"
        case "gmail":           return "Gmail"
        case "canvas":          return "Canvas LMS"
        case "readwise":        return "Readwise"
        case "goodnotes":       return "GoodNotes"
        case "note":            return "Notes"
        case "url":             return "Saved Links"
        case "twitter":         return "Twitter / X"
        default:                return key.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
        }
    }

    private func sourceIcon(_ name: String) -> String {
        switch name.lowercased() {
        case "google_calendar": return "📅"
        case "gmail":           return "📧"
        case "canvas":          return "🎓"
        case "readwise":        return "📚"
        case "goodnotes":       return "📒"
        case "note":            return "📝"
        case "url":             return "🔗"
        case "twitter":         return "🐦"
        default:                return "📄"
        }
    }
}
