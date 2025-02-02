import SwiftUI

struct PowerSourcesView: View {
    let sources: [PowerSource]
    
    // Add carbon intensities for each source type
    private let sourceIntensities: [String: Int] = [
        "wind": 11,
        "nuclear": 12,
        "hydro": 24,
        "solar": 27,
        "gas": 524,
        "coal": 1097
    ]
    
    var significantSources: [PowerSource] {
        sources
            .filter { $0.percentage >= 1.0 } // Only show sources >= 1%
            .sorted { $0.percentage > $1.percentage }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Grid Sources")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(significantSources) { source in
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(source.emoji)
                            Text("\(Int(source.percentage))%")
                                .font(.subheadline.bold())
                        }
                        Text(source.id.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let intensity = sourceIntensities[source.id.lowercased()] {
                            Text("\(intensity) gCO₂/kWh")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
} 