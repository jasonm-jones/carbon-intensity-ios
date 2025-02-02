import SwiftUI

struct ApiKeySetupView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String
    @State private var zone: String
    @Environment(\.dismiss) private var dismiss
    
    // Initialize with existing values
    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _apiKey = State(initialValue: Configuration.apiKey)
        _zone = State(initialValue: Configuration.zone)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                        
                        Text("Electricity Maps Setup")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("To monitor your local grid's carbon intensity, you'll need an API key from Electricity Maps.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // API Key Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your API key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Link("Get an API key", destination: URL(string: "https://www.electricitymaps.com/get-access")!)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Zone Selection Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zone")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your zone (e.g., US-MISO)", text: $zone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Link("Find your zone", destination: URL(string: "https://app.electricitymaps.com/map")!)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Save Button
                    Button(action: {
                        Configuration.zone = zone
                        Configuration.apiKey = apiKey
                        isPresented = false
                    }) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                apiKey.isEmpty || zone.isEmpty ? 
                                    Color.gray : Color.green
                            )
                            .cornerRadius(12)
                    }
                    .disabled(apiKey.isEmpty || zone.isEmpty)
                    .padding(.top)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if Configuration.hasApiKey {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ApiKeySetupView(isPresented: .constant(true))
} 