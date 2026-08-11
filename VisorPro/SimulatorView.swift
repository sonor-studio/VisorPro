import SwiftUI

struct SimulatorView: View {
    @ObservedObject var mediaKeyManager: MediaKeyManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Power State Simulator")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Toggle("Enable Simulation", isOn: $mediaKeyManager.isSimulated)
                .toggleStyle(.checkbox)
                .font(.system(size: 13, weight: .medium))
            
            if mediaKeyManager.isSimulated {
                VStack(spacing: 16) {
                    Toggle("Plugged into Power", isOn: $mediaKeyManager.isPluggedIn)
                        .toggleStyle(.switch)
                        .font(.system(size: 13))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Battery:")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(mediaKeyManager.currentBatteryPercentage)%")
                                .font(.system(size: 12, weight: .bold))
                                .monospacedDigit()
                        }
                        
                        Slider(value: Binding(
                            get: { Double(mediaKeyManager.currentBatteryPercentage) },
                            set: { mediaKeyManager.currentBatteryPercentage = Int($0) }
                        ), in: 0...100, step: 1)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                Text("Listening to real system events...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 100)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
