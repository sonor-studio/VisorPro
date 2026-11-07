import Foundation
import AppKit
import SwiftUI

extension MediaKeyManager {
    
    func triggerClipboardIndicator(text: String, action: String = "copy", app: String = "", folder: String? = nil, size: String = "", isMasked: Bool = false) {
        if !enableClipboard { return }
        
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }
        
        if action == "copy" && !notifyOnCopy { return }
        if action == "cut" && !notifyOnCut { return }
        if action == "paste" && !notifyOnPaste && !isProgrammaticPasteboardChange { return }
        
        if action == "copy" { playNotificationSound(named: soundOnCopy) }
        else if action == "cut" { playNotificationSound(named: soundOnCut) }
        else if action == "paste" { playNotificationSound(named: soundOnPaste) }
        
        copyTimer?.invalidate()
        pendingClipboardShowTask?.cancel()
        cancelOverlayHide(for: "copy")
        
        let copyPos = self.getOverlayPosition(for: "copyOverlayPosition")
        dismissCollidingIndicators(newPosition: copyPos, source: "copy")
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let executeShow = { [weak self] in
            guard let self = self else { return }
            
            // Apply published states right before showing, preventing layout jumps on closing view
            self.copiedText = trimmedText
            self.clipboardAction = action
            self.clipboardSourceApp = app
            self.clipboardSourceFolder = folder
            self.clipboardMetadataSize = size
            self.isClipboardMasked = isMasked
            self.clipboardEventId = UUID()
            
            if self.clipboardEnableHistory {
                // Add element to history (if it differs from the previous one)
                if !trimmedText.isEmpty {
                    if self.clipboardHistory.first?.text != trimmedText {
                        let newItem = ClipboardItem(text: trimmedText, app: app, folder: folder, size: size, timestamp: Date(), isMasked: isMasked)
                        self.clipboardHistory.insert(newItem, at: 0)
                        self.cleanupClipboardHistory()
                    } else if !self.clipboardHistory.isEmpty {
                        self.clipboardHistory[0].isMasked = isMasked
                    }
                }
            }
            
            withAnimation(.easeInOut(duration: 0.15)) {
                self.showCopyIndicator = true
                self.notifyOverlayStateChanged()
                self.overlayTriggerTimes["copy"] = Date()
            }
            
            self.scheduleOverlayHide(for: "copy")
        }
        
