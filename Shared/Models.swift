import Foundation
import WidgetKit

// MARK: - Widget Models
struct CarbonEntry: TimelineEntry {
    let date: Date
    let intensity: Int
    let percentile: Int
    let emoji: String
    let updatedAt: String
    let zone: String
    var historicalData: [HistoricalDataPoint]?
    var powerSources: [PowerSource]?
}

// MARK: - Data Models
struct HistoricalDataPoint: Codable, Identifiable {
    // MARK: - Static Properties
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // MARK: - Properties
    let datetime: String
    let carbonIntensity: Int
    let zone: String
    let updatedAt: String
    let isEstimated: Bool
    let _localDate: Date
    
    var id: String { datetime }
    var intensity: Int { carbonIntensity }
    var localDate: Date { _localDate }
    
    var date: Date {
        if let date = Self.iso8601Formatter.date(from: datetime) {
            return date
        }
        return Self.fallbackFormatter.date(from: datetime) ?? Date()
    }
    
    init(datetime: String, carbonIntensity: Int, zone: String, updatedAt: String, isEstimated: Bool) {
        self.datetime = datetime
        self.carbonIntensity = carbonIntensity
        self.zone = zone
        self.updatedAt = updatedAt
        self.isEstimated = isEstimated
        
        // Calculate local date during initialization using static formatters
        if let date = Self.iso8601Formatter.date(from: datetime) {
            self._localDate = date.convertToLocal()
        } else if let date = Self.fallbackFormatter.date(from: datetime) {
            self._localDate = date.convertToLocal()
        } else {
            self._localDate = Date().convertToLocal()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // First decode all the basic properties
        datetime = try container.decode(String.self, forKey: .datetime)
        carbonIntensity = try container.decode(Int.self, forKey: .carbonIntensity)
        zone = try container.decode(String.self, forKey: .zone)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        isEstimated = try container.decode(Bool.self, forKey: .isEstimated)
        
        // Then initialize _localDate using the decoded datetime
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var utcDate = formatter.date(from: datetime)
        if utcDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            utcDate = formatter.date(from: datetime)
        }
        _localDate = (utcDate ?? Date()).convertToLocal()
    }
    
    private enum CodingKeys: String, CodingKey {
        case datetime
        case carbonIntensity
        case zone
        case updatedAt
        case isEstimated
    }
}

// Add Date extension for timezone conversion
extension Date {
    func convertToLocal() -> Date {
        let timezone = TimeZone.current
        let seconds = timezone.secondsFromGMT(for: self)
        return addingTimeInterval(TimeInterval(seconds))
    }
}

struct PowerSource: Codable, Identifiable, Hashable {
    let id: String
    let percentage: Double
    let emoji: String
    
    static let emojiMap: [String: String] = [
        "wind": "💨",
        "solar": "☀️",
        "hydro": "💧",
        "biomass": "🌱",
        "geothermal": "🌋",
        "nuclear": "⚛️",
        "coal": "🪨",
        "gas": "⛽",
        "oil": "🛢️",
        "unknown": "❓"
    ]
}

struct CarbonIntensityResponse: Codable {
    // MARK: - Static Properties
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // MARK: - Properties
    let carbonIntensity: Int
    let datetime: String
    let zone: String
    private var _percentile: Int?
    let _localDate: Date
    
    var intensity: Int { carbonIntensity }
    var updatedAt: String { datetime }
    var localDate: Date { _localDate }
    
    var percentile: Int {
        get { _percentile ?? 50 }
        set { _percentile = newValue }
    }
    
    mutating func calculatePercentile(historicalData: [HistoricalDataPoint]) {
        let sortedIntensities = historicalData.map { $0.intensity }.sorted()
        guard let index = sortedIntensities.firstIndex(where: { $0 >= carbonIntensity }) else {
            _percentile = 100
            return
        }
        _percentile = Int((Double(index) / Double(sortedIntensities.count)) * 100)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        carbonIntensity = try container.decode(Int.self, forKey: .carbonIntensity)
        datetime = try container.decode(String.self, forKey: .datetime)
        zone = try container.decode(String.self, forKey: .zone)
        
        // Use static formatters for thread safety
        if let date = Self.iso8601Formatter.date(from: datetime) {
            _localDate = date.convertToLocal()
        } else if let date = Self.fallbackFormatter.date(from: datetime) {
            _localDate = date.convertToLocal()
        } else {
            _localDate = Date().convertToLocal()
        }
    }
}

// MARK: - Data Provider
class DataProvider {
    func fetchLatestData() async throws -> CarbonEntry {
        let startTime = Date()
        
        // Make concurrent API requests
        async let intensity = ElectricityMapsAPI.shared.fetchCurrentIntensity()
        async let historical = ElectricityMapsAPI.shared.fetchHistoricalData()
        async let sources = ElectricityMapsAPI.shared.fetchPowerBreakdown()
        
        // Await all results together
        let awaitStart = Date()
        var intensityResult = try await intensity
        let historicalResult = try await historical
        let sourcesResult = try await sources
        let awaitTime = Date().timeIntervalSince(awaitStart)
        
        DebugLogger.log(
            "API Timing Details",
            type: .network,
            details: """
                Concurrent await time: \(String(format: "%.2f", awaitTime))s
                Historical points: \(historicalResult.count)
                Power sources: \(sourcesResult.count)
                """
        )
        
        // Calculate percentile
        let percentileStart = Date()
        intensityResult.calculatePercentile(historicalData: historicalResult)
        let percentileTime = Date().timeIntervalSince(percentileStart)
        
        let totalTime = Date().timeIntervalSince(startTime)
        DebugLogger.log(
            "Data Processing Complete",
            type: .network,
            details: """
                Percentile calc time: \(String(format: "%.2f", percentileTime))s
                Total processing time: \(String(format: "%.2f", totalTime))s
                """
        )
        
        return CarbonEntry(
            date: Date(),
            intensity: intensityResult.intensity,
            percentile: intensityResult.percentile,
            emoji: Configuration.emojiForPercentile(100 - intensityResult.percentile),
            updatedAt: intensityResult.updatedAt,
            zone: intensityResult.zone,
            historicalData: historicalResult,
            powerSources: sourcesResult
        )
    }
} 