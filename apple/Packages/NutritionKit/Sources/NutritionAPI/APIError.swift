// API error taxonomy. 401 → purge the cookie token and route to re-login (there
// is no refresh; the signed token lives 24h). Most proxy error bodies are
// `{ "error": "..." }`.

import Foundation

public enum APIError: Error, Sendable, Equatable, LocalizedError {
    case unauthorized                              // 401 — token invalid/expired
    case forbidden(message: String?)               // 403
    case conflict                                  // 409 — server doesn't know this device (re-enroll)
    case notFound                                  // 404
    case rateLimited(retryAfter: TimeInterval?)    // 429
    case badRequest(message: String?)              // 400 / app-level failure
    case server(status: Int, message: String?)     // 5xx and other unexpected
    case transport(String)                         // URLError / connectivity
    case decoding(String)                          // response body didn't match the DTO
    case invalidResponse                           // non-HTTP response / missing token cookie

    public var errorDescription: String? {
        switch self {
        case .unauthorized:        return "Your session expired. Please try again."
        case .forbidden(let m):    return m ?? "Access denied."
        case .conflict:            return "Device needs to re-register."
        case .notFound:            return "Not found."
        case .rateLimited(let r):
            if let r { return "Rate limited. Try again in \(Int(r))s." }
            return "Too many requests. Please wait."
        case .badRequest(let m):   return m ?? "Bad request."
        case .server(let s, let m): return m ?? "Server error (\(s))."
        case .transport(let m):    return "Network error: \(m)"
        case .decoding(let m):     return "Unexpected response: \(m)"
        case .invalidResponse:     return "Invalid server response."
        }
    }

    /// Map an HTTP status + body + headers to a typed error (nil for 2xx).
    static func from(status: Int, data: Data, headers: [AnyHashable: Any]) -> APIError? {
        guard !(200..<300).contains(status) else { return nil }
        let message = Self.errorMessage(from: data)
        switch status {
        case 401: return .unauthorized
        case 403: return .forbidden(message: message)
        case 409: return .conflict
        case 404: return .notFound
        case 429: return .rateLimited(retryAfter: Self.retryAfter(from: headers))
        case 400: return .badRequest(message: message)
        default:  return .server(status: status, message: message)
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        struct ErrorBody: Decodable { let error: String? }
        return (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
    }

    /// Numeric `Retry-After` (delta-seconds), falling back to `X-RateLimit-Reset`
    /// (epoch seconds).
    private static func retryAfter(from headers: [AnyHashable: Any]) -> TimeInterval? {
        func header(_ name: String) -> String? {
            for (k, v) in headers where (k as? String)?.caseInsensitiveCompare(name) == .orderedSame {
                return v as? String
            }
            return nil
        }
        if let ra = header("Retry-After"), let secs = TimeInterval(ra.trimmingCharacters(in: .whitespaces)) {
            return max(0, secs)
        }
        if let reset = header("X-RateLimit-Reset"), let epoch = TimeInterval(reset) {
            return max(0, epoch - Date().timeIntervalSince1970)
        }
        return nil
    }
}
