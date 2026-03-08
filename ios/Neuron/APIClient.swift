import Foundation
import Combine

// MARK: - Response Models

struct StatusResponse: Codable {
    let total_chunks: Int
    let sources: [String: Int]
}

struct DigestResponse: Codable {
    let result: String
    let cached_at: String?
}

struct NewsResponse: Codable {
    let articles: [NewsArticle]
    let by_category: [String: [NewsArticle]]
    let cached_at: String?
}

struct NewsArticle: Codable, Identifiable {
    var id: String { url }
    let title: String
    let url: String
    let description: String?
    let image: String?
    let category: String
    let source: String
}

struct NewsSummaryResponse: Codable {
    let summary: String
}

struct SparkResponse: Codable {
    let sparks: [Spark]
    let cached_at: String?
}

struct Spark: Codable, Identifiable {
    var id: String { (title ?? "") + (recent_item ?? "") }
    let title: String?
    let connection: String?
    let why_it_matters: String?
    let recent_item: String?
    let past_item: String?
}

struct DailyResponse: Codable {
    let fact: String?
    let vocab: VocabWord?
    let cached_at: String?
}

struct VocabWord: Codable {
    let word: String?
    let pronunciation: String?
    let part_of_speech: String?
    let definition: String?
    let etymology: String?
    let example: String?
}

struct AskRequest: Codable {
    let q: String
    let n_results: Int
}

struct Recommendation: Codable, Identifiable {
    var id: String { title + type }
    let type: String
    let title: String
    let author_or_show: String?
    let why: String?
    let link: String?
    let link_label: String?
    let link2: String?
    let link2_label: String?
}

struct RecommendationsResponse: Codable {
    let recommendations: [Recommendation]
}

struct IngestTextRequest: Codable {
    let text: String
    let source: String
}

struct AskStreamEvent: Codable {
    let type: String
    let text: String?
    let answer: String?
    let sources: [SourceChunk]?
    let detail: String?
}

struct SourceChunk: Codable, Identifiable {
    var id: String { (title ?? "") + (source ?? "") }
    let title: String?
    let source: String?
    let excerpt: String?
    let full_text: String?
    let url: String?
    let icon: String?
    let index: Int?
}

// MARK: - API Client

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    private var baseURL: String { AppSettings.shared.serverURL }

    // MARK: - Status

    func status() async throws -> StatusResponse {
        try await get("/status")
    }

    // MARK: - Digest

    func digest(refresh: Bool = false) async throws -> DigestResponse {
        try await get("/digest\(refresh ? "?refresh=true" : "")")
    }

    // MARK: - News

    func news() async throws -> NewsResponse {
        try await get("/news")
    }

    func newsSummary() async throws -> NewsSummaryResponse {
        try await get("/news/summary")
    }

    // MARK: - Sparks

    func sparks() async throws -> SparkResponse {
        try await get("/spark?days_recent=14&days_old=60")
    }

    // MARK: - Recommendations

    func recommendations() async throws -> RecommendationsResponse {
        try await get("/recommendations")
    }

    // MARK: - Daily

    func daily() async throws -> DailyResponse {
        try await get("/daily")
    }

    // MARK: - Ask (streaming)

    enum AskEvent {
        case token(String)
        case sources([SourceChunk])
        case done(String, [SourceChunk]?)
    }

    func askStream(query: String) throws -> AsyncThrowingStream<AskEvent, Error> {
        guard let url = URL(string: baseURL + "/ask/stream") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AskRequest(q: query, n_results: 25))

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (stream, _) = try await URLSession.shared.bytes(for: req)
                    for try await line in stream.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let data = json.data(using: .utf8),
                              let event = try? JSONDecoder().decode(AskStreamEvent.self, from: data)
                        else { continue }

                        switch event.type {
                        case "token":
                            let t = event.text ?? ""
                            continuation.yield(.token(t))
                        case "sources":
                            if let srcs = event.sources {
                                continuation.yield(.sources(srcs))
                            }
                        case "done":
                            continuation.yield(.done(event.answer ?? "", event.sources))
                        default: break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Ingest

    func ingestNote(_ text: String) async throws {
        struct Req: Codable { let text: String; let source: String }
        try await post("/ingest/text", body: Req(text: text, source: "note"))
    }

    func ingestURL(_ urlStr: String) async throws {
        struct Req: Codable { let url: String }
        try await post("/ingest/url", body: Req(url: urlStr))
    }

    // MARK: - Refresh

    func refresh() async throws {
        struct Empty: Codable {}
        try await post("/refresh", body: Empty())
    }

    // MARK: - Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    @discardableResult
    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<B: Encodable>(_ path: String, body: B) async throws {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await URLSession.shared.data(for: req)
    }
}
