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
                
                let jDate = formatter.date(from: comment) ?? sysDate
                let isSync = dict[kSecAttrSynchronizable as String] as? Bool ?? false
                
                parsedItems.append(ParsedLicense(key: keyStr, joinDate: jDate, isSynced: isSync))
            }
        }
        
        if parsedItems.isEmpty {
            let randomPart = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).uppercased()
            let formattedRandom = stride(from: 0, to: randomPart.count, by: 4).map {
                let start = randomPart.index(randomPart.startIndex, offsetBy: $0)
                let end = randomPart.index(start, offsetBy: 4, limitedBy: randomPart.endIndex) ?? randomPart.endIndex
                return String(randomPart[start..<end])
            }.joined(separator: "-")
            
            let newKey = "EA-\(formattedRandom)"
            let newDate = Date()
            
            if saveToKeychain(key: newKey, date: newDate) {
                DispatchQueue.main.async {
                    self.licenseKey = newKey
                    self.joinDate = newDate
                    self.isPremium = true
                    self.isEarlyAdopter = true
                }
                LogManager.shared.log("Issued new early adopter license and saved to Keychain.", level: "INFO")
            } else {
                LogManager.shared.log("Failed to save license to Keychain.", level: "ERROR")
            }
            
        } else {
            parsedItems.sort { $0.joinDate < $1.joinDate }
            let oldest = parsedItems.first!
            let isEA = oldest.key.hasPrefix("EA-")
            
            DispatchQueue.main.async {
                self.licenseKey = oldest.key
                self.joinDate = oldest.joinDate
                self.isPremium = true
                self.isEarlyAdopter = isEA
            }
            LogManager.shared.log("License found. Premium: true, Early Adopter: \(isEA)", level: "INFO")
            
            let needsCleanup = parsedItems.count > 1
            let needsPromotion = !oldest.isSynced
            
            if needsCleanup || needsPromotion {
                LogManager.shared.log("Keychain needs cleanup/promotion. Duplicates: \(needsCleanup), Needs iCloud: \(needsPromotion)", level: "INFO")
                
                let delQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: keychainService,
                    kSecAttrAccount as String: licenseAccount
                ]
                
                var dqCloud = delQuery; dqCloud[kSecAttrSynchronizable as String] = true
                SecItemDelete(dqCloud as CFDictionary)
                
                var dqLocal = delQuery; dqLocal[kSecAttrSynchronizable as String] = false
                SecItemDelete(dqLocal as CFDictionary)
                
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
        
        let delQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount
        ]
        var dqCloud = delQuery; dqCloud[kSecAttrSynchronizable as String] = true
        SecItemDelete(dqCloud as CFDictionary)
        var dqLocal = delQuery; dqLocal[kSecAttrSynchronizable as String] = false
        SecItemDelete(dqLocal as CFDictionary)
        
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
        if SecItemCopyMatching(cloudQuery as CFDictionary, &items) == errSecSuccess, let arr = items as? [NSDictionary] {
            results.append(contentsOf: arr.compactMap { $0 as? [String: Any] })
        }
        
        // Query Local items explicitly
        var localQuery = baseQuery
        localQuery[kSecAttrSynchronizable as String] = false
        items = nil
        if SecItemCopyMatching(localQuery as CFDictionary, &items) == errSecSuccess, let arr = items as? [NSDictionary] {
            results.append(contentsOf: arr.compactMap { $0 as? [String: Any] })
        }
        
        return results
    }
}
