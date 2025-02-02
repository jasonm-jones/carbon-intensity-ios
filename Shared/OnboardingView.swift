import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Your Grid's Carbon Intensity Varies",
            description: "Throughout the day, your electrical grid can be up to 80% cleaner or dirtier, depending on the availability of low carbon sources like solar, wind, hydro, and nuclear.",
            image: "chart.line.uptrend.xyaxis",
            color: .orange
        ),
        OnboardingPage(
            title: "Power Sources Matter",
            description: "Different power sources produce vastly different amounts of carbon. Clean sources like solar and nuclear produce almost no carbon, while coal produces 100x more!",
            image: "bolt.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Timing Matters",
            description: "By shifting energy-intensive tasks (like laundry, dishwashing, or EV charging) to cleaner times, you can reduce your carbon footprint by 20-50% or more.",
            image: "clock.arrow.circlepath",
            color: .purple
        ),
        OnboardingPage(
            title: "We'll Help You Choose",
            description: "We monitor your local grid in real-time and show you when it's cleanest to run high-energy tasks - at no cost to you.",
            image: "checkmark.circle",
            color: .indigo
        )
    ]
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            // Skip button in top right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        hasSeenOnboarding = true
                        dismiss()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
            
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: 30) {
                        Spacer()
                        
                        // Icon
                        Image(systemName: pages[index].image)
                            .font(.system(size: 80))
                            .foregroundColor(pages[index].color)
                        
                        // Title
                        Text(pages[index].title)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        // Description
                        Text(pages[index].description)
                            .font(.system(size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                        
                        Spacer()
                        
                        // Example visualization based on page
                        Group {
                            switch index {
                            case 0:
                                // Grid variability visualization
                                GridVariabilityView()
                            case 1:
                                // Power sources comparison
                                PowerSourcesComparisonView()
                            case 2:
                                // Task timing visualization
                                TaskTimingView()
                            case 3:
                                // App recommendation visualization
                                RecommendationExampleView()
                            default:
                                EmptyView()
                            }
                        }
                        .frame(height: 200)
                        
                        Spacer()
                        
                        // Get Started button on last page
                        if index == pages.count - 1 {
                            Button {
                                withAnimation {
                                    hasSeenOnboarding = true
                                    dismiss()
                                }
                            } label: {
                                Text("Get Started")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(pages[index].color)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 50)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let image: String
    let color: Color
}

// Example visualizations for each page
struct GridVariabilityView: View {
    // Sample data to demonstrate daily pattern
    let sampleData = [
        620, 610, 600,           // Morning peak (red)
        580, 570,               // Transition (light red)
        480, 450, 440,          // Midday solar (green)
        460, 470,               // Transition (light green)
        590, 610                // Evening peak (red)
    ]
    
    private let average: Int = 530
    
    var body: some View {
        VStack(spacing: 8) {
            // Graph
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let barSpacing: CGFloat = 4
                let barWidth = (width / CGFloat(sampleData.count)) - barSpacing
                let scale: CGFloat = height / 200  // Increased scale for even taller bars
                
                ZStack {
                    // Average line
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: width, height: 1)
                        .position(x: width/2, y: height/2)
                    
                    // Bars
                    HStack(spacing: barSpacing) {
                        ForEach(Array(sampleData.enumerated()), id: \.offset) { index, value in
                            let barHeight = CGFloat(abs(value - average)) * scale
                            let isHigher = value > average
                            let intensity = abs(value - average)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorForIntensity(intensity: intensity, isHigher: isHigher))
                                .frame(width: barWidth, height: barHeight)
                                .offset(y: isHigher ? -barHeight/2 : barHeight/2)
                        }
                    }
                }
            }
            
            // Label
            Text("24-Hour Grid Carbon Intensity")
                .font(.system(size: 16))  // Bigger caption
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 32)  // Match text margins
    }
    
    private func colorForIntensity(intensity: Int, isHigher: Bool) -> Color {
        if isHigher {
            return intensity > 50 ? .red : .red.opacity(0.7)
        } else {
            return intensity > 50 ? .green : .green.opacity(0.7)
        }
    }
}

struct TaskTimingView: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 44))
                    Text("11AM")
                        .font(.system(size: 16))  // Bigger time
                    Text("Low Carbon")
                        .font(.system(size: 14))  // Bigger label
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 44))
                    Text("8PM")
                        .font(.system(size: 16))  // Bigger time
                    Text("High Carbon")
                        .font(.system(size: 14))  // Bigger label
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {  // Increased spacing
                Image(systemName: "washer")
                Image(systemName: "ev.charger")
                Image(systemName: "dishwasher")
            }
            .font(.system(size: 36))  // Bigger icons
            .foregroundColor(.secondary)
        }
    }
}

struct RecommendationExampleView: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                    Text("Good Time for Heavy Loads")  // Updated text
                        .font(.system(size: 20, weight: .semibold))  // Bigger headline
                }
                .foregroundColor(Configuration.colorForPercentile(98))
                
                Text("24")
                    .font(.system(size: 44, design: .rounded).bold())  // Bigger number
                    .foregroundColor(Configuration.colorForPercentile(98))
                Text("gCO₂/kWh")
                    .font(.system(size: 16))  // Bigger unit
                    .foregroundColor(.secondary)
                
                (Text("Cleaner than ")
                    .foregroundColor(.primary)
                + Text("98%")
                    .font(.system(size: 20, weight: .bold))  // Much bigger percentage
                    .foregroundColor(Configuration.colorForPercentile(98))
                + Text(" of the last 24 hours")
                    .foregroundColor(.primary))
                    .font(.system(size: 16))  // Bigger base text
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct PowerSourcesComparisonView: View {
    let sources: [(name: String, emoji: String, intensity: Int, color: Color)] = [
        ("Wind", "💨", 11, .green),
        ("Nuclear", "⚛️", 12, .green),
        ("Hydro", "💧", 24, .green),
        ("Solar", "☀️", 27, .green),
        ("Gas", "🔥", 524, .orange),
        ("Coal", "🏭", 1097, .red)
    ].sorted { $0.intensity < $1.intensity }  // Sort by intensity
    
    var maxIntensity: Int { 1100 }  // Updated to show full scale including coal
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Carbon Intensity by Source")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach(sources, id: \.name) { source in
                    HStack(spacing: 12) {
                        Text(source.emoji)
                            .font(.system(size: 24))
                        
                        Text(source.name)
                            .font(.system(size: 16))
                            .frame(width: 80, alignment: .leading)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(source.color)
                                    .frame(
                                        width: min(
                                            CGFloat(source.intensity) / CGFloat(maxIntensity) * geometry.size.width,
                                            geometry.size.width
                                        ),
                                        height: 24
                                    )
                                
                                if source.intensity > maxIntensity {
                                    // Add arrow for values that exceed the scale
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.white)
                                        .offset(x: geometry.size.width - 20)
                                }
                            }
                            
                            Text("\(source.intensity)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .position(
                                    x: min(
                                        CGFloat(source.intensity) / CGFloat(maxIntensity) * geometry.size.width + 25,
                                        geometry.size.width - 20
                                    ),
                                    y: 12
                                )
                        }
                    }
                    .frame(height: 24)
                }
            }
            
            Text("gCO₂/kWh")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)  // Match spacing with other screens
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
} 