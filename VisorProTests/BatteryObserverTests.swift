import Testing
import Foundation
@testable import VisorPro

struct BatteryObserverTests {
    
    @Test func testBatteryStateParsing() async throws {
        // We can create a lightweight "mock" MediaKeyManager. But MediaKeyManager is an ObservableObject.
        // It's not a protocol, so we will use the shared instance and check if properties are updated.
        let manager = MediaKeyManager.shared
        
        // Mock data from IOKit AppleSmartBattery
        let mockData: [String: Any] = [
            "CurrentCapacity": NSNumber(value: 80),
            "MaxCapacity": NSNumber(value: 100),
            "DesignCapacity": NSNumber(value: 100),
            "CycleCount": NSNumber(value: 15),
            "ExternalConnected": NSNumber(value: true),
            "IsCharging": NSNumber(value: true),
            "TimeRemaining": NSNumber(value: 120),
            "Voltage": NSNumber(value: 12000), // 12000 mV = 12 V
            "Amperage": NSNumber(value: 2000)  // 2000 mA = 2 A
            // Power = 12 V * 2 A = 24 W
        ]
        
        // Create our observer with injected mock data
        let observer = BatteryObserver(manager: manager, batteryDataProvider: {
            return mockData
        })
        
        // Trigger a check
        observer.refresh()
        
        // The observer runs its parsing logic.
        // In this case, `refresh()` just calls `updateLivePowerDraw()`. Let's see if PowerDraw gets updated.
        // Formula: Voltage * Amperage / 1,000,000
        // 12000 * 2000 / 1000000 = 24.0 W
        
        // Wait a tiny bit since properties might update on main thread?
        // Let's just check the synchronous changes if any, or sleep.
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        #expect(manager.batteryPowerDraw.contains("24.0") || manager.batteryPowerDraw.contains("24,0"))
    }
}
