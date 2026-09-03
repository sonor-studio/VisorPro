import Foundation
import Security
import Combine

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var isPremium: Bool = false
    @Published var isEarlyAdopter: Bool = false
    @Published var licenseKey: String? = nil
    @Published var joinDate: Date? = nil
    
    private let keychainService = "com.sonorstudio.VisorPro.License"
    private let licenseAccount = "earlyAdopterKey"
    
    private init() {
        checkAndIssueLicense()
    }
    
    struct ParsedLicense {
        let key: String
        let joinDate: Date
        let isSynced: Bool
    }
    
    func checkAndIssueLicense() {
        let allItems = readAllKeychainItems()
        
        var parsedItems: [ParsedLicense] = []
        let formatter = ISO8601DateFormatter()
        
        for dict in allItems {
            if let data = dict[kSecValueData as String] as? Data,
               let keyStr = String(data: data, encoding: .utf8) {
                
                let sysDate = dict[kSecAttrCreationDate as String] as? Date ?? Date()
                let comment = dict[kSecAttrComment as String] as? String ?? ""
                
                // If we previously saved the original date in the comment, use it. Otherwise fallback to system creation date.
                let jDate = formatter.date(from: comment) ?? sysDate
                let isSync = dict[kSecAttrSynchronizable as String] as? Bool ?? false
                
                parsedItems.append(ParsedLicense(key: keyStr, joinDate: jDate, isSynced: isSync))
            }
        }
        
        if parsedItems.isEmpty {
            // Brand new user, no keys found anywhere
            let randomPart = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).uppercased()
            let formattedRandom = stride(from: 0, to: randomPart.count, by: 4).map {
                let start = randomPart.index(randomPart.startIndex, offsetBy: $0)
                let end = randomPart.index(start, offsetBy: 4, limitedBy: randomPart.endIndex) ?? randomPart.endIndex
                return String(randomPart[start..<end])
            }.joined(separator: "-")
            
            let newKey = "EA-\(formattedRandom)"
            let newDate = Date()
            
            if saveToKeychain(key: newKey, date: newDate) {
                self.licenseKey = newKey
                self.joinDate = newDate
                self.isPremium = true
                self.isEarlyAdopter = true
                LogManager.shared.log("Issued new early adopter license and saved to Keychain.", level: "INFO")
            } else {
                LogManager.shared.log("Failed to save license to Keychain.", level: "ERROR")
            }
            
        } else {
            // User has one or more keys.
            // 1. ALWAYS pick the oldest key by date to protect against overwrite bugs.
            parsedItems.sort { $0.joinDate < $1.joinDate }
            let oldest = parsedItems.first!
            
            self.licenseKey = oldest.key
            self.joinDate = oldest.joinDate
            self.isPremium = true
            self.isEarlyAdopter = oldest.key.hasPrefix("EA-")
            LogManager.shared.log("License found. Premium: true, Early Adopter: \(self.isEarlyAdopter)", level: "INFO")
            
            // 2. Self-healing & iCloud Sync Promotion
            let needsCleanup = parsedItems.count > 1
            let needsPromotion = !oldest.isSynced
            
            if needsCleanup || needsPromotion {
                LogManager.shared.log("Keychain needs cleanup/promotion. Duplicates: \(needsCleanup), Needs iCloud: \(needsPromotion)", level: "INFO")
                
                // Wipe ALL existing keys (both local and cloud) to start fresh
                let delQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: keychainService,
                    kSecAttrAccount as String: licenseAccount
                ]
                
                var dqCloud = delQuery; dqCloud[kSecAttrSynchronizable as String] = true
                SecItemDelete(dqCloud as CFDictionary)
                
                var dqLocal = delQuery; dqLocal[kSecAttrSynchronizable as String] = false
                SecItemDelete(dqLocal as CFDictionary)
                
                // Re-save the oldest key. This preserves its original date (via kSecAttrComment) and attempts to push to iCloud.
                _ = saveToKeychain(key: oldest.key, date: oldest.joinDate)
            }
        }
    }
    
    private func saveToKeychain(key: String, date: Date) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        let dateStr = ISO8601DateFormatter().string(from: date)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecValueData as String: data,
            kSecAttrComment as String: dateStr
        ]
        
        // Try iCloud first
        query[kSecAttrSynchronizable as String] = true
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            // Fallback to local keychain if iCloud sync fails or is disabled
            query[kSecAttrSynchronizable as String] = false
            status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecSuccess {
                LogManager.shared.log("Saved license to local Keychain.", level: "INFO")
            }
        } else {
            LogManager.shared.log("Saved license to iCloud Keychain.", level: "INFO")
        }
        
        return status == errSecSuccess
    }
    
    private func readAllKeychainItems() -> [[String: Any]] {
        var results: [[String: Any]] = []
        
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        // Query iCloud items explicitly
        var cloudQuery = baseQuery
        cloudQuery[kSecAttrSynchronizable as String] = true
        var items: CFTypeRef?
        if SecItemCopyMatching(cloudQuery as CFDictionary, &items) == errSecSuccess, let arr = items as? [[String: Any]] {
            results.append(contentsOf: arr)
        }
        
        // Query Local items explicitly
        var localQuery = baseQuery
        localQuery[kSecAttrSynchronizable as String] = false
        items = nil
        if SecItemCopyMatching(localQuery as CFDictionary, &items) == errSecSuccess, let arr = items as? [[String: Any]] {
            results.append(contentsOf: arr)
        }
        
        return results
    }
}
