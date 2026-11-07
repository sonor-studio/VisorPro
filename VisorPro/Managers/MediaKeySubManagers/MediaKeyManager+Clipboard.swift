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
        self.isSimulatingPaste = true
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
            keyDown.setIntegerValueField(.eventSourceUserData, value: 0x56505354)
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = flags
            keyUp.setIntegerValueField(.eventSourceUserData, value: 0x56505354)
            keyUp.post(tap: .cgAnnotatedSessionEventTap)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isSimulatingPaste = false
        }
    }

    // MARK: - Cycle Paste History
    
    func startClipboardCycling(shortcutModifiers: NSEvent.ModifierFlags, cycleChar: String) -> Bool {
        guard enableClipboard else { return false }
        
        var items = self.clipboardHistory
        
        // Ensure the current pasteboard item is present at the front if not empty
        let currentData = self.processClipboardData(for: "paste")
        if !currentData.text.isEmpty {
            if let first = items.first {
                if first.text != currentData.text {
                    let fresh = ClipboardItem(text: currentData.text, app: currentData.app, folder: currentData.folder, size: currentData.size, timestamp: Date(), isMasked: currentData.isMasked)
                    items.insert(fresh, at: 0)
                    self.clipboardHistory = items
                }
            } else {
                let fresh = ClipboardItem(text: currentData.text, app: currentData.app, folder: currentData.folder, size: currentData.size, timestamp: Date(), isMasked: currentData.isMasked)
                items.append(fresh)
                self.clipboardHistory = items
            }
        }
        
        guard !items.isEmpty else { return false }
        
        self.clipboardCycleItems = items
        self.clipboardCycleIndex = 0
        self.clipboardCycleTotal = items.count
        self.isClipboardCycling = true
        self.activeCycleModifier = shortcutModifiers
        self.activeCycleChar = cycleChar
        
        let item = items[0]
        
        copyTimer?.invalidate()
        pendingClipboardShowTask?.cancel()
        cancelOverlayHide(for: "copy")
        
        let copyPos = self.getOverlayPosition(for: "copyOverlayPosition")
        dismissCollidingIndicators(newPosition: copyPos, source: "copy")
        
        self.copiedText = item.text
        self.clipboardAction = "cyclePaste"
        self.clipboardSourceApp = item.app
        self.clipboardSourceFolder = item.folder
        self.clipboardMetadataSize = item.size
        self.isClipboardMasked = item.isMasked ?? false
        self.clipboardEventId = UUID()
        
        withAnimation(.easeInOut(duration: 0.15)) {
            self.showCopyIndicator = true
            self.notifyOverlayStateChanged()
            self.overlayTriggerTimes["copy"] = Date()
        }
        
        return true
    }

    func cycleToNextClipboardItem(backwards: Bool = false) {
        guard isClipboardCycling, !clipboardCycleItems.isEmpty else { return }
        
        let newIndex: Int
        if backwards {
            newIndex = (clipboardCycleIndex - 1 + clipboardCycleItems.count) % clipboardCycleItems.count
        } else {
            newIndex = (clipboardCycleIndex + 1) % clipboardCycleItems.count
        }
        
        let item = clipboardCycleItems[newIndex]
        cancelOverlayHide(for: "copy")
        
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.clipboardCycleIndex = newIndex
            self.copiedText = item.text
            self.clipboardSourceApp = item.app
            self.clipboardSourceFolder = item.folder
            self.clipboardMetadataSize = item.size
            self.isClipboardMasked = item.isMasked ?? false
            self.clipboardEventId = UUID()
        }
    }

    func finishClipboardCycling() {
        guard isClipboardCycling else { return }
        isClipboardCycling = false
        
        guard !clipboardCycleItems.isEmpty, clipboardCycleIndex < clipboardCycleItems.count else {
            cancelClipboardCycling()
            return
        }
        
        let selectedItem = clipboardCycleItems[clipboardCycleIndex]
        clipboardCycleItems = []
        
        withAnimation(.easeInOut(duration: 0.15)) {
            self.clipboardAction = "paste"
            self.copiedText = selectedItem.text
            self.clipboardSourceApp = selectedItem.app
            self.clipboardSourceFolder = selectedItem.folder
            self.clipboardMetadataSize = selectedItem.size
            self.isClipboardMasked = selectedItem.isMasked ?? false
            self.clipboardEventId = UUID()
            self.showCopyIndicator = true
        }
        
        if notifyOnPaste {
            playNotificationSound(named: soundOnPaste)
        }
        scheduleOverlayHide(for: "copy")
        
        let pasteboard = NSPasteboard.general
        self.isProgrammaticPasteboardChange = true
        self.pendingClipboardAction = "ignore"
        self.pendingClipboardActionTimestamp = Date()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProgrammaticPasteboardChange = false
        }
        
        pasteboard.clearContents()
        if let folder = selectedItem.folder {
            let fileURL = URL(fileURLWithPath: folder).appendingPathComponent(selectedItem.text)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                pasteboard.writeObjects([fileURL as NSURL])
            } else {
                pasteboard.setString(selectedItem.text, forType: .string)
            }
        } else {
            pasteboard.setString(selectedItem.text, forType: .string)
        }
        
        if let idx = self.clipboardHistory.firstIndex(where: { $0.id == selectedItem.id }) {
            var updatedItem = selectedItem
            updatedItem.timestamp = Date()
            self.clipboardHistory.remove(at: idx)
            self.clipboardHistory.insert(updatedItem, at: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.simulatePaste(isFile: selectedItem.folder != nil)
        }
    }

    func cancelClipboardCycling() {
        guard isClipboardCycling else { return }
        isClipboardCycling = false
        clipboardCycleItems = []
        withAnimation(.easeInOut(duration: 0.15)) {
            self.showCopyIndicator = false
            self.notifyOverlayStateChanged()
        }
        cancelOverlayHide(for: "copy")
    }

}
