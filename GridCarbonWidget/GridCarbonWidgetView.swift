import SwiftUI
import WidgetKit
import Shared

struct GridCarbonWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @State private var showDebugView = false
    
    var body: some View {
        ZStack {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DebugButton(showDebugView: $showDebugView)
                }
            }
        }
    }
}

struct SmallWidgetView: View {
    let entry: CarbonEntry
    
    var body: some View {
        VStack(spacing: 4) {
            Text(entry.emoji)
                .font(.system(size: 40))
            
            Text("\(entry.intensity) gCO₂")
                .font(.headline)
                .foregroundColor(Configuration.colorForIntensity(entry.intensity))
            
            HStack(spacing: 2) {
                Text("\(entry.percentile)%")
                    .font(.subheadline)
                Text("cleaner")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let entry: CarbonEntry
    
    var body: some View {
        HStack {
            SmallWidgetView(entry: entry)
            
            if let historicalData = entry.historicalData {
                CarbonGraphView(data: historicalData)
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let entry: CarbonEntry
    
    var body: some View {
        VStack {
            MediumWidgetView(entry: entry)
            
            if let powerSources = entry.powerSources {
                PowerSourcesView(sources: powerSources)
            }
        }
        .padding()
    }
} 