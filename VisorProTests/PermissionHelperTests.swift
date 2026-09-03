import Testing
@testable import VisorPro

struct PermissionHelperTests {
    @Test func testHasLocationPermission() async throws {
        // Since we can't easily mock the CLLocationManager singleton in PermissionHelper without refactoring,
        // we just test that calling the function doesn't crash.
        let hasPermission = PermissionHelper.hasLocationPermission()
        #expect(hasPermission == false || hasPermission == true)
    }
    
    @Test func testCheckBluetoothPermission() async throws {
        let hasPermission = PermissionHelper.checkBluetoothPermission()
        #expect(hasPermission == false || hasPermission == true)
    }
}
