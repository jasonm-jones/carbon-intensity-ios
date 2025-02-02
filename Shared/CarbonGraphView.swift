import SwiftUI

struct CarbonGraphView: View {
    let data: [HistoricalDataPoint]
    
    // MARK: - Cached Properties
    private let average: Int
    private let maxDeviation: Int
    private let percentileMap: [Int: Int]  // Cache intensity -> percentile mapping
    
    // MARK: - Constants
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Initialization
    init(data: [HistoricalDataPoint]) {
        // Store data (already in chronological order from API)
        self.data = data
        
        // Calculate average
        let sum = data.reduce(0) { $0 + $1.intensity }
        self.average = sum / max(1, data.count)
        
        // Calculate max deviation
        let maxValue = data.map(\.intensity).max() ?? average
        let minValue = data.map(\.intensity).min() ?? average
        self.maxDeviation = max(abs(maxValue - average), abs(average - minValue))
        
        // Pre-calculate all percentiles
        let sortedIntensities = data.map(\.intensity).sorted()
        let total = Double(sortedIntensities.count)
        var percentiles: [Int: Int] = [:]
        
        for intensity in Set(sortedIntensities) {
            let position = sortedIntensities.filter { $0 <= intensity }.count
            percentiles[intensity] = Int((Double(position) / total) * 100)
        }
        self.percentileMap = percentiles
    }
    
    private func colorForBar(_ point: HistoricalDataPoint) -> Color {
        // Use cached percentile
        let percentile = percentileMap[point.intensity] ?? 50
        return Configuration.colorForPercentile(100 - percentile)
    }
    
    // MARK: - View Body
    var body: some View {
        GeometryReader { geometry in
            let layout = GraphLayout(geometry: geometry, dataCount: data.count)
            
            ZStack {
                // Grid lines and labels
                GridLinesView(average: average, maxDeviation: maxDeviation, layout: layout)
                
                // Average line
                AverageLineView(layout: layout)
                
                // Bars
                BarsView(
                    data: data,
                    average: average,
                    maxDeviation: maxDeviation,
                    layout: layout,
                    colorForBar: colorForBar
                )
                
                // Time labels
                TimeLabelsView(
                    newestDate: data.last?.localDate ?? Date(),
                    layout: layout,
                    dateFormatter: dateFormatter
                )
                
                // "Now" indicator
                if data.last != nil {
                    NowIndicatorView(layout: layout)
                }
            }
        }
    }
}

// MARK: - Supporting Types
private struct GraphLayout {
    let marginLeft: CGFloat = 30
    let marginRight: CGFloat = 15
    let marginTop: CGFloat = 10
    let marginBottom: CGFloat = 20
    
    let width: CGFloat
    let height: CGFloat
    let graphWidth: CGFloat
    let graphHeight: CGFloat
    let barWidth: CGFloat
    let barSpacing: CGFloat
    
    init(geometry: GeometryProxy, dataCount: Int) {
        width = geometry.size.width
        height = geometry.size.height
        graphWidth = width - marginLeft - marginRight
        graphHeight = height - marginTop - marginBottom
        barWidth = (graphWidth / CGFloat(dataCount)) * 0.8
        barSpacing = (graphWidth / CGFloat(dataCount)) * 0.2
    }
}

// MARK: - Subviews
// (Create separate view structs for GridLinesView, AverageLineView, BarsView, 
// TimeLabelsView, and NowIndicatorView to further break down the complexity)

private struct GridLinesView: View {
    let average: Int
    let maxDeviation: Int
    let layout: GraphLayout
    
