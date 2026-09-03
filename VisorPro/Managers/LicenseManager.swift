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
    
    func checkAndIssueLicense() {
        if let existing = readFromKeychain() {
            self.licenseKey = existing.key
            self.joinDate = existing.date
            self.isPremium = true
            self.isEarlyAdopter = existing.key.hasPrefix("EA-")
            LogManager.shared.log("License found in Keychain. Premium: true, Early Adopter: \(self.isEarlyAdopter)", level: "INFO")
            
            if !existing.isSynchronized {
                tryUpgradeToCloudKeychain(key: existing.key)
            }
        } else {
            // Currently in early adopter phase, so we issue a key to everyone automatically.
            let randomPart = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).uppercased()
            // Format as EA-XXXX-XXXX-XXXX-XXXX for better readability
            let formattedRandom = stride(from: 0, to: randomPart.count, by: 4).map {
                let start = randomPart.index(randomPart.startIndex, offsetBy: $0)
                let end = randomPart.index(start, offsetBy: 4, limitedBy: randomPart.endIndex) ?? randomPart.endIndex
                return String(randomPart[start..<end])
            }.joined(separator: "-")
            
            let newKey = "EA-\(formattedRandom)"
            
            if saveToKeychain(newKey) {
                self.licenseKey = newKey
                self.joinDate = Date()
                self.isPremium = true
                self.isEarlyAdopter = true
                LogManager.shared.log("Issued new early adopter license and saved to Keychain.", level: "INFO")
            } else {
                LogManager.shared.log("Failed to save license to Keychain.", level: "ERROR")
            }
        }
    }
    
    private func tryUpgradeToCloudKeychain(key: String) {
        guard let data = key.data(using: .utf8) else { return }
        
        let cloudQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true
        ]
        
        SecItemDelete(cloudQuery as CFDictionary)
        let status = SecItemAdd(cloudQuery as CFDictionary, nil)
        
        if status == errSecSuccess {
            let localQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: licenseAccount,
                kSecAttrSynchronizable as String: false
            ]
            SecItemDelete(localQuery as CFDictionary)
            LogManager.shared.log("Upgraded license to iCloud Keychain.", level: "INFO")
        }
    }
    
    private func saveToKeychain(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true
        ]
        
        // Try iCloud first
        SecItemDelete(query as CFDictionary)
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            // Fallback to local keychain if iCloud sync fails
            query[kSecAttrSynchronizable as String] = false
            SecItemDelete(query as CFDictionary)
            status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecSuccess {
                LogManager.shared.log("Saved license to local Keychain as fallback.", level: "INFO")
            }
        }
        
        return status == errSecSuccess
    }
    
    private func readFromKeychain() -> (key: String, date: Date, isSynchronized: Bool)? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]
        
        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        var bestItem: [String: Any]? = nil
        
        if status == errSecSuccess, let dict = item as? [String: Any] {
            bestItem = dict
        } else {
            // Fallback: search for local item
            query[kSecAttrSynchronizable as String] = false
            status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess, let dict = item as? [String: Any] {
                bestItem = dict
            }
        }
        
        if let bestItem = bestItem,
           let data = bestItem[kSecValueData as String] as? Data,
           let keyString = String(data: data, encoding: .utf8) {
           
           let creationDate = bestItem[kSecAttrCreationDate as String] as? Date ?? Date()
           let isSync = bestItem[kSecAttrSynchronizable as String] as? Bool ?? false
           return (keyString, creationDate, isSync)
        }
        
        return nil
    }
}
