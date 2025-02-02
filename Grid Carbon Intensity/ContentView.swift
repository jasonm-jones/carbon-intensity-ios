//
//  ContentView.swift
//  Grid Carbon Intensity
//
//  Created by Jason Jones on 2/1/25.
//

import SwiftUI
import WidgetKit
import Shared

class ContentViewModel: ObservableObject {
    @Published var intensity: Int = 0
    @Published var percentile: Int = 0
    @Published var zone: String = ""
    @Published var updatedAt: String = ""
    @Published var historicalData: [HistoricalDataPoint]?
    @Published var powerSources: [PowerSource]?
    @Published var isLoading = false
    @Published var showingApiKeySetup = false
    
    @MainActor
    func loadData() async {
        guard !isLoading else { return }
        
        isLoading = true
        let startTime = Date()
        
        do {
            DebugLogger.log("API Request: Starting", type: .network)
            let entry = try await DataProvider().fetchLatestData()
            let fetchTime = Date().timeIntervalSince(startTime)
            DebugLogger.log("API Request: Completed", type: .network, details: "Fetch time: \(String(format: "%.2f", fetchTime))s")
            
            // Start measuring UI update time
            let updateStart = Date()
            
            // Batch UI updates
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.intensity = entry.intensity
                    self.percentile = entry.percentile
                    self.zone = entry.zone
                    self.updatedAt = entry.updatedAt
                    self.historicalData = entry.historicalData
                    self.powerSources = entry.powerSources
                }
            }
            
