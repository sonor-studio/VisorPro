import Foundation
import AppKit
import SwiftUI

extension MediaKeyManager {
    func triggerFileDeletedOverlay() {
        if !showTrashModule { return }
        if !notifyOnFileDeleted { return }
        
        let pos = self.getOverlayPosition(for: "fileDeletedOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "fileDeleted")
        playNotificationSound(named: self.soundOnFileDeleted)
        
        withAnimation(.easeInOut(duration: 0.15)) {
            self.showFileDeletedIndicator = true
            self.notifyOverlayStateChanged()
            self.overlayTriggerTimes["fileDeleted"] = Date()
        }
        
        OverlayStateRelay.shared.fileDeletedEventId = UUID()
        scheduleOverlayHide(for: "fileDeleted")
    }

    func cleanupClipboardHistory() {
        let retention = UserDefaults.standard.string(forKey: "clipboardHistoryRetention") ?? "24h"
        
        var modified = false
        if retention == "24h" {
            let threshold = Date().addingTimeInterval(-24 * 60 * 60)
            let startCount = self.clipboardHistory.count
            self.clipboardHistory.removeAll(where: { $0.timestamp < threshold })
            if self.clipboardHistory.count != startCount { modified = true }
        } else if retention == "7d" {
            let threshold = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let startCount = self.clipboardHistory.count
            self.clipboardHistory.removeAll(where: { $0.timestamp < threshold })
            if self.clipboardHistory.count != startCount { modified = true }
        }
        
        let limit = self.clipboardHistoryLimit > 0 ? self.clipboardHistoryLimit : 30
        if self.clipboardHistory.count > limit {
            self.clipboardHistory.removeLast(self.clipboardHistory.count - limit)
            modified = true
        }
        
        if modified {
            let current = self.clipboardHistory
            self.clipboardHistory = current
        }
    }

    func copyHistoryItemToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        self.isProgrammaticPasteboardChange = true
        self.pendingClipboardAction = "paste"
        self.pendingClipboardActionTimestamp = Date()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProgrammaticPasteboardChange = false
        }
        pasteboard.clearContents()
        
        if let folder = item.folder {
            let fileURL = URL(fileURLWithPath: folder).appendingPathComponent(item.text)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                pasteboard.writeObjects([fileURL as NSURL])
            } else {
                pasteboard.setString(item.text, forType: .string)
            }
        } else {
            pasteboard.setString(item.text, forType: .string)
        }
        
        DispatchQueue.main.async {
            if let idx = self.clipboardHistory.firstIndex(where: { $0.id == item.id }) {
                var updatedItem = item
                updatedItem.timestamp = Date()
                self.clipboardHistory.remove(at: idx)
                self.clipboardHistory.insert(updatedItem, at: 0)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.simulatePaste(isFile: item.folder != nil)
        }
    }

    func simulatePaste(isFile: Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode: CGKeyCode
        let flags: CGEventFlags
        
        if isFile {
            keyCode = 9 // 'v'
            flags = .maskCommand
        } else {
            keyCode = self.keyCode(for: self.pasteShortcut.character)
            flags = self.cgFlags(from: self.pasteShortcut.modifiers)
        }
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = flags
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = flags
            keyUp.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

}
