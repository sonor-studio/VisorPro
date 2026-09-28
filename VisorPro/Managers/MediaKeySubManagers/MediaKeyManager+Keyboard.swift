import Foundation
import AppKit
import Carbon
import SwiftUI

extension MediaKeyManager {
    func getAvailableLanguages() -> [KeyboardLayout] {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource],
              let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return []
        }
        
        var currentId = ""
        if let currentIdPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID),
           let idStr = Unmanaged<AnyObject>.fromOpaque(currentIdPtr).takeUnretainedValue() as? String {
            currentId = idStr
        }
        
        var layouts: [KeyboardLayout] = []
        for source in sourceList {
            guard let catPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = Unmanaged<AnyObject>.fromOpaque(catPtr).takeUnretainedValue() as? String else { continue }
            
            if category == (kTISCategoryKeyboardInputSource as String) {
                if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                   let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                   let id = Unmanaged<AnyObject>.fromOpaque(idPtr).takeUnretainedValue() as? String,
                   let name = Unmanaged<AnyObject>.fromOpaque(namePtr).takeUnretainedValue() as? String {
                    layouts.append(KeyboardLayout(id: id, name: name, isSelected: (id == currentId)))
                }
            }
        }
        return layouts
    }

    func selectLanguage(idToSelect: String) {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return }
        for source in sourceList {
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
               let id = Unmanaged<AnyObject>.fromOpaque(idPtr).takeUnretainedValue() as? String {
                if id == idToSelect {
                    if let oldId = OverlayStateRelay.shared.currentKeyboardLayoutId, oldId != idToSelect {
                        OverlayStateRelay.shared.previousKeyboardLayoutId = oldId
                    }
                    OverlayStateRelay.shared.currentKeyboardLayoutId = idToSelect
                    
                    if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                       let name = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? String {
                        OverlayStateRelay.shared.currentKeyboardLanguage = name
                    }
                    
                    isSwitchingLanguageInternally = true
                    TISSelectInputSource(source)
                    
                    // Keep the overlay alive when changing language via the button
                    self.keepAlive(for: "language", isHovering: false)
                    OverlayStateRelay.shared.languageEventId = UUID()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isSwitchingLanguageInternally = false
                    }
                    return
                }
            }
        }
    }

    func getCurrentCapsLockState() -> Bool {
        var connect: io_connect_t = 0
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        if service == 0 { return false }
        IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
        var state: Bool = false
        IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
        IOServiceClose(connect)
        IOObjectRelease(service)
        return state
    }

    func toggleCapsLock(isCatchup: Bool = false) {
        var connect: io_connect_t = 0
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        if service != 0 {
            IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
            var state: Bool = false
            IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
            let newState = !state
            IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), newState)
            IOServiceClose(connect)
            IOObjectRelease(service)
            
            self.isCapsLockOn = newState
            
            let src = CGEventSource(stateID: .hidSystemState)
            
            var currentFlags = CGEventSource.flagsState(.hidSystemState)
            if newState {
                currentFlags.insert(.maskAlphaShift)
            } else {
                currentFlags.remove(.maskAlphaShift)
            }
            
            let eventDown = CGEvent(keyboardEventSource: src, virtualKey: 57, keyDown: true)
            eventDown?.type = .flagsChanged
            eventDown?.flags = currentFlags
            eventDown?.setIntegerValueField(.eventSourceUserData, value: 12345)
            eventDown?.post(tap: .cghidEventTap)
            
            let eventUp = CGEvent(keyboardEventSource: src, virtualKey: 57, keyDown: false)
            eventUp?.type = .flagsChanged
            eventUp?.flags = currentFlags
            eventUp?.setIntegerValueField(.eventSourceUserData, value: 12345)
            eventUp?.post(tap: .cghidEventTap)
            
            self.triggerCapsLockIndicator(isOn: newState)
        }
    }

    func setupRawCapsLockDetection() {
        guard self.isTrusted else { return }
        if rawHIDManager != nil { return } // Prevent double registration
        
        rawHIDManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = rawHIDManager else { return }
        
        let deviceMatch: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x01, // Generic Desktop
            kIOHIDDeviceUsageKey: 0x06      // Keyboard
        ]
        
        IOHIDManagerSetDeviceMatching(manager, deviceMatch as CFDictionary)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        // Protection against sleeping/disconnecting keyboards (hot-plug)
        let matchCallback: IOHIDDeviceCallback = { context, result, sender, device in
        }
        let removeCallback: IOHIDDeviceCallback = { context, result, sender, device in
        }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, matchCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, removeCallback, context)
        
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            guard let context = context else { return }
            let selfObj = Unmanaged<MediaKeyManager>.fromOpaque(context).takeUnretainedValue()
            
            let element = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let intValue = IOHIDValueGetIntegerValue(value)
            
            // 0x07 = Keyboard/Keypad, 0x39 = Caps Lock
            if usagePage == 0x07 {
                if usage == 0x39 {
                    if intValue == 1 {
                        DispatchQueue.main.async {
                            selfObj.handleRawCapsLockPress()
                        }
                    }
                }
            }
        }, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess {
        } else {
        }
        
        // Inicjalna synchronizacja stanu
        self.isCapsLockOn = self.getCurrentCapsLockState()
    }

    func handleRawCapsLockPress() {
        if !self.enableKeyboard { return }
        
        // Increased delay from 0.05s to 0.15s to give Bluetooth keyboards time to light up the LED
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let actualHardwareState = self.getCurrentCapsLockState()
            
            guard actualHardwareState != self.isCapsLockOn else { return }
            
            if !self.useSystemOSD {
                self.lastAction = "Caps Lock: \(actualHardwareState ? "On" : "Off")"
            }
            
            self.triggerCapsLockIndicator(isOn: actualHardwareState)
        }
    }

}
