import XCTest
@testable import Grid_Carbon_Intensity

final class TrendCalculationTests: XCTestCase {
    // Helper function to create test data points
    private func createDataPoints(_ intensities: [Int]) -> [HistoricalDataPoint] {
        return intensities.enumerated().map { index, intensity in
            let date = Date().addingTimeInterval(-Double(index) * 3600)
            let dateString = ISO8601DateFormatter().string(from: date)
            return HistoricalDataPoint(
                datetime: dateString,
                carbonIntensity: intensity,
                zone: "test",
                updatedAt: dateString,
                isEstimated: false
            )
        }
    }
    
    func testIncreasingTrend() {
        // Test clearly dirtier (>5% increase)
        let dirtierData = createDataPoints([525, 500]) // 5% increase
        XCTAssertEqual(
            MainContentView.calculateTrend(from: dirtierData),
            .increasing,
            "Should detect increasing trend when last value is >5% higher"
        )
        
        // Test significantly dirtier
        let veryDirtierData = createDataPoints([600, 500]) // 20% increase
        XCTAssertEqual(
            MainContentView.calculateTrend(from: veryDirtierData),
            .increasing,
            "Should detect increasing trend when last value is much higher"
        )
    }
    
    func testDecreasingTrend() {
        // Test clearly cleaner (>5% decrease)
        let cleanerData = createDataPoints([475, 500]) // 5% decrease
        XCTAssertEqual(
            MainContentView.calculateTrend(from: cleanerData),
            .decreasing,
            "Should detect decreasing trend when last value is >5% lower"
        )
        
        // Test significantly cleaner
        let veryCleanerData = createDataPoints([400, 500]) // 20% decrease
        XCTAssertEqual(
            MainContentView.calculateTrend(from: veryCleanerData),
            .decreasing,
            "Should detect decreasing trend when last value is much lower"
        )
    }
    
    func testStableTrend() {
        // Test exactly stable
        let stableData = createDataPoints([500, 500]) // 0% change
        XCTAssertEqual(
            MainContentView.calculateTrend(from: stableData),
            .stable,
            "Should detect stable trend when values are equal"
        )
        
        // Test within 5% threshold higher
        let slightlyHigher = createDataPoints([524, 500]) // 4.8% increase
        XCTAssertEqual(
            MainContentView.calculateTrend(from: slightlyHigher),
            .stable,
            "Should detect stable trend when increase is less than 5%"
        )
        
        // Test within 5% threshold lower
        let slightlyLower = createDataPoints([476, 500]) // 4.8% decrease
        XCTAssertEqual(
            MainContentView.calculateTrend(from: slightlyLower),
            .stable,
            "Should detect stable trend when decrease is less than 5%"
        )
    }
    
    func testEdgeCases() {
        // Test empty data
        XCTAssertEqual(
            MainContentView.calculateTrend(from: []),
            .stable,
            "Should return stable for empty data"
        )
        
        // Test single data point
        let singlePoint = createDataPoints([500])
        XCTAssertEqual(
            MainContentView.calculateTrend(from: singlePoint),
            .stable,
            "Should return stable for single data point"
        )
        
        // Test with more than two points (should only compare last two)
        let multiplePoints = createDataPoints([600, 500, 400, 300]) // Only 600 vs 500 matters
        XCTAssertEqual(
            MainContentView.calculateTrend(from: multiplePoints),
            .increasing,
            "Should only compare last two points regardless of history"
        )
    }
} 