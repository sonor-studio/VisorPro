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
        } else {
            let randomPart = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).uppercased()
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
    
    private func saveToKeychain(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount
        ]
        
        // Delete any existing items (both synced and local will be matched without the sync attribute)
        SecItemDelete(query as CFDictionary)
        
        var addQuery = query
        addQuery[kSecValueData as String] = data
        // Explicitly force to local login keychain for maximum reliability across reinstalls
        addQuery[kSecAttrSynchronizable as String] = false
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            LogManager.shared.log("Saved license to Keychain.", level: "INFO")
            return true
        }
        return false
    }
    
    private func readFromKeychain() -> (key: String, date: Date)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll // Fetch all duplicates if any
        ]
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        if status == errSecSuccess, let array = items as? [[String: Any]], !array.isEmpty {
            
            // Sort by creation date so we always pick the OLDEST one (the original license)
            let sortedArray = array.sorted { (dict1, dict2) -> Bool in
                let date1 = dict1[kSecAttrCreationDate as String] as? Date ?? Date()
                let date2 = dict2[kSecAttrCreationDate as String] as? Date ?? Date()
                return date1 < date2
            }
            
            let oldestItem = sortedArray.first!
            
            // If there are duplicates, purge them and keep only the oldest one
            if array.count > 1 {
                SecItemDelete(query as CFDictionary)
                
                let restoreQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: keychainService,
                    kSecAttrAccount as String: licenseAccount,
                    kSecValueData as String: oldestItem[kSecValueData as String]!,
                    kSecAttrSynchronizable as String: false
                ]
                // Optional: carry over creation date if possible (usually read-only on creation)
                SecItemAdd(restoreQuery as CFDictionary, nil)
            }
            
            if let data = oldestItem[kSecValueData as String] as? Data,
               let keyString = String(data: data, encoding: .utf8) {
               
               let creationDate = oldestItem[kSecAttrCreationDate as String] as? Date ?? Date()
               return (keyString, creationDate)
            }
        }
        
        return nil
    }
}
