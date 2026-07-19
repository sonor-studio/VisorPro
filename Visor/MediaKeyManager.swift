import Cocoa
import ApplicationServices
import SwiftUI
import Combine
import IOBluetooth

struct Shortcut {
    let character: String
    let modifiers: NSEvent.ModifierFlags
}

class MediaKeyManager: ObservableObject {
    @Published var lastAction: String = "Oczekuję na akcje..."
    @Published var isTrusted: Bool = false
    @Published var useSystemOSD: Bool = false // Przełącznik do wyłączania przechwytywania
    @Published var targetBatteryPercentage: String = UserDefaults.standard.string(forKey: "targetBatteryPercentage") ?? "80" {
        didSet {
            UserDefaults.standard.set(targetBatteryPercentage, forKey: "targetBatteryPercentage")
        }
    }
    @Published var notifyOnPlug: Bool = UserDefaults.standard.object(forKey: "notifyOnPlug") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnPlug, forKey: "notifyOnPlug") }
    }
    @Published var notifyOn10Percent: Bool = UserDefaults.standard.object(forKey: "notifyOn10Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOn10Percent, forKey: "notifyOn10Percent") }
    }
    @Published var notifyOn20Percent: Bool = UserDefaults.standard.object(forKey: "notifyOn20Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOn20Percent, forKey: "notifyOn20Percent") }
    }
    @Published var notifyOn100Percent: Bool = UserDefaults.standard.object(forKey: "notifyOn100Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOn100Percent, forKey: "notifyOn100Percent") }
    }
    
    @Published var notifyOnCopy: Bool = UserDefaults.standard.object(forKey: "notifyOnCopy") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCopy, forKey: "notifyOnCopy") }
    }
    @Published var notifyOnCut: Bool = UserDefaults.standard.object(forKey: "notifyOnCut") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCut, forKey: "notifyOnCut") }
    }
    @Published var notifyOnPaste: Bool = UserDefaults.standard.object(forKey: "notifyOnPaste") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnPaste, forKey: "notifyOnPaste") }
    }
    
    @Published var notifyOnCapsLock: Bool = UserDefaults.standard.object(forKey: "notifyOnCapsLock") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCapsLock, forKey: "notifyOnCapsLock") }
    }

    @Published var currentBatteryPercentage: Int = 15 {
        didSet {
            if !isPluggedIn && oldValue != currentBatteryPercentage {
                if currentBatteryPercentage == 20 && notifyOn20Percent {
                    triggerLowBatteryWarning()
                } else if currentBatteryPercentage == 10 && notifyOn10Percent {
                    triggerLowBatteryWarning()
                }
            }
            
            if isPluggedIn && currentBatteryPercentage == 100 && oldValue != currentBatteryPercentage {
                if notifyOn100Percent {
                    triggerChargingStatus()
                }
            }
        }
    }
    
    @Published var isPluggedIn: Bool = true {
        didSet {
            if isPluggedIn {
                withAnimation(.easeInOut(duration: 0.25)) { showLowBatteryWarning = false }
                if oldValue != isPluggedIn && notifyOnPlug {
                    triggerChargingStatus()
                }
            } else {
                if currentBatteryPercentage == 20 && notifyOn20Percent {
                    triggerLowBatteryWarning()
                } else if currentBatteryPercentage == 10 && notifyOn10Percent {
                    triggerLowBatteryWarning()
                }
            }
        }
    }
    
    @Published var isSimulated: Bool = true
    @Published var showLowBatteryWarning: Bool = false
    @Published var showChargingStatus: Bool = false
    
    @Published var currentVolume: Int = 50
    @Published var isMuted: Bool = false
    @Published var showVolumeIndicator: Bool = false
    @Published var currentAudioDeviceName: String = "Volume"
    private var volumeTimer: Timer?
    
    @Published var currentBrightness: Int = 50
    @Published var showBrightnessIndicator: Bool = false
    private var brightnessTimer: Timer?
    
    private var chargingTimer: Timer?
    
    @Published var showCopyIndicator: Bool = false
    @Published var copiedText: String = ""
    @Published var clipboardAction: String = "copy" // "copy", "cut", "paste"
    @Published var clipboardEventId: UUID = UUID()
    var pendingClipboardAction: String?
    private var copyTimer: Timer?
    private var pasteboardObserver: PasteboardObserver?
    
    @Published var showCapsLockIndicator: Bool = false
    @Published var isCapsLockOn: Bool = false
    @Published var capsLockEventId: UUID = UUID()
    private var capsLockTimer: Timer?
    
    // Bluetooth
    @Published var notifyOnBluetooth: Bool = UserDefaults.standard.object(forKey: "notifyOnBluetooth") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnBluetooth, forKey: "notifyOnBluetooth") }
    }
    @Published var showBluetoothIndicator: Bool = false
    @Published var bluetoothIsConnected: Bool = false
    @Published var bluetoothDeviceName: String = ""
    @Published var bluetoothEventId: UUID = UUID()
    private var bluetoothTimer: Timer?
    private var bluetoothObserver: VisorBluetoothObserver?
    private var lastBluetoothEventTime: Date = Date.distantPast
    
    private func dismissCollidingIndicators(newPosition: String, source: String) {
        let volPos = UserDefaults.standard.string(forKey: "volumeOverlayPosition") ?? "top"
        let brightPos = UserDefaults.standard.string(forKey: "brightnessOverlayPosition") ?? "top"
        let battPos = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
        let copyPos = UserDefaults.standard.string(forKey: "copyOverlayPosition") ?? "bottom"
        let capsPos = UserDefaults.standard.string(forKey: "capsLockOverlayPosition") ?? "bottom"
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        
        if source != "volume" && volPos == newPosition && showVolumeIndicator {
            withAnimation(nil) { showVolumeIndicator = false }
        }
        if source != "brightness" && brightPos == newPosition && showBrightnessIndicator {
            withAnimation(nil) { showBrightnessIndicator = false }
        }
        if source != "battery" && battPos == newPosition && (showChargingStatus || showLowBatteryWarning) {
            withAnimation(nil) { 
                showChargingStatus = false
                showLowBatteryWarning = false
            }
        }
        if source != "copy" && copyPos == newPosition && showCopyIndicator {
            withAnimation(nil) { showCopyIndicator = false }
        }
        if source != "capsLock" && capsPos == newPosition && showCapsLockIndicator {
            withAnimation(nil) { showCapsLockIndicator = false }
        }
        if source != "bluetooth" && btPos == newPosition && showBluetoothIndicator {
            withAnimation(nil) { showBluetoothIndicator = false }
        }
    }
    
    private var batteryTimer: Timer?
    
    func triggerLowBatteryWarning() {
        let battPos = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        withAnimation(.easeInOut(duration: 0.25)) { showLowBatteryWarning = true }
    }
    
    func triggerChargingStatus() {
        chargingTimer?.invalidate()
        let battPos = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        // Wymuś odświeżenie UI poprzez krótkie zrzucenie stanu, jeśli był już aktywny
        if showChargingStatus {
            showChargingStatus = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showChargingStatus = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                showChargingStatus = true
            }
        }
        
        chargingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showChargingStatus = false
            }
        }
    }
    
    func triggerVolumeIndicator() {
        // Pomijaj powiadomienie o głośności jeśli przed chwilą było zdarzenie Bluetooth (np. podłączono słuchawki)
        if Date().timeIntervalSince(lastBluetoothEventTime) < 2.0 { return }
        
        volumeTimer?.invalidate()
        let volPos = UserDefaults.standard.string(forKey: "volumeOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: volPos, source: "volume")
        
        withAnimation(.easeInOut(duration: 0.25)) {
            showVolumeIndicator = true
        }
        
        volumeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showVolumeIndicator = false
            }
        }
    }
    
    func triggerBrightnessIndicator() {
        brightnessTimer?.invalidate()
        let brightPos = UserDefaults.standard.string(forKey: "brightnessOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: brightPos, source: "brightness")
        
        withAnimation(.easeInOut(duration: 0.25)) {
            showBrightnessIndicator = true
        }
        
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showBrightnessIndicator = false
            }
        }
    }
    
    func triggerClipboardIndicator(text: String, action: String = "copy") {
        if action == "copy" && !notifyOnCopy { return }
        if action == "cut" && !notifyOnCut { return }
        if action == "paste" && !notifyOnPaste { return }
        
        copyTimer?.invalidate()
        let copyPos = UserDefaults.standard.string(forKey: "copyOverlayPosition") ?? "bottom"
        dismissCollidingIndicators(newPosition: copyPos, source: "copy")
        
        self.copiedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clipboardAction = action
        self.clipboardEventId = UUID()
        
        if showCopyIndicator {
            showCopyIndicator = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showCopyIndicator = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCopyIndicator = true
            }
        }
        
        copyTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showCopyIndicator = false
            }
        }
    }
    
    func triggerCapsLockIndicator(isOn: Bool) {
        if !notifyOnCapsLock { return }
        
        capsLockTimer?.invalidate()
        let pos = UserDefaults.standard.string(forKey: "capsLockOverlayPosition") ?? "bottom"
        dismissCollidingIndicators(newPosition: pos, source: "capsLock")
        
        self.isCapsLockOn = isOn
        self.capsLockEventId = UUID()
        
        if showCapsLockIndicator {
            showCapsLockIndicator = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showCapsLockIndicator = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCapsLockIndicator = true
            }
        }
        
        capsLockTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showCapsLockIndicator = false
            }
        }
    }
    
    func triggerBluetoothIndicator(deviceName: String, isConnected: Bool) {
        if !notifyOnBluetooth { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bluetoothTimer?.invalidate()
            let pos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
            self.dismissCollidingIndicators(newPosition: pos, source: "bluetooth")
            
            self.bluetoothDeviceName = deviceName
            self.bluetoothIsConnected = isConnected
            self.bluetoothEventId = UUID()
            self.lastBluetoothEventTime = Date()
            
            if self.showBluetoothIndicator {
                self.showBluetoothIndicator = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.showBluetoothIndicator = true
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showBluetoothIndicator = true
                }
            }
            
            self.bluetoothTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showBluetoothIndicator = false
                }
            }
        }
    }
    
    func updateBatteryState(percentage: Int, pluggedIn: Bool) {
        guard !isSimulated else { return }
        self.currentBatteryPercentage = percentage
        self.isPluggedIn = pluggedIn
    }
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var audioRouteObserver: AudioRouteObserver?
    private var batteryObserver: BatteryObserver?
    private var wifiObserver: WiFiObserver?
    
    var copyShortcut: Shortcut = Shortcut(character: "c", modifiers: .command)
    var pasteShortcut: Shortcut = Shortcut(character: "v", modifiers: .command)
    var cutShortcut: Shortcut = Shortcut(character: "x", modifiers: .command)
    
    init() {
        checkAccessibility()
        loadShortcuts()
        self.bluetoothObserver = VisorBluetoothObserver(manager: self)
        self.audioRouteObserver = AudioRouteObserver(manager: self)
        self.batteryObserver = BatteryObserver(manager: self)
        self.wifiObserver = WiFiObserver(manager: self)
        self.pasteboardObserver = PasteboardObserver(manager: self)
        
        VolumeManager.shared.fetchCurrentVolume { [weak self] vol, muted in
            self?.currentVolume = vol
            self?.isMuted = muted
            self?.currentAudioDeviceName = VolumeManager.shared.getCurrentAudioDeviceName()
        }
        
        BrightnessManager.shared.fetchCurrentBrightness { [weak self] brightness in
            self?.currentBrightness = brightness
        }
        
        self.bluetoothObserver?.startObserving()
    }
    
    private func loadShortcuts() {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let keys = global?["NSUserKeyEquivalents"] as? [String: String] ?? [:]
        
        self.copyShortcut = parseShortcut(keys["Copy"] ?? "@c")
        self.pasteShortcut = parseShortcut(keys["Paste"] ?? "@v")
        self.cutShortcut = parseShortcut(keys["Cut"] ?? "@x")
    }
    
    private func parseShortcut(_ string: String) -> Shortcut {
        var modifiers: NSEvent.ModifierFlags = []
        var character = ""
        
        for char in string {
            switch char {
            case "@": modifiers.insert(.command)
            case "^": modifiers.insert(.control)
            case "~": modifiers.insert(.option)
            case "$": modifiers.insert(.shift)
            default: character = String(char).lowercased()
            }
        }
        return Shortcut(character: character, modifiers: modifiers)
    }
    
    func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        self.isTrusted = AXIsProcessTrustedWithOptions(options)
    }
    
    func start() {
        if !self.isTrusted {
            checkAccessibility()
            if !self.isTrusted {
                print("Brak uprawnień Dostępności!")
                return
            }
        }
        
        let eventMask = (1 << CGEventType(rawValue: UInt32(NX_SYSDEFINED))!.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue)
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            let manager = Unmanaged<MediaKeyManager>.fromOpaque(refcon!).takeUnretainedValue()
            
            if type == .flagsChanged {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 57 { // 57 to kVK_CapsLock
                    let isCapsOn = event.flags.contains(.maskAlphaShift)
                    DispatchQueue.main.async {
                        if !manager.useSystemOSD {
                            manager.lastAction = "Caps Lock: \(isCapsOn ? "Wł." : "Wył.")"
                        }
                        manager.triggerCapsLockIndicator(isOn: isCapsOn)
                    }
                }
                return Unmanaged.passRetained(event)
            }
            
            if type == .keyDown {
                if !manager.useSystemOSD {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    
                    let hasCommand = flags.contains(.maskCommand)
                    
                    if hasCommand {
                        if keyCode == 8 { // 'c'
                            manager.pendingClipboardAction = "copy"
                            DispatchQueue.main.async { manager.lastAction = "Skopiowano tekst" }
                        } else if keyCode == 9 { // 'v'
                            DispatchQueue.main.async {
                                manager.lastAction = "Wklejono tekst"
                                let text = NSPasteboard.general.string(forType: .string) ?? "Wklejony plik"
                                manager.triggerClipboardIndicator(text: text, action: "paste")
                            }
                        } else if keyCode == 7 { // 'x'
                            manager.pendingClipboardAction = "cut"
                            DispatchQueue.main.async { manager.lastAction = "Wycięto tekst" }
                        }
                    }
                }
                return Unmanaged.passRetained(event)
            }
            
            guard type == CGEventType(rawValue: UInt32(NX_SYSDEFINED))! else { return Unmanaged.passRetained(event) }
            
            if manager.useSystemOSD {
                return Unmanaged.passRetained(event)
            }
            guard type == CGEventType(rawValue: UInt32(NX_SYSDEFINED))! else { return Unmanaged.passRetained(event) }
            guard let nsEvent = NSEvent(cgEvent: event), nsEvent.type == .systemDefined else { return Unmanaged.passRetained(event) }
            if nsEvent.subtype.rawValue == 8 { // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                let data1 = nsEvent.data1
                let keyCode = (data1 & 0xFFFF0000) >> 16
                let keyFlags = data1 & 0x0000FFFF
                let keyState = (keyFlags & 0xFF00) >> 8
                let isKeyDown = (keyState == 0x0A)
                
                let NX_KEYTYPE_SOUND_UP = 0
                let NX_KEYTYPE_SOUND_DOWN = 1
                let NX_KEYTYPE_BRIGHTNESS_UP = 2
                let NX_KEYTYPE_BRIGHTNESS_DOWN = 3
                let NX_KEYTYPE_MUTE = 7
                
                if keyCode == NX_KEYTYPE_SOUND_UP || keyCode == NX_KEYTYPE_SOUND_DOWN || keyCode == NX_KEYTYPE_MUTE || keyCode == NX_KEYTYPE_BRIGHTNESS_UP || keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN {
                    if isKeyDown {
                        DispatchQueue.main.async {
                            if keyCode == NX_KEYTYPE_SOUND_UP {
                                manager.lastAction = "Zwiększanie głośności"
                                VolumeManager.shared.increaseVolume { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.currentAudioDeviceName = VolumeManager.shared.getCurrentAudioDeviceName()
                                    manager.triggerVolumeIndicator()
                                }
                            } else if keyCode == NX_KEYTYPE_SOUND_DOWN {
                                manager.lastAction = "Zmniejszanie głośności"
                                VolumeManager.shared.decreaseVolume { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.currentAudioDeviceName = VolumeManager.shared.getCurrentAudioDeviceName()
                                    manager.triggerVolumeIndicator()
                                }
                            } else if keyCode == NX_KEYTYPE_MUTE {
                                VolumeManager.shared.toggleMute { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.currentAudioDeviceName = VolumeManager.shared.getCurrentAudioDeviceName()
                                    manager.lastAction = muted ? "Wyciszono dźwięk" : "Włączono dźwięk"
                                    manager.triggerVolumeIndicator()
                                }
                            } else if keyCode == NX_KEYTYPE_BRIGHTNESS_UP {
                                manager.lastAction = "Zwiększanie jasności"
                                BrightnessManager.shared.increaseBrightness { newBright in
                                    manager.currentBrightness = newBright
                                    manager.triggerBrightnessIndicator()
                                }
                            } else if keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN {
                                manager.lastAction = "Zmniejszanie jasności"
                                BrightnessManager.shared.decreaseBrightness { newBright in
                                    manager.currentBrightness = newBright
                                    manager.triggerBrightnessIndicator()
                                }
                            }
                        }
                    }
                    // Zwrócenie nil blokuje zdarzenie – systemowy OSD nie pokaże się, a system sam nie zmieni głośności.
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPtr
        )
        
        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                print("Event tap aktywny – nasłuchuję głośności.")
            }
        } else {
            print("Nie udało się utworzyć Event Tap. Upewnij się, że 'App Sandbox' w Xcode jest wyłączony oraz masz uprawnienia Dostępności.")
        }
    }
}

