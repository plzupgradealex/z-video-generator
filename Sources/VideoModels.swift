import Foundation

/// Request body for `POST /videos/generations`.
/// Optional fields are omitted from JSON when nil (JSONEncoder default),
/// matching the Flask app's "only send supported params" behaviour.
struct GenerationRequest: Encodable, Sendable {
    var model: String
    var prompt: String?
    var image_url: String?
    var quality: String?
    var with_audio: Bool?
    var size: String?
    var duration: Int?
    var fps: Int?
    var style: String?
    var aspect_ratio: String?
    var movement_amplitude: String?
}

struct VideoResult: Decodable, Sendable {
    var url: String?
    var cover_image_url: String?
}

/// Response from both the generation and the async-result endpoints.
struct VideoObject: Decodable, Sendable {
    var id: String?
    var model: String?
    var task_status: String?
    var video_result: [VideoResult]?
    var request_id: String?
}

/// A saved generation shown in History.
struct HistoryItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var prompt: String
    var videoURL: String
    var coverURL: String?
    var model: String
    var date: Date
}
