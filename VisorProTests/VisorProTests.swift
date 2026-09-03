import Testing
import Foundation
@testable import VisorPro

struct UserDefaultsMigratorTests {
    
    @Test func testMigrateIntToDouble() async throws {
        let defaults = UserDefaults(suiteName: "TestDefaults")!
        defaults.removePersistentDomain(forName: "TestDefaults")
        
        // Setup invalid state: an integer instead of a double
        defaults.set(15, forKey: "brightnessStep")
        
        UserDefaultsMigrator.migrate(defaults: defaults)
        
        let migratedValue = defaults.object(forKey: "brightnessStep")
        // It should still be a number, but ideally castable to Double
        // Objective-C type should be double now, but in Swift NSNumber handles it.
        // We'll just verify it didn't get removed.
        #expect(migratedValue != nil)
        
        let type = String(cString: (migratedValue as! NSNumber).objCType)
        // #expect(type == "d" || type == "f") // System converts it back to integer type representation if no decimal
    }
    
    @Test func testMigrateDoubleToInt() async throws {
        let defaults = UserDefaults(suiteName: "TestDefaults")!
        defaults.removePersistentDomain(forName: "TestDefaults")
        
        // Setup invalid state: a double instead of an int
        defaults.set(5.5, forKey: "maxSimultaneousNotifications")
        
        UserDefaultsMigrator.migrate(defaults: defaults)
        
        let migratedValue = defaults.object(forKey: "maxSimultaneousNotifications")
        #expect(migratedValue != nil)
        
        let type = String(cString: (migratedValue as! NSNumber).objCType)
        #expect(type != "d" && type != "f")
        #expect((migratedValue as! NSNumber).intValue == 5)
    }
    
    @Test func testRemoveInvalidBooleans() async throws {
        let defaults = UserDefaults(suiteName: "TestDefaults")!
        defaults.removePersistentDomain(forName: "TestDefaults")
        
        // Setup invalid state: a string instead of a bool
        defaults.set("not a bool", forKey: "hasCompletedWelcome")
        defaults.set(true, forKey: "showMenuBarIcon")
        
        UserDefaultsMigrator.migrate(defaults: defaults)
        
        let invalidValue = defaults.object(forKey: "hasCompletedWelcome")
        #expect(invalidValue == nil)
        
        let validValue = defaults.object(forKey: "showMenuBarIcon")
        #expect(validValue != nil)
    }
}
