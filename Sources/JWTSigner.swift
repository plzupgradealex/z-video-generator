import Foundation
import CryptoKit

/// Builds the HS256 JWT that Z.AI uses for bearer auth.
///
/// Mirrors `zai/core/_jwt_token.py`: the API key is `id.secret`; the secret half
/// signs a payload `{api_key, exp, timestamp}` (milliseconds) with a header
/// `{"alg":"HS256","sign_type":"SIGN"}`. The server verifies the HMAC over the
/// exact base64url bytes in the token, so header/payload key ordering is irrelevant.
enum JWTSigner {
    enum Error: Swift.Error {
        case invalidAPIKey
    }

    static func token(for apiKey: String) throws -> String {
        let parts = apiKey.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw Error.invalidAPIKey }
        let apiKeyID = String(parts[0])
        let secret = Data(parts[1].utf8)

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let expMs = nowMs + (3 * 60 + 30) * 1000 // 3 min cache + 30 s buffer, like the SDK

        let header = #"{"alg":"HS256","sign_type":"SIGN"}"#
        let payload = #"{"api_key":"\#(apiKeyID)","exp":\#(expMs),"timestamp":\#(nowMs)}"#

        let headerB64 = base64URLEncode(Data(header.utf8))
        let payloadB64 = base64URLEncode(Data(payload.utf8))
        let signingInput = "\(headerB64).\(payloadB64)"

        let key = SymmetricKey(data: secret)
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let signature = base64URLEncode(Data(mac))

        return "\(signingInput).\(signature)"
    }

    /// base64 URL encoding without padding (JWT requirement).
    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