class PasteboardObserver {
    private weak var manager: MediaKeyManager?
    private var timer: Timer?
    private var lastChangeCount: Int
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        self.lastChangeCount = NSPasteboard.general.changeCount
        startObserving()
    }
    
    func startObserving() {
        // Obserwujemy pasteboard co 0.1 sekundy dla natychmiastowej reakcji
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    private func checkPasteboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            let action = manager?.pendingClipboardAction ?? "copy"
            manager?.pendingClipboardAction = nil
            
            // Sprawdzamy czy w schowku jest tekst
            if let copiedText = NSPasteboard.general.string(forType: .string) {
                DispatchQueue.main.async {
                    self.manager?.triggerClipboardIndicator(text: copiedText, action: action)
                }
            } else {
                // Skopiowano coś innego, np. plik lub obrazek
                DispatchQueue.main.async {
                    self.manager?.triggerClipboardIndicator(text: "Plik / Obraz", action: action)
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

class VisorBluetoothObserver: NSObject {
    weak var manager: MediaKeyManager?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        super.init()
    }
    
    func startObserving() {
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        
        // Zarejestruj rozłączenia dla już połączonych urządzeń przy starcie aplikacji
        if let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in pairedDevices {
                if device.isConnected() {
                    device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
                }
            }
        }
    }
    
    @objc func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let deviceName = device.name ?? "Unknown Device"
        manager?.triggerBluetoothIndicator(deviceName: deviceName, isConnected: true)
        
        // Obserwowanie rozłączenia tylko dla połączonych urządzeń
        device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
    }
    
    @objc func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let deviceName = device.name ?? "Unknown Device"
        manager?.triggerBluetoothIndicator(deviceName: deviceName, isConnected: false)
    }
}
