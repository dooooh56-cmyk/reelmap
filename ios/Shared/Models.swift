import Foundation

struct Place: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    var lotAddress: String?
    let lat: Double
    let lng: Double
    let category: String
    let url: String
    var source: String?
    var savedAt: String?
}
struct PendingPost: Codable, Identifiable {
    var id = UUID().uuidString
    let url: String
    let text: String
    let reason: String
    var createdAt = ISO8601DateFormatter().string(from: Date())
}
struct LibraryData: Codable {
    var places: [Place] = []
    var pending: [PendingPost] = []
}
struct Entity: Codable { let name: String; let address: String; let evidence: String; let evidenceSource: String }
struct CandidateGroup: Codable, Identifiable {
    var id: String { entity.name + entity.address }
    let entity: Entity
    let places: [Place]
    let verified: Bool
    let matchedID: String?
}
struct TokenUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let thinkingTokens: Int
    let totalTokens: Int
}
struct Analysis: Codable {
    let status: String
    let groups: [CandidateGroup]
    let source: String
    let warnings: [String]
    let method: String
    let mediaAnalyzed: Bool
    let usage: TokenUsage?
}
struct MediaInput: Codable { let mime: String; let data: String }
struct AnalysisInput: Codable { let url: String; let text: String; let media: MediaInput?; let analyzeMedia: Bool }
struct ServerConfig: Codable { let gemini: Bool; let search: Bool; let mapJSKey: String; let accessCodeRequired: Bool }
struct SearchResult: Codable { let places: [Place] }
struct APIErrorBody: Codable { let error: String }
struct APIError: LocalizedError { let message: String; let status: Int; var errorDescription: String? { message } }
struct UserError: LocalizedError { let message: String; var errorDescription: String? { message } }

enum API {
    static let base = URL(string: "https://reelmap-dohyeok-1030.dodo73231.chatgpt.site")!
    static func post<Input: Encodable, Output: Decodable>(_ path: String, input: Input, code: String) async throws -> Output {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(code, forHTTPHeaderField: "X-Demo-Code")
        request.httpBody = try JSONEncoder().encode(input)
        request.timeoutInterval = 150
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error ?? "서버에 연결하지 못했습니다. 연결 상태를 확인해 주세요.", status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(Output.self, from: data)
    }
}

// Public-page acquisition stays on the device; no Instagram login cookies are used.
enum InstagramCaption {
    static func postURL(_ raw: String) -> URL? {
        guard var c = URLComponents(string: raw), c.scheme == "https",
              ["instagram.com", "www.instagram.com"].contains(c.host ?? ""),
              c.user == nil, c.password == nil, c.port == nil,
              c.path.range(of: #"^/(?:[\w.]+/)?(?:reel|p|tv)/[A-Za-z0-9_-]{5,40}/?$"#, options: .regularExpression) != nil else { return nil }
        c.query = nil; c.fragment = nil
        return c.url
    }
    static func postKey(_ raw: String) -> String? {
        guard let url = postURL(raw) else { return nil }
        return url.path.split(separator: "/").last.map(String.init)
    }
    static func decode(_ value: String) -> String {
        let pattern = #"&(?:amp|quot|apos|lt|gt|#x[0-9a-fA-F]+|#[0-9]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        var result = value
        for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let entity = String(result[range])
            let named = ["&amp;":"&", "&quot;":"\"", "&apos;":"'", "&lt;":"<", "&gt;":">"]
            var replacement = named[entity]
            if replacement == nil {
                let hex = entity.hasPrefix("&#x")
                let digits = entity.dropFirst(hex ? 3 : 2).dropLast()
                if let n = UInt32(digits, radix: hex ? 16 : 10), let scalar = UnicodeScalar(n) { replacement = String(scalar) }
            }
            if let replacement { result.replaceSubrange(range, with: replacement) }
        }
        return result
    }
    static func parse(_ html: String) -> String? {
        guard let tags = try? NSRegularExpression(pattern: #"<meta\b[^>]*>"#, options: .caseInsensitive),
              let attrs = try? NSRegularExpression(pattern: #"([\w:-]+)\s*=\s*(["'])([\s\S]*?)\2"#) else { return nil }
        var metadata: [String:String] = [:]
        for match in tags.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range]); var values: [String:String] = [:]
            for attr in attrs.matches(in: tag, range: NSRange(tag.startIndex..., in: tag)) {
                guard let key = Range(attr.range(at: 1), in: tag), let value = Range(attr.range(at: 3), in: tag) else { continue }
                values[String(tag[key]).lowercased()] = decode(String(tag[value]))
            }
            if let key = values["property"] ?? values["name"] { metadata[key] = values["content"] ?? "" }
        }
        if (metadata["og:title"] ?? "").range(of: #"Login|로그인"#, options: .regularExpression) != nil { return nil }
        let caption = metadata["og:description"] ?? metadata["description"] ?? ""
        return caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : String(caption.prefix(20000))
    }
    static func read(_ raw: String) async throws -> String {
        guard let url = postURL(raw) else { throw UserError(message: "공개 인스타 게시물 링크를 확인해 주세요.") }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 7
        configuration.timeoutIntervalForResource = 8
        let session = URLSession(configuration: configuration, delegate: PostRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("ko-KR,ko;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, response.expectedContentLength <= 2 * 1024 * 1024 else { throw UserError(message: "기기에서 공개 본문을 읽지 못했습니다.") }
        var data = Data(); data.reserveCapacity(64 * 1024)
        for try await byte in bytes {
            guard data.count < 2 * 1024 * 1024 else { throw UserError(message: "게시물 응답 크기를 초과했습니다.") }
            data.append(byte)
        }
        guard let caption = parse(String(decoding: data, as: UTF8.self)) else { throw UserError(message: "공개 본문이 없거나 로그인 접근이 필요합니다.") }
        return caption
    }
    private final class PostRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            let first = task.originalRequest?.url?.absoluteString ?? ""
            let next = request.url?.absoluteString ?? ""
            completionHandler(postKey(first) != nil && postKey(first) == postKey(next) ? request : nil)
        }
    }
}
