import SwiftUI

public enum DebugSettings {
    @AppStorage("debugModeEnabled") public static var isEnabled = false
    
    public static func toggleDebugMode() {
        isEnabled.toggle()
    }
} 