    var body: some View {
        let yScale = (layout.graphHeight / 2) / CGFloat(maxDeviation)
        
        ForEach(-2...2, id: \.self) { i in
            let value = average + (maxDeviation * i / 2)
            let y = layout.marginTop + layout.graphHeight/2 - CGFloat(value - average) * yScale
            
            // Grid line
            Path { path in
                path.move(to: CGPoint(x: layout.marginLeft, y: y))
                path.addLine(to: CGPoint(x: layout.width - layout.marginRight, y: y))
            }
            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            
            // Y-axis label
            Text("\(value)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .position(x: layout.marginLeft - 15, y: y)
        }
    }
}

private struct AverageLineView: View {
    let layout: GraphLayout
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.8))
            .frame(width: layout.graphWidth, height: 1)
            .position(
                x: layout.marginLeft + layout.graphWidth/2,
                y: layout.marginTop + layout.graphHeight/2
            )
    }
}

private struct BarsView: View {
    let data: [HistoricalDataPoint]
    let average: Int
    let maxDeviation: Int
    let layout: GraphLayout
    let colorForBar: (HistoricalDataPoint) -> Color
    
    var body: some View {
        let yScale = (layout.graphHeight / 2) / CGFloat(maxDeviation)
        
        ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
            // Calculate x position from left to right
            let x = layout.marginLeft + CGFloat(index) * (layout.barWidth + layout.barSpacing)
            let value = point.intensity
            
            let barHeight = CGFloat(abs(value - average)) * yScale
            let y = value > average
                ? layout.marginTop + layout.graphHeight/2 - barHeight
                : layout.marginTop + layout.graphHeight/2
            
            Rectangle()
                .fill(colorForBar(point))
                .frame(width: layout.barWidth, height: barHeight)
                .position(x: x + layout.barWidth/2, y: y + barHeight/2)
        }
    }
}

private struct TimeLabelsView: View {
    let newestDate: Date
    let layout: GraphLayout
    let dateFormatter: DateFormatter
    
    var body: some View {
        ForEach(0..<5) { i in
            let x = layout.marginLeft + CGFloat(i) * layout.graphWidth / 4
            
            // Calculate time for each label, starting from the current time
            // and going back in 6-hour increments
            let hoursAgo = 24 - (i * 6)  // 24, 18, 12, 6, 0 hours ago
            let labelDate = Calendar.current.date(
                byAdding: .hour,
                value: -hoursAgo,
                to: Date()
            ) ?? Date()
            
            Text(dateFormatter.string(from: labelDate))
                .font(.caption)
                .foregroundColor(.secondary)
                .position(x: x, y: layout.height - 5)
        }
    }
}

private struct NowIndicatorView: View {
    let layout: GraphLayout
    
    var body: some View {
        let x = layout.width - layout.marginRight - layout.barWidth
        
        ZStack {
            // Vertical line
            Rectangle()
                .fill(Color.primary)
                .frame(width: 2)
                .frame(height: layout.graphHeight)
                .position(x: x + layout.barWidth/2, y: layout.marginTop + layout.graphHeight/2)
                .opacity(0.3)
            
            // "Now" label
            Text("Now")
                .font(.caption.bold())
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(radius: 1)
                )
                .position(x: x + layout.barWidth/2, y: layout.marginTop + 30)
        }
    }
}

struct DashStyle: ViewModifier {
    let dash: CGFloat
    
    func body(content: Content) -> some View {
        content
            .mask(
                StripesPattern(dash: dash)
            )
    }
}

struct StripesPattern: Shape {
    let dash: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for y in stride(from: 0, to: rect.height, by: dash * 2) {
            path.addRect(CGRect(x: 0, y: y, width: rect.width, height: dash))
        }
        return path
    }
}

extension View {
    func dashStyle(dash: CGFloat) -> some View {
        modifier(DashStyle(dash: dash))
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    
    let previewData = (0...23).map { hoursAgo in
        let date = calendar.date(byAdding: .hour, value: -hoursAgo, to: now)!
        return HistoricalDataPoint(
            datetime: ISO8601DateFormatter().string(from: date),
            carbonIntensity: 400 + Int.random(in: -100...100),
            zone: "test",
            updatedAt: "",
            isEstimated: false
        )
    }
    
    CarbonGraphView(data: previewData)
        .frame(height: 200)
        .padding()
} 