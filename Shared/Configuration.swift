import Foundation
import SwiftUI
import Security

enum Configuration {
    static var apiKey: String {
        get { KeychainManager.getApiKey() ?? "" }
        set {
            if newValue.isEmpty {
                _ = KeychainManager.deleteApiKey()
            } else {
                _ = KeychainManager.saveApiKey(newValue)
            }
        }
    }
    
    static var hasApiKey: Bool {
        let key = KeychainManager.getApiKey() ?? ""
        return !key.isEmpty
    }
    
    // Get your API key from https://www.electricitymaps.com/
    static let defaultZone = "US-NW-PACE"
    
    static let refreshInterval: TimeInterval = 3600 // 1 hour
    static let historicalDataHours: TimeInterval = 24 * 3600 // 24 hours in seconds
    
    // Carbon intensity thresholds (gCO₂eq/kWh)
    static let intensityThresholds = [
        50,  // Very clean
        150, // Clean
        300, // Moderate
        450, // Dirty
        600  // Very dirty
    ]
    
    static func colorForIntensity(_ intensity: Int) -> Color {
        switch intensity {
        case ..<intensityThresholds[0]:
            return Color(red: 0/255, green: 153/255, blue: 0/255)     // Cleanest
        case ..<intensityThresholds[1]:
            return Color(red: 93/255, green: 181/255, blue: 41/255)   // Cleaner
        case ..<intensityThresholds[2]:
            return Color(red: 253/255, green: 173/255, blue: 58/255)  // Average
        case ..<intensityThresholds[3]:
            return Color(red: 247/255, green: 110/255, blue: 45/255)  // Dirtier
        default:
            return Color(red: 220/255, green: 20/255, blue: 9/255)    // Dirtiest
        }
    }
    
    // Percentile thresholds for recommendations
    static let percentileThresholds = [
        20,  // Cleanest 20%
        40,  // Cleaner than average
        60,  // Average
        80   // Dirtier than average
        // >= 80 is dirtiest 20%
    ]
    
    static func emojiForPercentile(_ percentile: Int) -> String {
        switch percentile {
        case ..<percentileThresholds[0]: return "🌿" // Cleanest 20%
        case ..<percentileThresholds[1]: return "🌱" // Cleaner than average
        case ..<percentileThresholds[2]: return "😑" // Average
        case ..<percentileThresholds[3]: return "😡" // Dirtier than average
        default: return "⛔" // Dirtiest 20%
        }
    }
    
    static func recommendationForPercentile(_ percentile: Int) -> String {
        switch percentile {
        case ..<percentileThresholds[0]:
            return "🌿 Excellent time to run high-energy tasks!"
        case ..<percentileThresholds[1]:
            return "🌱 Good time for high-energy tasks"
        case ..<percentileThresholds[2]:
            return "😑 OK to run normal tasks"
        case ..<percentileThresholds[3]:
            return "😡 Consider delaying high-energy tasks if possible"
        default:
            return "⛔ Avoid high-energy tasks - grid is very dirty"
        }
    }
    
    static func colorForPercentile(_ percentile: Int) -> Color {
        switch percentile {
        case 80...100: // Cleanest 20%
            return Color.green
        case 60..<80:  // Cleaner than average
            return Color.green.opacity(0.7)
        case 40..<60:  // Average
            return Color.orange
        case 20..<40:  // Dirtier than average
            return Color.red.opacity(0.7)
        default:       // Dirtiest 20%
            return Color.red
        }
    }
    
    static var zone: String {
        get { UserDefaults.standard.string(forKey: "zone") ?? "US-NW-PACE" }
        set { UserDefaults.standard.set(newValue, forKey: "zone") }
    }
} 