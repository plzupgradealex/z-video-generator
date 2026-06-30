import Foundation

/// Async client for the Z.AI video API (`https://api.z.ai/api/paas/v4`).
/// No Python dependency — calls REST directly with a bearer JWT.
struct ZAIClient: Sendable {
    static let baseURL = URL(string: "https://api.z.ai/api/paas/v4")!

    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    private func authorizedRequest(method: String, path: String, body: Data? = nil) throws -> URLRequest {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(try JWTSigner.token(for: apiKey))", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        req.timeoutInterval = 60
        return req
    }

    /// Submit a generation; returns the task id + initial status.
    func generate(_ request: GenerationRequest) async throws -> VideoObject {
        let body = try JSONEncoder().encode(request)
        let req = try authorizedRequest(method: "POST", path: "videos/generations", body: body)
        return try await send(req)
    }

    /// Poll the result of a generation by task id.
    func retrieve(id: String) async throws -> VideoObject {
        let req = try authorizedRequest(method: "GET", path: "async-result/\(id)")
        return try await send(req)
    }

    /// Lightweight auth/reachability probe that drives the connection-status
    /// light. It never returns data — only a classification: any HTTP response
    /// that isn't an auth failure means Z.AI is up and the key is accepted; a
    /// 401/403 means the key is bad; a transport error means we can't reach the
    /// server. Read-only and side-effect free, so it's safe to run on launch,
    /// on key change, and whenever the app regains focus.
    func verify() async -> VerifyResult {
        do {
            var req = try authorizedRequest(method: "GET", path: "async-result/0")
            req.timeoutInterval = 12
            let (_, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { return .unreachable }
            if http.statusCode == 401 || http.statusCode == 403 { return .unauthorized }
            return .connected
        } catch {
            return .unreachable
        }
    }

    private func send(_ request: URLRequest) async throws -> VideoObject {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ZAIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ZAIError.http(status: http.statusCode, message: body)
        }
        do {
            return try JSONDecoder().decode(VideoObject.self, from: data)
        } catch {
            throw ZAIError.decoding(error)
        }
    }
}

/// Outcome of a `ZAIClient.verify()` probe — maps onto the connection-status
/// light in the sidebar footer.
enum VerifyResult: Sendable {
    case connected      // server reachable, key accepted
    case unauthorized   // 401/403 — key rejected
    case unreachable    // transport error — can't reach Z.AI
}

enum ZAIError: LocalizedError {
    case http(status: Int, message: String)
    case invalidResponse
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .http(let status, let message):
            return "Z.AI error \(status): \(ZVUtil.summarize(message))"
        case .invalidResponse:
            return "Invalid response from the server."
        case .decoding(let error):
            return "Could not parse the response: \(error.localizedDescription)"
        }
    }

    /// Recovery category for tailored failure UI. A 402 — or any body mentioning
    /// funds/balance/quota/credit — is out-of-credit; 401/403 is a rejected key;
    /// everything else is generic. Transport errors never reach here (they're
    /// thrown as `URLError` and classified by `AppModel.classify`).
    var failureKind: FailureKind {
        switch self {
        case .http(let status, let message):
            if status == 402 { return .outOfCredit }
            if status == 401 || status == 403 { return .unauthorized }
            let body = message.lowercased()
            let creditMarkers = ["insufficient", "balance", "quota", "credit", "funds"]
            if creditMarkers.contains(where: { body.contains($0) }) { return .outOfCredit }
            return .generic
        case .invalidResponse, .decoding:
            return .generic
        }
    }
}
