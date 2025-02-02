import WidgetKit
import SwiftUI

// MARK: - Widget Provider
struct Provider: TimelineProvider {
    typealias Entry = CarbonEntry
    private let dataProvider = DataProvider()
    
    func placeholder(in context: Context) -> CarbonEntry {
        CarbonEntry(
            date: Date(),
            intensity: 245,
            percentile: 23,
            emoji: "😑",
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            zone: Configuration.defaultZone,
            historicalData: nil,
            powerSources: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CarbonEntry) -> ()) {
        Task {
            do {
                let entry = try await dataProvider.fetchLatestData()
                completion(entry)
            } catch {
                let placeholder = CarbonEntry(
                    date: Date(),
                    intensity: 245,
                    percentile: 23,
                    emoji: "❓",
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                    zone: Configuration.defaultZone,
                    historicalData: nil,
                    powerSources: nil
                )
                completion(placeholder)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarbonEntry>) -> ()) {
        Task {
            do {
                let entry = try await dataProvider.fetchLatestData()
                let nextUpdate = Date().addingTimeInterval(Configuration.refreshInterval)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            } catch {
                let placeholder = CarbonEntry(
                    date: Date(),
                    intensity: 245,
                    percentile: 23,
                    emoji: "❓",
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                    zone: Configuration.defaultZone,
                    historicalData: nil,
                    powerSources: nil
                )
                let timeline = Timeline(entries: [placeholder], policy: .after(Date().addingTimeInterval(300)))
                completion(timeline)
            }
        }
    }
}

// MARK: - Widget Bundle
//@main
struct GridCarbonWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarbonIntensityWidget()
    }
}

// MARK: - Individual Widgets
struct CarbonIntensityWidget: Widget {
    let kind: String = "CarbonIntensityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GridCarbonWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Grid Carbon Intensity")
        .description("Shows real-time carbon intensity of your electrical grid.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
