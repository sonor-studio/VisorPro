import Foundation
import Security

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.sonorstudio.VisorPro.License",
    kSecAttrAccount as String: "earlyAdopterKey"
]

var count = 0
// Delete iCloud
var cloudQuery = query
cloudQuery[kSecAttrSynchronizable as String] = true
let cStatus = SecItemDelete(cloudQuery as CFDictionary)
if cStatus == errSecSuccess { print("Wiped iCloud key(s)") }

// Delete Local
var localQuery = query
localQuery[kSecAttrSynchronizable as String] = false
let lStatus = SecItemDelete(localQuery as CFDictionary)
if lStatus == errSecSuccess { print("Wiped Local key(s)") }

// Delete Any (just to be absolutely certain)
let anyStatus = SecItemDelete(query as CFDictionary)
if anyStatus == errSecSuccess { print("Wiped generic key(s)") }

print("Keychain wiped for VisorPro. Status Cloud: \\(cStatus), Local: \\(lStatus)")
