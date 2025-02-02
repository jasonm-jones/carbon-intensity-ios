import SwiftUI
import Shared

struct DebugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLog: DebugLog?
    @State private var showingCopyConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                AppInfoSection()
                APIConfigSection()
                
                Section("Debug Logs") {
                    ForEach(DebugLogger.logs.reversed()) { log in
                        Button {
                            selectedLog = log
                        } label: {
                            DebugLogRow(log: log)
                        }
                    }
                }
            }
            .navigationTitle("Debug Info")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        DebugLogger.clearLogs()
                    }
                }
            }
            .sheet(item: $selectedLog) { log in
                NavigationView {
                    LogDetailView(log: log)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    selectedLog = nil
                                }
                            }
                            
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    UIPasteboard.general.string = formatLogForCopy(log)
                                    showingCopyConfirmation = true
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                        }
                }
                .toast(isPresenting: $showingCopyConfirmation) {
                    ToastView(message: "Copied to clipboard")
                }
            }
        }
    }
    
    private func formatLogForCopy(_ log: DebugLog) -> String {
        var text = "[\(log.type.rawValue.uppercased())] \(log.message)"
        if let details = log.details {
            text += "\nDetails: \(details)"
        }
        text += "\nTimestamp: \(log.timestamp)"
        return text
    }
}

struct LogDetailView: View {
    let log: DebugLog
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        List {
            Section {
                LabeledContent("Type", value: log.type.rawValue.uppercased())
                LabeledContent("Time", value: timeFormatter.string(from: log.timestamp))
            }
            
            Section("Message") {
                Text(log.message)
                    .font(.body)
                    .textSelection(.enabled)
            }
            
            if let details = log.details {
                Section("Details") {
                    Text(details)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Log Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 5)
    }
}

extension View {
    func toast(isPresenting: Binding<Bool>, duration: TimeInterval = 2, content: @escaping () -> some View) -> some View {
        self.modifier(ToastModifier(isPresenting: isPresenting, duration: duration, content: content))
    }
}

struct ToastModifier<T: View>: ViewModifier {
    @Binding var isPresenting: Bool
    let duration: TimeInterval
    let content: () -> T
    
    func body(content parentContent: Content) -> some View {
        ZStack {
            parentContent
            
            if isPresenting {
                self.content()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isPresenting = false
                            }
                        }
                    }
            }
        }
    }
}

struct AppInfoSection: View {
    var body: some View {
        Section("App Info") {
            LabeledContent("Version", value: Bundle.main.releaseVersionNumber)
            LabeledContent("Build", value: Bundle.main.buildVersionNumber)
        }
    }
}

struct APIConfigSection: View {
    var body: some View {
        Section("API Configuration") {
            LabeledContent("Zone", value: Configuration.zone)
            LabeledContent("Has API Key", value: Configuration.hasApiKey ? "Yes" : "No")
        }
    }
}

struct DebugLogRow: View {
    let log: DebugLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.message)
                .font(.subheadline)
            if let details = log.details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(log.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .foregroundColor(log.type == .error ? .red : .primary)
    }
}

// Helper extensions for app version info
extension Bundle {
    var releaseVersionNumber: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildVersionNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

#Preview {
    DebugView()
} 