import SwiftUI
import UIKit

struct AskView: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var settings: AppSettings
    @State private var query = ""
    @State private var messages: [Message] = []
    @State private var isStreaming = false
    @State private var streamingStarted = false   // true once first token arrives
    @State private var sources: [SourceChunk] = []
    @State private var streamVersion: Int = 0
    @State private var streamingTask: Task<Void, Never>? = nil
    @FocusState private var inputFocused: Bool

    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        var text: String
        enum Role { case user, assistant }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if messages.isEmpty {
                                EmptyAskView { suggestion in
                                    // Fill query but don't auto-send — let user confirm
                                    query = suggestion
                                    inputFocused = true
                                }
                                .padding(.top, 40)
                            } else {
                                ForEach(messages) { msg in
                                    MessageBubble(message: msg, isStreaming: isStreaming && msg.id == messages.last?.id && msg.role == .assistant && !streamingStarted)
                                        .id(msg.id)
                                }
                                if !sources.isEmpty {
                                    SourcesBar(sources: sources)
                                        .padding(.horizontal, 16)
                                        .id("sources")
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: streamVersion) { _, _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }

                Divider()

                // Input bar
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Ask anything…", text: $query, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .lineLimit(1...6)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .focused($inputFocused)
                        .submitLabel(.send)
                        .onSubmit { sendQuery() }

                    Button(action: isStreaming ? cancelStreaming : sendQuery) {
                        Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(query.isEmpty && !isStreaming ? .quaternary : .primary)
                    }
                    .disabled(query.isEmpty && !isStreaming)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .padding(.bottom, 4)
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !messages.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                messages = []
                                sources = []
                            }
                        } label: {
                            Text("Clear")
                                .font(.system(size: 15))
                        }
                    }
                }
            }
        }
    }

    private func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        streamingStarted = false
    }

    private func sendQuery() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isStreaming else { return }
        query = ""
        inputFocused = false
        sources = []
        streamingStarted = false

        // Haptic feedback on send
        if settings.hapticEnabled {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        messages.append(Message(role: .user, text: q))
        let answerMsg = Message(role: .assistant, text: "")
        let answerID = answerMsg.id
        messages.append(answerMsg)
        isStreaming = true

        streamingTask = Task { @MainActor in
            do {
                let stream = try api.askStream(query: q)
                for try await event in stream {
                    guard let idx = messages.firstIndex(where: { $0.id == answerID }) else { continue }
                    switch event {
                    case .token(let t):
                        streamingStarted = true
                        messages[idx].text += t
                        streamVersion &+= 1
                    case .sources(let srcs):
                        sources = srcs
                    case .done(let finalAnswer, let srcs):
                        if !finalAnswer.isEmpty { messages[idx].text = finalAnswer }
                        if let srcs { sources = srcs }
                    }
                }
            } catch is CancellationError {
                // User cancelled — leave partial text in place
            } catch {
                if let idx = messages.firstIndex(where: { $0.id == answerID }) {
                    messages[idx].text = "Error: \(error.localizedDescription)"
                }
            }
            isStreaming = false
            streamingStarted = false
            streamingTask = nil
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.3 : 0.85)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear { phase = 0 }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AskView.Message
    let isStreaming: Bool

    private var parsedText: AttributedString {
        renderMarkdown(message.text)
    }

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 60) }

            Group {
                if message.role == .assistant {
                    if isStreaming && message.text.isEmpty {
                        // Show bouncing dots when streaming but no tokens yet
                        TypingIndicatorView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 4)
                    } else {
                        Text(message.text.isEmpty ? "…" : parsedText)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                            .textSelection(.enabled)
                    }
                } else {
                    Text(message.text)
                        .font(.system(size: 15))
                        .lineSpacing(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.label))
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .textSelection(.enabled)
                }
            }

            if message.role == .user { EmptyView() }
        }
    }
}

// MARK: - Sources Bar

struct SourcesBar: View {
    let sources: [SourceChunk]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sources.prefix(6)) { src in
                        sourceCard(src)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func sourceCard(_ src: SourceChunk) -> some View {
        let cardContent = VStack(alignment: .leading, spacing: 3) {
            Text(src.icon ?? "📌")
                .font(.system(size: 14))
            Text(src.title ?? "Source")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.primary)
            Text(src.source ?? "")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(width: 110, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))

        if let urlStr = src.url, let url = URL(string: urlStr) {
            Link(destination: url) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }
}

// MARK: - Empty Ask View

struct EmptyAskView: View {
    let onSuggestion: (String) -> Void

    private let suggestions = [
        "What am I working on this week?",
        "Summarize my recent meetings",
        "What's due soon in my courses?",
        "What have I been reading lately?",
    ]

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Ask Neuron")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.5)
                Text("Search across everything you've saved,\nnoted, read, or attended.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 6) {
                ForEach(suggestions, id: \.self) { s in
                    Button { onSuggestion(s) } label: {
                        Text(s)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
