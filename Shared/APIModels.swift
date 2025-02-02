import Foundation

// MARK: - API Error Types
enum APIError: LocalizedError {
    case invalidResponse
    case invalidData
    case networkError
    case badRequest(String)
    case unauthorized
    case notFound
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Could not parse server response"
        case .networkError:
            return "Network connection error"
        case .badRequest(let message):
            return "Invalid request: \(message)"
        case .unauthorized:
            return "Invalid API key or unauthorized access"
        case .notFound:
            return "Zone not found"
        case .serverError:
            return "Server error, please try again later"
        }
    }
}

// MARK: - API Response Models
struct ErrorResponse: Codable {
    let message: String
}

struct HistoricalResponse: Codable {
    let zone: String
    let history: [HistoricalDataPoint]
}

struct PowerBreakdownResponse: Codable {
    let zone: String
    let powerProductionBreakdown: [String: Double?]
    let updatedAt: String
    let datetime: String
    let renewablePercentage: Double
    
    private enum CodingKeys: String, CodingKey {
        case zone
        case powerProductionBreakdown
        case updatedAt
        case datetime
        case renewablePercentage
    }
} 