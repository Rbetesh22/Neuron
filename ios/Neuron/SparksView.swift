import SwiftUI

struct SparksView: View {
    @EnvironmentObject var api: APIClient
    @State private var sparks: [Spark] = []
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sparks.isEmpty {
                    EmptySparksView(onRetry: { Task { await load() } })
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(sparks) { spark in
                                SparkCard(spark: spark)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        loadError = false
        if let result = try? await api.sparks() {
            sparks = result.sparks
        } else {
            loadError = true
        }
        isLoading = false
    }
}

struct SparkCard: View {
    let spark: Spark
    @State private var expanded = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(spark.title ?? "Connection")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let conn = spark.connection {
                            Text(expanded ? conn : String(conn.prefix(140)) + (conn.count > 140 ? "…" : ""))
                                .font(.system(size: 13.5))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    if let recent = spark.recent_item {
                        SparkMetaRow(label: "Recent", value: recent)
                    }
                    if let past = spark.past_item {
                        SparkMetaRow(label: "Past", value: past)
                    }
                    if let why = spark.why_it_matters {
                        SparkMetaRow(label: "Why it matters", value: why)
                    }

                    // Copy connection button
                    if let conn = spark.connection {
                        Button {
                            UIPasteboard.general.string = conn
                            withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy connection", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(copied ? Color.green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SparkMetaRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .lineLimit(3)
        }
    }
}

struct EmptySparksView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            VStack(spacing: 5) {
                Text("No connections yet")
                    .font(.system(size: 17, weight: .semibold))
                Text("Add more content to your library\nand Neuron will find surprising links.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Button(action: onRetry) {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
