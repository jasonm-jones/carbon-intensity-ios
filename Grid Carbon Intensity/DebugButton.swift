import SwiftUI

struct DebugButton: View {
    @Binding var showDebugView: Bool
    
    var body: some View {
        #if DEBUG
        Button(action: { showDebugView = true }) {
            Image(systemName: "ladybug.fill")
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showDebugView) {
            DebugView()
        }
        #endif
    }
} 