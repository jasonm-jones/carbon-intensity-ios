import Foundation

class ElectricityMapsAPI {
    static let shared = ElectricityMapsAPI()
    private let baseURL = "https://api.electricitymap.org/v3"
    
    private var headers: [String: String] {
        ["auth-token": Configuration.apiKey]
    }
    
    // MARK: - API Methods
    func fetchCurrentIntensity(for zone: String = Configuration.defaultZone) async throws -> CarbonIntensityResponse {
        let url = URL(string: "\(baseURL)/carbon-intensity/latest?zone=\(zone)")!
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        
        DebugLogger.log("Sending request", type: .network, 
            details: """
            Full URL: \(url.absoluteString)
            Method: GET
            Zone: \(zone)
            """)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DebugLogger.log("Invalid response type", type: .error)
            throw APIError.invalidResponse
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "No body"
        DebugLogger.log("Received response", type: .network,
            details: """
            Status: \(httpResponse.statusCode)
            Headers: \(httpResponse.allHeaderFields)
            Body: \(responseBody)
            """)
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                let intensity = try decoder.decode(CarbonIntensityResponse.self, from: data)
                DebugLogger.log("Successfully fetched current intensity", details: """
                    Intensity: \(intensity.carbonIntensity) gCO₂/kWh
                    Zone: \(intensity.zone)
                    Updated: \(intensity.datetime)
                    """)
                return intensity
            } catch {
                DebugLogger.log("Failed to decode response", type: .error, 
                    details: "Error: \(error)\nJSON: \(responseBody)")
                throw APIError.invalidData
            }
        case 400:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                DebugLogger.log("Bad request", type: .error, details: errorResponse.message)
                throw APIError.badRequest(errorResponse.message)
            }
            throw APIError.badRequest("Invalid request")
        case 401:
            DebugLogger.log("Unauthorized", type: .error, details: "Check your API key")
            throw APIError.unauthorized
        case 404:
            DebugLogger.log("Not found", type: .error, details: "Zone \(zone) not found")
            throw APIError.notFound
        default:
            DebugLogger.log("Server error", type: .error, 
                details: "Status: \(httpResponse.statusCode)\nBody: \(responseBody)")
            throw APIError.serverError
        }
    }
    
    func fetchHistoricalData(for zone: String = Configuration.defaultZone) async throws -> [HistoricalDataPoint] {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-Configuration.historicalDataHours)
        
        // Use UTC for API requests
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let start = dateFormatter.string(from: startTime)
        let end = dateFormatter.string(from: endTime)
        
        let url = URL(string: "\(baseURL)/carbon-intensity/history?zone=\(zone)&start=\(start)&end=\(end)")!
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        
        DebugLogger.log("Sending historical data request", type: .network, 
            details: """
            Full URL: \(url.absoluteString)
            Method: GET
            Zone: \(zone)
            Start: \(start)
            End: \(end)
            """)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DebugLogger.log("Invalid response type", type: .error)
            throw APIError.invalidResponse
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "No body"
        DebugLogger.log("Received historical data response", type: .network,
            details: """
            Status: \(httpResponse.statusCode)
            Headers: \(httpResponse.allHeaderFields)
            Body: \(responseBody)
            """)
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                let historyResponse = try decoder.decode(HistoricalResponse.self, from: data)
                DebugLogger.log("Successfully fetched historical data", details: """
                    Points: \(historyResponse.history.count)
                    Time range: \(start) to \(end)
                    Zone: \(historyResponse.zone)
                    """)
                
                // Data from the API is already in chronological order (oldest to newest)
                // but let's document and verify this
                let historicalData = historyResponse.history
                
                #if DEBUG
                // Verify chronological ordering
                let formatter = DateFormatter()
                formatter.dateFormat = "ha"
                formatter.amSymbol = "AM"
                formatter.pmSymbol = "PM"
                
                let dataLog = historicalData.map { point in
                    "[\(formatter.string(from: point.localDate)), \(point.intensity)]"
                }.joined(separator: ", ")
                
                DebugLogger.log("Historical Data (Time, Intensity)", type: .info, details: dataLog)
                #endif
                
                return historicalData
            } catch {
                DebugLogger.log("Failed to decode response", type: .error, 
                    details: "Error: \(error)\nJSON: \(responseBody)")
                throw APIError.invalidData
            }
        case 400:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                DebugLogger.log("Bad request", type: .error, details: errorResponse.message)
                throw APIError.badRequest(errorResponse.message)
            }
            throw APIError.badRequest("Invalid request")
        case 401:
            DebugLogger.log("Unauthorized", type: .error, details: "Check your API key")
            throw APIError.unauthorized
        case 404:
            DebugLogger.log("Not found", type: .error, details: "Zone \(zone) not found")
            throw APIError.notFound
        default:
            DebugLogger.log("Server error", type: .error, 
                details: "Status: \(httpResponse.statusCode)\nBody: \(responseBody)")
            throw APIError.serverError
        }
    }
    
    func fetchPowerBreakdown(for zone: String = Configuration.defaultZone) async throws -> [PowerSource] {
        let url = URL(string: "\(baseURL)/power-breakdown/latest?zone=\(zone)")!
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        
        DebugLogger.log("Sending power breakdown request", type: .network, 
            details: """
            Full URL: \(url.absoluteString)
            Method: GET
            Zone: \(zone)
            """)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DebugLogger.log("Invalid response type", type: .error)
            throw APIError.invalidResponse
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "No body"
        DebugLogger.log("Received power breakdown response", type: .network,
            details: """
            Status: \(httpResponse.statusCode)
            Headers: \(httpResponse.allHeaderFields)
            Body: \(responseBody)
            """)
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                let breakdownResponse = try decoder.decode(PowerBreakdownResponse.self, from: data)
                // Filter out null values and convert to PowerSource array
                return breakdownResponse.powerProductionBreakdown.compactMap { source in
                    guard let value = source.value else { return nil }
                    return PowerSource(
                        id: source.key,
                        percentage: value / 100.0, // Convert to percentage
                        emoji: PowerSource.emojiMap[source.key] ?? "❓"
                    )
                }.filter { $0.percentage > 0 } // Only include sources with non-zero values
            } catch {
                DebugLogger.log("Failed to decode power breakdown", type: .error, 
                    details: """
                    Error: \(error)
                    JSON: \(responseBody)
                    """)
                throw APIError.invalidData
            }
        case 400:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                DebugLogger.log("Bad request", type: .error, details: errorResponse.message)
                throw APIError.badRequest(errorResponse.message)
            }
            throw APIError.badRequest("Invalid request")
        case 401:
            DebugLogger.log("Unauthorized", type: .error, details: "Check your API key")
            throw APIError.unauthorized
        case 404:
            DebugLogger.log("Not found", type: .error, details: "Zone \(zone) not found")
            throw APIError.notFound
        default:
            DebugLogger.log("Server error", type: .error, 
                details: "Status: \(httpResponse.statusCode)\nBody: \(responseBody)")
            throw APIError.serverError
        }
    }
} 