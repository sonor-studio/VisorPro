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
    
    private func saveToKeychain(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true
        ]
        
        // Delete any existing item to ensure we can save a new one (though logically it shouldn't exist here)
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func readFromKeychain() -> (key: String, date: Date)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: licenseAccount,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let dict = item as? [String: Any],
           let data = dict[kSecValueData as String] as? Data,
           let keyString = String(data: data, encoding: .utf8) {
           
           let creationDate = dict[kSecAttrCreationDate as String] as? Date ?? Date()
           return (keyString, creationDate)
        }
        return nil
    }
}