        if self.showCopyIndicator && self.clipboardAction != action && action != "paste" {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showCopyIndicator = false
            }
            let task = DispatchWorkItem(block: executeShow)
            self.pendingClipboardShowTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        } else {
            executeShow()
        }
    }
    
    internal func getFinderActiveFolder() -> String? {
        let script = """
        tell application "Finder"
            try
                set theTarget to target of front Finder window
                return POSIX path of (theTarget as alias)
            on error
                return POSIX path of (path to desktop folder as alias)
            end try
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let output = appleScript.executeAndReturnError(&error)
            if let stringValue = output.stringValue {
                var path = stringValue
                if path.hasSuffix("/") && path.count > 1 {
                    path.removeLast()
                }
                return path
            }
        }
        return nil
    }

    internal func isURLOrDomain(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || 
           lower.hasPrefix("https://") || 
           lower.hasPrefix("ftp://") || 
           lower.hasPrefix("file://") || 
           lower.hasPrefix("www.") {
            return true
        }
        
        // Cannot be a URL/domain if it contains whitespace, newlines, or '@' (emails handled separately)
        if lower.contains(" ") || lower.contains("\n") || lower.contains("\r") || lower.contains("\t") || lower.contains("@") {
            return false
        }
        
        // Extract host portion (before '/', '?', '#', ':')
        let hostPort = lower.components(separatedBy: CharacterSet(charactersIn: "/?#")).first ?? lower
        let host = hostPort.components(separatedBy: ":").first ?? hostPort
        
        if host == "localhost" {
            return true
        }
        
        let parts = host.split(separator: ".")
        // Check IPv4 address format (e.g. 192.168.1.1)
        if parts.count == 4 && parts.allSatisfy({ if let n = Int($0), n >= 0 && n <= 255 { return true }; return false }) {
            return true
        }
        
        // Check Domain / Hostname format (e.g. auth.services.adobe.com or apple.com)
        if parts.count >= 2 {
            guard let tld = parts.last else { return false }
            // Valid TLDs consist solely of letters and are 2 to 24 characters long
            if tld.count >= 2 && tld.count <= 24 && tld.allSatisfy({ $0.isLetter }) {
                let validLabels = parts.allSatisfy { label in
                    guard !label.isEmpty, !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
                    return label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
                }
                if validLabels {
                    return true
                }
            }
        }
        
        return false
    }

    func processClipboardData(for action: String) -> (text: String, app: String, folder: String?, size: String, isMasked: Bool) {
        let board = NSPasteboard.general
        var text = "File / Image"
        var sizeStr = ""
        var folder: String? = nil
        var isMasked = false
        
        let types = board.types ?? []
        let hasFileURL = types.contains(.fileURL) || types.contains(NSPasteboard.PasteboardType("public.file-url")) || types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        
        if hasFileURL, let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            if urls.count > 1 {
                text = "\(urls.count) files"
                folder = urls.first?.deletingLastPathComponent().path
                sizeStr = "\(urls.count) items"
            } else {
                let firstUrl = urls.first!
                text = firstUrl.lastPathComponent
                folder = firstUrl.deletingLastPathComponent().path
                
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: firstUrl.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        if let contents = try? FileManager.default.contentsOfDirectory(atPath: firstUrl.path) {
                            sizeStr = "\(contents.count) items"
                        } else {
                            sizeStr = "Folder"
                        }
                    } else {
                        if let attr = try? FileManager.default.attributesOfItem(atPath: firstUrl.path),
                           let size = attr[.size] as? UInt64 {
                            let formatter = ByteCountFormatter()
                            formatter.allowedUnits = [.useAll]
                            formatter.countStyle = .file
                            sizeStr = formatter.string(fromByteCount: Int64(size))
                        } else {
                            sizeStr = "Unknown"
                        }
                    }
                } else {
                    sizeStr = "Unknown"
                }
            }
            
            if action == "paste" && frontApp == "Finder" {
                if let destFolder = self.getFinderActiveFolder() {
                    folder = destFolder
                }
            }
        } else if let copiedText = board.string(forType: .string) {
            text = copiedText
            sizeStr = "\(copiedText.count)"
            
            let showPasswordToggle = UserDefaults.standard.object(forKey: "clipboardShowPasswordToggle") as? Bool ?? true
            if showPasswordToggle && !copiedText.isEmpty {
                let lower = copiedText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Exclude URLs and domain names (e.g. auth.services.adobe.com, https://...) from password masking
                let isURL = self.isURLOrDomain(copiedText)
                
                // Exclude valid email addresses from password masking
                let isEmail: Bool = {
                    if lower.contains(" ") || lower.contains("\n") || lower.contains("\r") || !lower.contains("@") {
                        return false
                    }
                    let parts = lower.split(separator: "@")
                    if parts.count == 2 {
                        let domain = parts[1]
                        if domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") {
                            let tld = domain.split(separator: ".").last ?? ""
                            return tld.count >= 2 && tld.allSatisfy { $0.isLetter }
                        }
                    }
                    return false
                }()
                
                // Exclude long notes or multiline text (passwords do not contain linebreaks or long sentences with spaces)
                let isMultilineOrNote = copiedText.contains("\n") || copiedText.contains("\r") || (copiedText.contains(" ") && copiedText.count > 30)
                
                if !isURL && !isEmail && !isMultilineOrNote {
                    let sensitivePasteboardTypes: Set<String> = [
                        "org.nspasteboard.ConcealedType",
                        "com.agilebits.onepassword",
                        "com.apple.is-sensitive",
                        "org.nspasteboard.AutoGeneratedType",
                        "de.petermaurer.TransientPasteboardType",
                        "ConcealedType",
                        "com.apple.security.pboard.concealed"
                    ]
                    let hasConcealedMarker = types.contains { sensitivePasteboardTypes.contains($0.rawValue) }
                    
                    let frontAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() ?? ""
                    let frontAppName = (NSWorkspace.shared.frontmostApplication?.localizedName ?? "").lowercased()
                    
                    let isPasswordManagerApp = frontAppBundleId.contains("passwords") ||
                                               frontAppBundleId.contains("keychain") ||
                                               frontAppBundleId.contains("1password") ||
                                               frontAppBundleId.contains("bitwarden") ||
                                               frontAppBundleId.contains("keepass") ||
                                               frontAppBundleId.contains("dashlane") ||
                                               frontAppBundleId.contains("enpass") ||
                                               frontAppBundleId.contains("proton.pass") ||
                                               frontAppBundleId.contains("protonmail.pass") ||
                                               frontAppBundleId.contains("lastpass") ||
                                               frontAppBundleId.contains("nordpass") ||
                                               frontAppBundleId.contains("keeper") ||
                                               frontAppBundleId.contains("roboform") ||
                                               frontAppBundleId.contains("strongbox") ||
                                               frontAppName == "passwords" ||
                                               frontAppName == "hasła" ||
                                               frontAppName == "passwörter" ||
                                               frontAppName == "mots de passe" ||
                                               frontAppName == "keychain access" ||
                                               frontAppName == "dostęp do pęku kluczy" ||
                                               frontAppName.contains("1password") ||
                                               frontAppName.contains("bitwarden") ||
                                               frontAppName.contains("keepass") ||
                                               frontAppName.contains("dashlane") ||
                                               frontAppName.contains("enpass") ||
                                               frontAppName.contains("proton pass") ||
                                               frontAppName.contains("lastpass") ||
                                               frontAppName.contains("nordpass")
                    
                    let hasSpecialPasswordSymbol = copiedText.contains { "!@#$%^&*()+=[]{}|;:'\",?`~\\".contains($0) }
                    let hasUppercase = copiedText.contains { $0.isUppercase }
                    let hasLowercase = copiedText.contains { $0.isLowercase }
                    let hasDigit = copiedText.contains { $0.isNumber }
                    let hasLetter = hasUppercase || hasLowercase
                    
                    let isTOTP = copiedText.count >= 6 && copiedText.count <= 8 && copiedText.allSatisfy { $0.isNumber }
                    let isComplexPassword = copiedText.count >= 6 && (hasSpecialPasswordSymbol || (hasUppercase && hasLowercase && hasDigit) || (hasLetter && hasDigit))
                    
                    if hasConcealedMarker {
                        isMasked = true
                    } else if isPasswordManagerApp {
                        if isTOTP || isComplexPassword {
                            isMasked = true
                        }
                    } else if copiedText.count >= 8 && hasSpecialPasswordSymbol && hasDigit && hasLetter {
                        isMasked = true
                    }
                }
            }
        } else {
            sizeStr = "Unknown"
        }
        
        return (text: text, app: frontApp, folder: folder, size: sizeStr, isMasked: isMasked)
    }
    
    internal func startHardwareKeyPolling() {
        hardwareKeyPollingTimer?.invalidate()
        hardwareKeyPollingTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, self.enableClipboard, self.isTrusted else { return }
            
            // Cmd (lewy lub prawy)
            let cmdPressed = CGEventSource.keyState(.hidSystemState, key: 55) || CGEventSource.keyState(.hidSystemState, key: 54)
            if !cmdPressed { return }
            
            if CGEventSource.keyState(.hidSystemState, key: 7) { // X
                self.detectedHardwareAction = "cut"
                self.detectedHardwareActionTimestamp = Date()
            } else if CGEventSource.keyState(.hidSystemState, key: 8) { // C
                self.detectedHardwareAction = "copy"
                self.detectedHardwareActionTimestamp = Date()
            } else if CGEventSource.keyState(.hidSystemState, key: 9) { // V
                if self.clipboardCyclePasteEnabled || self.isClipboardCycling {
                    return
                }
                self.detectedHardwareAction = "paste"
                self.detectedHardwareActionTimestamp = Date()
                
                let types = NSPasteboard.general.types ?? []
                let isFile = types.contains(.fileURL) || 
                             types.contains(NSPasteboard.PasteboardType("public.file-url")) || 
                             types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
                
                let hasCustomPaste = !(self.pasteShortcut.character == "v" && self.pasteShortcut.modifiers == .command)
                
                if !isFile && hasCustomPaste { return }
                
                if let last = self.lastPasteTrigger, Date().timeIntervalSince(last) < 1.0 { return }
                if !self.canPasteInFrontmostApp() { return }
                
                self.lastPasteTrigger = Date()
                DispatchQueue.main.async {
                    let data = self.processClipboardData(for: "paste")
                    self.triggerClipboardIndicator(text: data.text, action: "paste", app: data.app, folder: data.folder, size: data.size, isMasked: data.isMasked)
                }
            }
        }
    }
    
    internal func canPasteInFrontmostApp() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return true }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var menuBar: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) != .success { return true }
        guard let menuBarRef = menuBar, CFGetTypeID(menuBarRef) == AXUIElementGetTypeID() else { return true }
        let menuBarElement = menuBarRef as! AXUIElement
        
        var menus: CFTypeRef?
        if AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &menus) != .success { return true }
        guard let menuItems = menus as? [AXUIElement] else { return true }
        
        for item in menuItems {
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title) != .success { continue }
            if let titleStr = title as? String, (titleStr == "Edit" || titleStr == "Edycja") {
                var children: CFTypeRef?
                if AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &children) != .success { continue }
                guard let editMenuArr = children as? [AXUIElement], let editMenu = editMenuArr.first else { continue }
                
                var editItems: CFTypeRef?
                if AXUIElementCopyAttributeValue(editMenu, kAXChildrenAttribute as CFString, &editItems) != .success { continue }
                guard let items = editItems as? [AXUIElement] else { continue }
                
                var foundPasteOption = false
                var anyPasteEnabled = false
                
                for subItem in items {
                    var subTitle: CFTypeRef?
                    if AXUIElementCopyAttributeValue(subItem, kAXTitleAttribute as CFString, &subTitle) != .success { continue }
                    if let subStr = subTitle as? String, (subStr.contains("Paste") || subStr.contains("Wklej")) {
                        foundPasteOption = true
                        var enabled: CFTypeRef?
                        if AXUIElementCopyAttributeValue(subItem, kAXEnabledAttribute as CFString, &enabled) == .success {
                            if let isEnabled = enabled as? Bool, isEnabled {
                                anyPasteEnabled = true
                                break
                            }
                        } else {
                            anyPasteEnabled = true // Fallback
                            break
                        }
                    }
                }
                
                if foundPasteOption {
                    return anyPasteEnabled
                } else {
                    return false
                }
            }
        }
        return true // Fallback
    }
}