            let updateTime = Date().timeIntervalSince(updateStart)
            DebugLogger.log(
                "View Update: Completed",
                type: .network,
                details: """
                    Update time: \(String(format: "%.2f", updateTime))s
                    Total time: \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s
                    Data points: \(entry.historicalData?.count ?? 0)
                    Power sources: \(entry.powerSources?.count ?? 0)
                    """
            )
            
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            DebugLogger.log("API Error", type: .error, details: error.localizedDescription)
        }
        
        isLoading = false
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showingDebugView = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingOnboarding = false
    @State private var tapCount = 0
    @State private var lastTapTime = Date()
    @State private var debugEnabled = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    SkeletonView()
                } else if !Configuration.hasApiKey {
                    SetupRequiredView(showSetup: { viewModel.showingApiKeySetup = true })
                } else if viewModel.intensity == 0 {
                    EmptyStateView(retryAction: {
                        Task { await viewModel.loadData() }
                    })
                } else {
                    MainContentView(viewModel: viewModel)
                }
            }
            .animation(.easeOut(duration: 0.2), value: viewModel.isLoading)
            .navigationTitle("Grid Carbon")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingOnboarding = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { viewModel.showingApiKeySetup = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
                
                if debugEnabled {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            DispatchQueue.main.async {
                                showingDebugView = true
                            }
                        } label: {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDebugView) {
            DebugView()
        }
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(
                    width: UIScreen.main.bounds.width * 0.2,
                    height: UIScreen.main.bounds.height * 0.2
                )
                .onTapGesture {
                    let now = Date()
                    if now.timeIntervalSince(lastTapTime) > 1.0 {
                        tapCount = 0
                    }
                    
                    tapCount += 1
                    lastTapTime = now
                    
                    if tapCount >= 3 {
                        tapCount = 0
                        withAnimation(.easeInOut) {
                            DebugSettings.toggleDebugMode()
                            debugEnabled = DebugSettings.isEnabled
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            
            if debugEnabled {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .padding(8)
            }
        }
        .task {
            if !hasSeenOnboarding {
                showingOnboarding = true
                return
            }
            if !Configuration.hasApiKey {
                viewModel.showingApiKeySetup = true
            } else {
                await viewModel.loadData()
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                .onDisappear {
                    if hasSeenOnboarding && !Configuration.hasApiKey {
                        viewModel.showingApiKeySetup = true
                    }
                }
        }
        .sheet(isPresented: $viewModel.showingApiKeySetup) {
            ApiKeySetupView(isPresented: $viewModel.showingApiKeySetup)
        }
        .onChange(of: viewModel.showingApiKeySetup) { isShowing in
            if !isShowing && Configuration.hasApiKey {
                Task {
                    await viewModel.loadData()
                }
            }
        }
        .onChange(of: DebugSettings.isEnabled) { newValue in
            withAnimation(.easeInOut) {
                debugEnabled = newValue
            }
        }
        .onAppear {
            debugEnabled = false
        }
    }
}

// Move main content to its own view for clarity
struct MainContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Recommendation card (most frequently updated)
                RecommendationCard(
                    intensity: viewModel.intensity,
                    percentile: viewModel.percentile,
                    trend: Self.calculateTrend(from: viewModel.historicalData)
                )
                .padding(.horizontal)
                
                // Historical graph (expensive to render)
                if let historicalData = viewModel.historicalData {
                    HistoricalGraphView(data: historicalData)
                        .padding(.horizontal)
                        .id(historicalData.first?.datetime ?? "")  // Force redraw only when data changes
                }
                
                // Power sources grid (less frequently updated)
                if let sources = viewModel.powerSources {
                    PowerSourcesView(sources: sources)
                        .padding(.horizontal)
                        .id(sources.first?.id ?? "")  // Force redraw only when data changes
                }
                
                // Footer info (infrequently updated)
                FooterInfoView(
                    zone: viewModel.zone,
                    updatedAt: viewModel.updatedAt
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .animation(nil)  // Disable automatic animations
    }
    
    static func calculateTrend(from data: [HistoricalDataPoint]?) -> IntensityTrend {
        guard let data = data?.sorted(by: { $0.date > $1.date }),
              data.count >= 2 else {
            return .stable
        }
        
        // Compare last two points
        let current = Double(data[0].intensity)  // Most recent point
        let previous = Double(data[1].intensity) // Previous point
        
        // Calculate percentage change from previous to current
        let percentageChange = ((current - previous) / previous) * 100
        
        // Create formatters for debug output
        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "MM-dd HH:mm"
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "MM-dd HH:mm"
        localFormatter.timeZone = TimeZone.current
        
        // Enhanced debug logging with both UTC and local times
        print("""
            Trend calculation:
            All data points: \(data.map { point in
                let utcTime = utcFormatter.string(from: point.date)
                let localTime = localFormatter.string(from: point.date)
                return "[\(utcTime) UTC/\(localTime) Local: \(point.intensity)]"
            }.joined(separator: ", "))
            Current: \(current)
            Previous: \(previous)
            Change: \(String(format: "%.1f", percentageChange))%
            Trend: \(percentageChange >= 5 ? "Getting Dirtier" : percentageChange <= -5 ? "Getting Cleaner" : "Stable")
            """)
        
        // Use 5% threshold (inclusive)
        if percentageChange >= 5 {
            return .increasing
        } else if percentageChange <= -5 {
            return .decreasing
        }
        return .stable
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(), value: isAnimating)
            
            VStack(spacing: 8) {
                Text("Loading Grid Data")
                    .font(.headline)
                Text("Checking your local grid's carbon intensity...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .opacity(isAnimating ? 1 : 0.7)
            .animation(.easeInOut(duration: 1).repeatForever(), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct EmptyStateView: View {
    @State private var isAnimating = false
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.orange)
                .rotationEffect(.degrees(isAnimating ? 8 : -8))
                .animation(.easeInOut(duration: 1).repeatForever(), value: isAnimating)
            
            VStack(spacing: 8) {
                Text("Unable to Load Data")
                    .font(.headline)
                Text("There was a problem getting data from Electricity Maps.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

struct SetupRequiredView: View {
    @State private var isAnimating = false
    let showSetup: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
                .rotationEffect(.degrees(isAnimating ? 10 : -10))
                .animation(.easeInOut(duration: 1).repeatForever(), value: isAnimating)
            
            VStack(spacing: 8) {
                Text("Setup Required")
                    .font(.headline)
                Text("To monitor your local grid's carbon intensity, you'll need to set up your Electricity Maps API key.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: showSetup) {
                Text("Set Up Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// New Views
enum IntensityTrend: Equatable {
    case increasing, decreasing, stable
}

struct TrendSparkLine: View {
    let trend: IntensityTrend
    
    var body: some View {
        ZStack {
            // Axes
            Path { path in
                // Y axis
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 12))
                // X axis
                path.move(to: CGPoint(x: 0, y: 6))
                path.addLine(to: CGPoint(x: 24, y: 6))
            }
            .stroke(style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
            .opacity(0.3)
            
            // Trend line
            Path { path in
                switch trend {
                case .increasing:
                    path.move(to: CGPoint(x: 0, y: 8))
                    path.addLine(to: CGPoint(x: 8, y: 4))
                    path.addLine(to: CGPoint(x: 16, y: 8))
                    path.addLine(to: CGPoint(x: 24, y: 0))
                case .decreasing:
                    path.move(to: CGPoint(x: 0, y: 4))
                    path.addLine(to: CGPoint(x: 8, y: 8))
                    path.addLine(to: CGPoint(x: 16, y: 4))
                    path.addLine(to: CGPoint(x: 24, y: 12))
                case .stable:
                    path.move(to: CGPoint(x: 0, y: 6))
                    path.addLine(to: CGPoint(x: 8, y: 4))
                    path.addLine(to: CGPoint(x: 16, y: 8))
                    path.addLine(to: CGPoint(x: 24, y: 6))
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 12)
    }
}

struct RecommendationCard: View {
    let intensity: Int
    let percentile: Int
    let trend: IntensityTrend
    
    private var recommendationType: RecommendationType {
        switch percentile {
        case 0..<20:    // Cleanest 20%
            return .excellent
        case 20..<40:   // Cleaner than average
            return .good
        case 40..<60:   // Average
            return .okay
        case 60..<80:   // Dirtier than average
            return .delay
        default:        // Dirtiest 20%
            return .avoid
        }
    }
    
    private var recommendationMessage: String {
        switch recommendationType {
        case .excellent:
            return "Excellent Time for Heavy Loads"
        case .good:
            return "Good Time for Heavy Loads"
        case .okay:
            return "OK for Normal Tasks"
        case .delay:
            return "Delay Heavy Loads"
        case .avoid:
            return "Avoid Heavy Loads - Very Dirty Grid"
        }
    }
    
    private var recommendationIcon: String {
        switch recommendationType {
        case .excellent:
            return "star.circle.fill"  // Star for excellent conditions
        case .good:
            return "checkmark.circle.fill"  // Checkmark for good conditions
        case .okay:
            return "equal.circle.fill"  // Equal sign for average conditions
        case .delay:
            return "clock.circle.fill"  // Clock for delay recommendation
        case .avoid:
            return "xmark.circle.fill"  // X for avoid recommendation
        }
    }
    
    private var intensityColor: Color {
        // Use same quintile colors as graph
        switch percentile {
        case 0..<20:    // Cleanest 20%
            return Color(red: 0/255, green: 153/255, blue: 0/255)      // Dark Green
        case 20..<40:   // Cleaner than average
            return Color(red: 93/255, green: 181/255, blue: 41/255)    // Light Green
        case 40..<60:   // Average
            return Color(red: 253/255, green: 173/255, blue: 58/255)   // Yellow
        case 60..<80:   // Dirtier than average
            return Color(red: 247/255, green: 110/255, blue: 45/255)   // Orange
        default:        // Dirtiest 20%
            return Color(red: 220/255, green: 20/255, blue: 9/255)     // Red
        }
    }
    
    private var comparisonText: String {
        percentile <= 50 ? "Cleaner than" : "Dirtier than"  // Lower percentile means cleaner
    }
    
    private var displayPercentile: Int {
        percentile <= 50 ? (100 - percentile) : percentile  // Show how much cleaner/dirtier
    }
    
    private var trendText: String {
        trend == .decreasing ? "Getting Cleaner" : "Getting Dirtier"
    }
    
    private var trendColor: Color {
        trend == .decreasing ? .green : .red
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: recommendationIcon)
                    .font(.title)
                Text(recommendationMessage)
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundColor(intensityColor)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(intensity)")
                    .font(.system(size: 44, design: .rounded).bold())
                Text("gCO₂/kWh")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(intensityColor)
            
            (Text(comparisonText)
                .foregroundColor(.primary)
            + Text(" \(displayPercentile)%")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(intensityColor)
            + Text(" of the last 24 hours")
                .foregroundColor(.primary))
                .font(.system(size: 16))
            
            if trend != .stable {
                HStack(spacing: 6) {
                    TrendSparkLine(trend: trend)
                        .foregroundColor(trendColor)
                    Text(trendText)
                        .fontWeight(.semibold)
                }
                .foregroundColor(trendColor)
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct FooterInfoView: View {
    let zone: String
    let updatedAt: String
    
    private var localTime: String {
        // Convert UTC string to local time
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy h:mm a"  // Match API format
        
        if let utcDate = formatter.date(from: updatedAt) {
            formatter.dateFormat = "h:mm a"  // e.g., "3:42 PM"
            formatter.timeZone = TimeZone.current
            return formatter.string(from: utcDate)
        }
        return updatedAt
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(zone)
            Text("•")
                .foregroundColor(.secondary.opacity(0.5))
            Text("Updated \(localTime)")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

struct SkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Recommendation Card Skeleton
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 30, height: 30)
                        SkeletonRectangle(width: 220, height: 24)
                    }
                    
                    // Value and units
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        SkeletonRectangle(width: 120, height: 52)
                        SkeletonRectangle(width: 80, height: 16)
                    }
                    
                    // Percentile text
                    SkeletonRectangle(width: 200, height: 20)
                    
                    // Trend indicator
                    HStack {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 20, height: 20)
                        SkeletonRectangle(width: 100, height: 16)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Graph Skeleton - Matching actual graph
                VStack(alignment: .leading, spacing: 8) {
                    Text("24-Hour History")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<24, id: \.self) { index in
                            SkeletonRectangle(width: 8, height: 40 + CGFloat.random(in: 0...80))
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Power Sources Grid Skeleton - Matching actual grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Grid Sources")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            VStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 24, height: 24)
                                    SkeletonRectangle(width: 40, height: 20)
                                }
                                
                                SkeletonRectangle(width: 60, height: 14)
                                
                                SkeletonRectangle(width: 70, height: 12)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Footer Skeleton - Matching actual footer
                VStack(spacing: 4) {
                    SkeletonRectangle(width: 120, height: 14)
                    SkeletonRectangle(width: 180, height: 12)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct SkeletonRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(width: width, height: height)
            .cornerRadius(4)
    }
}

struct HistoricalGraphView: View {
    let data: [HistoricalDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24-Hour History")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            CarbonGraphView(data: data)
                .frame(height: 200)
        }
        .padding(.vertical)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

// Add this enum at the top level
private enum RecommendationType {
    case excellent
    case good
    case okay
    case delay
    case avoid
}

#Preview {
    ContentView()
}
