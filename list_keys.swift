import Foundation
import Security

let keychainService = "com.sonorstudio.VisorPro.License"
let licenseAccount = "earlyAdopterKey"

func printKeychainItems() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: licenseAccount,
        kSecReturnData as String: true,
        kSecReturnAttributes as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll
    ]
    
    print("--- SEARCHING LOCAL KEYCHAIN (Synchronizable: false) ---")
    var localQuery = query
    localQuery[kSecAttrSynchronizable as String] = false
    var items: CFTypeRef?
    var status = SecItemCopyMatching(localQuery as CFDictionary, &items)
    
    if status == errSecSuccess, let arr = items as? [NSDictionary] {
        for (index, dict) in arr.enumerated() {
            print("Local Item [\(index + 1)]:")
            printDetails(dict: dict)
        }
    } else {
        print("No local items found. Status: \(status)")
    }
    
    print("\n--- SEARCHING ICLOUD KEYCHAIN (Synchronizable: true) ---")
    var cloudQuery = query
    cloudQuery[kSecAttrSynchronizable as String] = true
    items = nil
    status = SecItemCopyMatching(cloudQuery as CFDictionary, &items)
    
    if status == errSecSuccess, let arr = items as? [NSDictionary] {
        for (index, dict) in arr.enumerated() {
            print("iCloud Item [\(index + 1)]:")
            printDetails(dict: dict)
        }
    } else {
        print("No iCloud items found. Status: \(status)")
    }
}

func printDetails(dict: NSDictionary) {
    let sysDate = dict[kSecAttrCreationDate as String] as? Date
    let modDate = dict[kSecAttrModificationDate as String] as? Date
    let comment = dict[kSecAttrComment as String] as? String ?? "NONE"
    
    var keyStr = "UNKNOWN"
    if let data = dict[kSecValueData as String] as? Data, let s = String(data: data, encoding: .utf8) {
        keyStr = s
    }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    
    print("  Key: \(keyStr)")
    print("  System Creation Date: \(sysDate != nil ? formatter.string(from: sysDate!) : "UNKNOWN")")
    print("  System Mod Date:      \(modDate != nil ? formatter.string(from: modDate!) : "UNKNOWN")")
    print("  Comment (Saved Date): \(comment)")
}

printKeychainItems()
