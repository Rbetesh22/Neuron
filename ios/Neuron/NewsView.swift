import SwiftUI

struct NewsView: View {
    @EnvironmentObject var api: APIClient
    @State private var byCategory: [String: [NewsArticle]] = [:]
    @State private var summary: String = ""
    @State private var selectedCat: String = "All"
    @State private var isLoading = true

    private let catOrder = ["World", "Israel", "Politics", "Tech", "AI", "Finance", "Sports", "Torah"]

    private var allCats: [String] {
        let present = catOrder.filter { byCategory[$0] != nil }
        let extra = byCategory.keys.filter { !catOrder.contains($0) }.sorted()
        return ["All"] + present + extra
    }

    private var displayArticles: [NewsArticle] {
        if selectedCat == "All" {
            return catOrder.flatMap { byCategory[$0] ?? [] } + byCategory.filter { !catOrder.contains($0.key) }.values.flatMap { $0 }
        }
        return byCategory[selectedCat] ?? []
    }

    private func articleCount(for cat: String) -> Int {
        if cat == "All" {
            return byCategory.values.reduce(0) { $0 + $1.count }
        }
        return byCategory[cat]?.count ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Briefing summary
                if !summary.isEmpty {
                    ScrollView {
                        let attrSummary = (try? AttributedString(markdown: summary)) ?? AttributedString(summary)
                        Text(attrSummary)
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(maxHeight: 180)
                    .background(Color(UIColor.secondarySystemGroupedBackground))

                    Divider()
                }

                // Category tabs with ScrollViewReader for auto-scroll
                ScrollViewReader { tabProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allCats, id: \.self) { cat in
                                let count = articleCount(for: cat)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCat = cat
                                    }
                                    withAnimation {
                                        tabProxy.scrollTo(cat, anchor: .center)
                                    }
                                } label: {
                                    Text(count > 0 && cat != "All" ? "\(cat) (\(count))" : cat)
                                        .font(.system(size: 13, weight: selectedCat == cat ? .semibold : .regular))
                                        .foregroundStyle(selectedCat == cat ? Color(UIColor.systemBackground) : .secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(selectedCat == cat ? Color(UIColor.label) : Color.clear)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color(UIColor.separator), lineWidth: selectedCat == cat ? 0 : 0.5))
                                }
                                .id(cat)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: selectedCat) { _, newCat in
                        withAnimation {
                            tabProxy.scrollTo(newCat, anchor: .center)
                        }
                    }
                }

                Divider()

                // Articles
                if isLoading {
                    Spacer()
                    ProgressView("Loading news…")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(displayArticles.enumerated()), id: \.element.id) { idx, article in
                                NewsRow(article: article, isFirst: idx == 0 && selectedCat == "All")
                                    .padding(.horizontal, 16)
                                if idx < displayArticles.count - 1 { Divider().padding(.horizontal, 16) }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Today's World")
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
        async let newsTask = try? api.news()
        async let sumTask = try? api.newsSummary()
        let (news, sum) = await (newsTask, sumTask)
        byCategory = news?.by_category ?? [:]
        summary = sum?.summary ?? ""
        isLoading = false
    }
}

struct NewsRow: View {
    let article: NewsArticle
    let isFirst: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(article.source.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.4)

                Link(destination: URL(string: article.url) ?? URL(string: "https://google.com")!) {
                    Text(article.title)
                        .font(.system(size: isFirst ? 17 : 14, weight: isFirst ? .bold : .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(isFirst ? 3 : 2)
                        .lineSpacing(2)
                }
                .buttonStyle(.plain)

                if isFirst, let desc = article.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let imgStr = article.image, let imgURL = URL(string: imgStr) {
                    AsyncImage(url: imgURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(UIColor.systemGray5)
                    }
                    .frame(width: isFirst ? 100 : 72, height: isFirst ? 70 : 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let url = URL(string: article.url) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 12)
    }
}
