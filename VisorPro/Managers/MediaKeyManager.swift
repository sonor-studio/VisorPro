import Cocoa
import ApplicationServices
import SwiftUI
import Combine
import IOBluetooth
import Carbon
import IOKit
import Foundation
import AVFoundation
import CoreGraphics
import IOKit.pwr_mgt
import IOKit.hid
import IOKit.hidsystem
import Carbon.HIToolbox
import CoreWLAN
import SystemConfiguration
import CoreBluetooth
import CoreLocation
import CoreServices











class MediaKeyManager: ObservableObject {
    func getOverlayPosition(for key: String) -> String {
        let mode = UserDefaults.standard.string(forKey: "overlayPositionMode") ?? "custom"
        if mode == "fixed" {
            return UserDefaults.standard.string(forKey: "globalOverlayPosition") ?? "top"
        }
        return UserDefaults.standard.string(forKey: key) ?? "top"
    }

    static let shared = MediaKeyManager()
    static var notificationDuration: TimeInterval {
        let val = UserDefaults.standard.double(forKey: "notificationDuration")
        return val == 0 ? 3.0 : val
    }
    
    @Published var lastAction: String = "Waiting for actions..."
    @Published var isTrusted: Bool = false {
        didSet {
            if oldValue != isTrusted {
                DispatchQueue.main.async {
                    self.setupMediaKeyTap()
                }
            }
        }
    }
    @Published var activeBluetoothNotifications: [DeviceNotification] = []
    @Published var activePeripheralNotifications: [DeviceNotification] = []
    @Published var activeDisplayNotifications: [DeviceNotification] = []
    @Published var swipeOffsets: [String: CGFloat] = [:]
    @Published var activeSwipeIds: Set<String> = []
    private var notificationTimers: [String: Timer] = [:]
    private var overlayHideTimers: [String: Timer] = [:]
    
    var overlayTriggerTimes: [String: Date] = [:]
    
    var lastDisplayConnectionTime: Date? = nil
    
    @AppStorage("maxSimultaneousNotifications") var maxSimultaneousNotifications: Int = 5
    @Published var mediaSkipDuration: Double = {
        let val = UserDefaults.standard.object(forKey: "mediaSkipDuration")
        return (val as? NSNumber)?.doubleValue ?? 10.0
    }() {
        didSet {
            UserDefaults.standard.set(mediaSkipDuration, forKey: "mediaSkipDuration")
        }
    }
    @AppStorage("overlayTheme") var overlayTheme: String = "system"
    @Published var globalHoveredTypes: Set<String> = []
    @Published var actualHoveredTypes: Set<String> = []
    
    @Published var useSystemOSD: Bool = false {
        didSet { setupMediaKeyTap() }
    }
    @AppStorage("soundOnVolume") var soundOnVolume: String = "None"
    @Published var enableVolume: Bool = UserDefaults.standard.object(forKey: "enableVolume") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enableVolume, forKey: "enableVolume")
            setupMediaKeyTap()
            if !enableVolume { withAnimation { self.showVolumeIndicator = false } }
        }
    }
    
    @AppStorage("soundOnBrightness") var soundOnBrightness: String = "None"
    @Published var enableBrightness: Bool = UserDefaults.standard.object(forKey: "enableBrightness") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enableBrightness, forKey: "enableBrightness")
            setupMediaKeyTap()
            if !enableBrightness { withAnimation { self.showBrightnessIndicator = false } }
        }
    }
    
    @AppStorage("soundOnKeyboardBrightness") var soundOnKeyboardBrightness: String = "None"
    @AppStorage("keyboardBrightnessModifier") var keyboardBrightnessModifier: String = "command"
    @Published var enableKeyboardBrightness: Bool = UserDefaults.standard.object(forKey: "enableKeyboardBrightness") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enableKeyboardBrightness, forKey: "enableKeyboardBrightness")
            setupMediaKeyTap()
            if !enableKeyboardBrightness { withAnimation { self.showKeyboardBrightnessIndicator = false } }
        }
    }
    @Published var enableBattery: Bool = UserDefaults.standard.object(forKey: "enableBattery") as? Bool ?? true {
        didSet { 
            UserDefaults.standard.set(enableBattery, forKey: "enableBattery")
            if !enableBattery {
                withAnimation { self.showLowBatteryWarning = false; self.showChargingStatus = false }
                PowerChimeManager.enableChargingSound()
            } else {
                PowerChimeManager.disableChargingSound()
            }
        }
    }
    @Published var enableKeyboard: Bool = UserDefaults.standard.object(forKey: "enableKeyboard") as? Bool ?? true {
        didSet { 
            UserDefaults.standard.set(enableKeyboard, forKey: "enableKeyboard")
            if !enableKeyboard { withAnimation { self.showCopyIndicator = false; self.showCapsLockIndicator = false; self.showLanguageIndicator = false } }
            if !enableBluetooth { withAnimation { self.activeBluetoothNotifications.removeAll() } }
            if !enableWiFi { withAnimation { self.showWiFiIndicator = false } }
        }
    }
    @Published var enableBluetooth: Bool = UserDefaults.standard.object(forKey: "enableBluetooth") as? Bool ?? false {
        didSet { 
            UserDefaults.standard.set(enableBluetooth, forKey: "enableBluetooth")
            if !enableBluetooth { withAnimation { self.activeBluetoothNotifications.removeAll() } }
        }
    }
    @Published var enableWiFi: Bool = UserDefaults.standard.object(forKey: "enableWiFi") as? Bool ?? false {
        didSet { 
            UserDefaults.standard.set(enableWiFi, forKey: "enableWiFi")
            if !enableWiFi { withAnimation { self.showWiFiIndicator = false } }
        }
    }
    
    @Published var targetBatteryPercentage: String = UserDefaults.standard.string(forKey: "targetBatteryPercentage") ?? "80" {
        didSet {
            UserDefaults.standard.set(targetBatteryPercentage, forKey: "targetBatteryPercentage")
        }
    }
    @Published var notifyOnPlug: Bool = UserDefaults.standard.object(forKey: "notifyOnPlug") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnPlug, forKey: "notifyOnPlug") }
    }

    @Published var soundOnPlug: String = UserDefaults.standard.string(forKey: "soundOnPlug") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnPlug, forKey: "soundOnPlug") }
    }
    
    @Published var notifyOnUnplug: Bool = UserDefaults.standard.object(forKey: "notifyOnUnplug") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnUnplug, forKey: "notifyOnUnplug") }
    }

    @Published var soundOnUnplug: String = UserDefaults.standard.string(forKey: "soundOnUnplug") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnUnplug, forKey: "soundOnUnplug") }
    }
    @Published var notifyOn10Percent: Bool = UserDefaults.standard.object(forKey: "notifyOn10Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOn10Percent, forKey: "notifyOn10Percent") }
    }

    @Published var soundOn10Percent: String = UserDefaults.standard.string(forKey: "soundOn10Percent") ?? "None" {
        didSet { UserDefaults.standard.set(soundOn10Percent, forKey: "soundOn10Percent") }
    }
    @Published var notifyOn20Percent: Bool = UserDefaults.standard.object(forKey: "notifyOn20Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOn20Percent, forKey: "notifyOn20Percent") }
    }

    @Published var soundOn20Percent: String = UserDefaults.standard.string(forKey: "soundOn20Percent") ?? "None" {
        didSet { UserDefaults.standard.set(soundOn20Percent, forKey: "soundOn20Percent") }
    }
    @Published var notifyOn100Percent: Bool = UserDefaults.standard.object(forKey: "notifyOn100Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOn100Percent, forKey: "notifyOn100Percent") }
    }

    @Published var soundOn100Percent: String = UserDefaults.standard.string(forKey: "soundOn100Percent") ?? "None" {
        didSet { UserDefaults.standard.set(soundOn100Percent, forKey: "soundOn100Percent") }
    }
    

    
    



    @Published var notifyOnHighRam: Bool = UserDefaults.standard.object(forKey: "notifyOnHighRam") as? Bool ?? false {
        didSet { UserDefaults.standard.set(notifyOnHighRam, forKey: "notifyOnHighRam") }
    }
    
    @Published var highRamThreshold: Double = {
        let val = UserDefaults.standard.object(forKey: "highRamThreshold") as? Double ?? 90.0
        return max(80.0, min(100.0, (round(val / 5.0) * 5.0)))
    }() {
        didSet { 
            UserDefaults.standard.set(highRamThreshold, forKey: "highRamThreshold") 
            RamObserver.shared.resetAlertFlag()
        }
    }

    @Published var soundOnHighRam: String = UserDefaults.standard.string(forKey: "soundOnHighRam") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnHighRam, forKey: "soundOnHighRam") }
    }

    

    
    @Published var notifyOnCopy: Bool = UserDefaults.standard.object(forKey: "notifyOnCopy") as? Bool ?? false {
        didSet { UserDefaults.standard.set(notifyOnCopy, forKey: "notifyOnCopy") }
    }

    @Published var soundOnCopy: String = UserDefaults.standard.string(forKey: "soundOnCopy") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCopy, forKey: "soundOnCopy") }
    }
    @Published var notifyOnCut: Bool = UserDefaults.standard.object(forKey: "notifyOnCut") as? Bool ?? false {
        didSet { UserDefaults.standard.set(notifyOnCut, forKey: "notifyOnCut") }
    }

    @Published var soundOnCut: String = UserDefaults.standard.string(forKey: "soundOnCut") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCut, forKey: "soundOnCut") }
    }
    @Published var notifyOnPaste: Bool = UserDefaults.standard.object(forKey: "notifyOnPaste") as? Bool ?? false {
        didSet { UserDefaults.standard.set(notifyOnPaste, forKey: "notifyOnPaste") }
    }

    @Published var soundOnPaste: String = UserDefaults.standard.string(forKey: "soundOnPaste") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnPaste, forKey: "soundOnPaste") }
    }
    
    @Published var notifyOnCapsLock: Bool = UserDefaults.standard.object(forKey: "notifyOnCapsLock") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCapsLock, forKey: "notifyOnCapsLock") }
    }

    @Published var soundOnCapsLock: String = UserDefaults.standard.string(forKey: "soundOnCapsLock") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCapsLock, forKey: "soundOnCapsLock") }
    }

    @Published var currentBatteryPercentage: Int = 15 {
        didSet {
            if !isBatteryInitialized { return }
            if !isPluggedIn && oldValue > currentBatteryPercentage {
                if currentBatteryPercentage <= 20 && currentBatteryPercentage > 10 && oldValue > 20 && notifyOn20Percent {
                    // Trigger if it crossed the 20% boundary
                    triggerLowBatteryWarning()
                } else if currentBatteryPercentage == 20 && notifyOn20Percent {
                    triggerLowBatteryWarning()
                } else if currentBatteryPercentage <= 10 && oldValue > 10 && notifyOn10Percent {
                    // Trigger if it crossed the 10% boundary
                    triggerLowBatteryWarning()
                } else if currentBatteryPercentage == 10 && notifyOn10Percent {
                    triggerLowBatteryWarning()
                }
            }
            
            if isPluggedIn && oldValue != currentBatteryPercentage {
                let reachedFull = currentBatteryPercentage == 100 || (currentBatteryPercentage == chargeLimit && chargeLimit < 100)
                if reachedFull && notifyOn100Percent {
                    triggerChargingStatus()
                }
            }
        }
    }
    
    @Published var isPluggedIn: Bool = true {
        didSet {
            if !isBatteryInitialized { return }
            if isPluggedIn {
                if oldValue != isPluggedIn && notifyOnPlug {
                    triggerChargingStatus()
                } else {
                    hideBatteryOverlay()
                }
            } else {
                if oldValue != isPluggedIn {
                    if notifyOnUnplug {
                        triggerUnplugStatus()
                    } else {
                        hideBatteryOverlay()
                        if currentBatteryPercentage == 20 && notifyOn20Percent {
                            triggerLowBatteryWarning()
                        } else if currentBatteryPercentage == 10 && notifyOn10Percent {
                            triggerLowBatteryWarning()
                        }
                    }
                } else {
                    hideBatteryOverlay()
                }
            }
        }
    }
    
    @Published var isBatteryInitialized: Bool = false
    
    @Published var isSimulated: Bool = false
    @Published var showLowBatteryWarning: Bool = false
    @Published var showChargingStatus: Bool = false
    @Published var showUnpluggedStatus: Bool = false
    @Published var batteryTimeRemaining: String = "Calculating..."
    @Published var batteryCycleCount: Int = 0
    @Published var batteryHealthPercentage: Int = 100
    @Published var batteryCondition: String = "Normal"
    @Published var batteryPowerDraw: String = "0.0 W"
    @Published var chargeLimit: Int = 100
    @Published var topBatteryConsumers: [(name: String, power: String, icon: NSImage?)] = []
    @Published var isEffectivelyFullyCharged: Bool = false {
        didSet {
            if !isBatteryInitialized { return }
            if isEffectivelyFullyCharged && !oldValue && notifyOn100Percent {
                triggerChargingStatus()
            }
        }
    }
    
    @Published var currentVolume: Int = 50
    @Published var isMuted: Bool = false
    @Published var showVolumeIndicator: Bool = false
    @Published var currentAudioDeviceName: String = "Volume"
    @Published var audioDevicesChanged: UUID = UUID()
    @Published var forceSingleScreenForDisplayTransition: Bool = false
    @Published var isDisplayTransitioning: Bool = false
    private var volumeTimer: Timer?
    
    @Published var currentBrightness: Int = 50
    @Published var showBrightnessIndicator: Bool = false
    private var brightnessTimer: Timer?
    
    @Published var currentKeyboardBrightness: Int = 50
    @Published var showKeyboardBrightnessIndicator: Bool = false
    private var keyboardBrightnessTimer: Timer?
    private var chargingTimer: Timer?
    
    private var hardwareKeyPollingTimer: Timer?
    var detectedHardwareAction: String?
    var detectedHardwareActionTimestamp: Date?
    var lastPasteTrigger: Date?
    
    public var lastChangeCount: Int = 0
    @Published var showCopyIndicator: Bool = false
    
    
    // RAM Monitoring
    


    @Published var showRamIndicator: Bool = false
    @Published var ramEventId = UUID()
    private var hideRamIndicatorTask: DispatchWorkItem?
    @Published var ramUsagePercent: Double = 0.0
    @Published var totalRamGB: Double = 0.0
    @Published var usedRamGB: Double = 0.0
    @Published var ramUsageHistory: [Double] = []
    @Published var ramTopProcesses: [(name: String, ramGB: Double, icon: NSImage?)] = []

    @Published var copiedText: String = ""
    @Published var clipboardAction: String = "copy" // "copy", "cut", "paste"
    @Published var clipboardEventId: UUID = UUID()
    @Published var clipboardSourceApp: String = ""
    @Published var clipboardSourceFolder: String? = nil
    @Published var clipboardMetadataSize: String = ""
    
    var pendingClipboardAction: String?
    var pendingClipboardActionTimestamp: Date?
    private var copyTimer: Timer?
    private var pendingClipboardShowTask: DispatchWorkItem?
    private var pasteboardObserver: PasteboardObserver?
    
    @Published var showCapsLockIndicator: Bool = false
    @Published var isCapsLockOn: Bool = false
    @Published var capsLockEventId: UUID = UUID()
    private var capsLockTimer: Timer?
    
    @Published var notifyOnLanguageChange: Bool = UserDefaults.standard.object(forKey: "notifyOnLanguageChange") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnLanguageChange, forKey: "notifyOnLanguageChange") }
    }

    @Published var soundOnLanguageChange: String = UserDefaults.standard.string(forKey: "soundOnLanguageChange") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnLanguageChange, forKey: "soundOnLanguageChange") }
    }
    @Published var showLanguageIndicator: Bool = false
    @Published var currentKeyboardLanguage: String = ""
    @Published var languageEventId: UUID = UUID()
    private var languageTimer: Timer?
    private var languageChangeWorkItem: DispatchWorkItem?
    public var isSwitchingLanguageInternally: Bool = false
    
    // Bluetooth
    @Published var notifyOnBluetoothConnect: Bool = UserDefaults.standard.object(forKey: "notifyOnBluetoothConnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnBluetoothConnect, forKey: "notifyOnBluetoothConnect") }
    }

    @Published var soundOnBluetoothConnect: String = UserDefaults.standard.string(forKey: "soundOnBluetoothConnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnBluetoothConnect, forKey: "soundOnBluetoothConnect") }
    }
    @Published var notifyOnBluetoothDisconnect: Bool = UserDefaults.standard.object(forKey: "notifyOnBluetoothDisconnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnBluetoothDisconnect, forKey: "notifyOnBluetoothDisconnect") }
    }

    @Published var soundOnBluetoothDisconnect: String = UserDefaults.standard.string(forKey: "soundOnBluetoothDisconnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnBluetoothDisconnect, forKey: "soundOnBluetoothDisconnect") }
    }
    @Published var bluetoothHistory: [String] = (UserDefaults.standard.array(forKey: "bluetoothHistory") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(bluetoothHistory, forKey: "bluetoothHistory") }
    }
    @Published var bluetoothBlocklist: [String] = (UserDefaults.standard.array(forKey: "bluetoothBlocklist") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(bluetoothBlocklist, forKey: "bluetoothBlocklist") }
    }
    @Published var showBluetoothIndicator: Bool = false
    @Published var bluetoothIsConnected: Bool = false
    @Published var bluetoothDeviceName: String = ""
    
    @Published var notifyOnWiFiConnect: Bool = UserDefaults.standard.object(forKey: "notifyOnWiFiConnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnWiFiConnect, forKey: "notifyOnWiFiConnect") }
    }

    @Published var soundOnWiFiConnect: String = UserDefaults.standard.string(forKey: "soundOnWiFiConnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnWiFiConnect, forKey: "soundOnWiFiConnect") }
    }
    @Published var notifyOnWiFiDisconnect: Bool = UserDefaults.standard.object(forKey: "notifyOnWiFiDisconnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnWiFiDisconnect, forKey: "notifyOnWiFiDisconnect") }
    }

    @Published var soundOnWiFiDisconnect: String = UserDefaults.standard.string(forKey: "soundOnWiFiDisconnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnWiFiDisconnect, forKey: "soundOnWiFiDisconnect") }
    }
    @Published var wifiHistory: [String] = (UserDefaults.standard.array(forKey: "wifiHistory") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(wifiHistory, forKey: "wifiHistory") }
    }
    @Published var wifiBlocklist: [String] = (UserDefaults.standard.array(forKey: "wifiBlocklist") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(wifiBlocklist, forKey: "wifiBlocklist") }
    }
    
    @Published var cameraHistory: [String] = (UserDefaults.standard.array(forKey: "cameraHistory") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(cameraHistory, forKey: "cameraHistory") }
    }
    @Published var cameraBlocklist: [String] = (UserDefaults.standard.array(forKey: "cameraBlocklist") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(cameraBlocklist, forKey: "cameraBlocklist") }
    }
    
    @Published var micHistory: [String] = (UserDefaults.standard.array(forKey: "micHistory") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(micHistory, forKey: "micHistory") }
    }
    @Published var micBlocklist: [String] = (UserDefaults.standard.array(forKey: "micBlocklist") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(micBlocklist, forKey: "micBlocklist") }
    }
    @Published var showWiFiIndicator: Bool = false
    @Published var wiFiSSID: String = ""
    @Published var wiFiIsConnected: Bool = false
    @Published var wiFiIsHotspot: Bool = false
    
    @Published var wiFiIPAddress: String?
    @Published var wiFiRouterIP: String?
    @Published var wiFiTxRate: Double?
    @Published var wiFiChannel: String?
    @Published var wiFiRSSI: Int?
    @Published var wiFiDetailsFetched: Bool = false
    @Published var bluetoothEventId: UUID = UUID()
    private var bluetoothTimer: Timer?
    private var bluetoothObserver: BluetoothObserver?
    private var lastBluetoothEventTime: Date = Date.distantPast
    
    // Multimedia
    @Published var enableMediaNotification: Bool = UserDefaults.standard.object(forKey: "enableMediaNotification") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableMediaNotification, forKey: "enableMediaNotification") }
    }
    @Published var showMediaIndicator: Bool = false
    @Published var mediaTitle: String = ""
    @Published var mediaArtist: String = ""
    @Published var mediaDuration: Double = 0.0
    @Published var mediaElapsedTime: Double = 0.0
    @Published var mediaIsPlaying: Bool = false
    @Published var mediaAction: String = "pause"
    @Published var mediaBundleId: String = ""
    @Published var mediaAlbum: String = ""
    
    @AppStorage("notifyMediaStart") var notifyMediaStart: Bool = true

    @AppStorage("soundMediaStart") var soundMediaStart: String = "None"
    @AppStorage("notifyMediaPause") var notifyMediaPause: Bool = true

    @AppStorage("soundMediaPause") var soundMediaPause: String = "None"
    @AppStorage("notifyMediaResume") var notifyMediaResume: Bool = true

    @AppStorage("soundMediaResume") var soundMediaResume: String = "None"
    @AppStorage("notifyMediaEnd") var notifyMediaEnd: Bool = true

    @AppStorage("soundMediaEnd") var soundMediaEnd: String = "None"
    
    @Published var mediaEventId: UUID = UUID()
    private var mediaTimer: Timer?
    private var mediaHideTimer: Timer?
    private var mediaObserver: MediaObserver?
    
    // Theme
    @Published var enableTheme: Bool = UserDefaults.standard.object(forKey: "enableTheme") as? Bool ?? false {
        didSet { 
            UserDefaults.standard.set(enableTheme, forKey: "enableTheme")
            if !enableTheme { withAnimation { self.showThemeIndicator = false } }
        }
    }
    @Published var notifyOnThemeDark: Bool = UserDefaults.standard.object(forKey: "notifyOnThemeDark") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnThemeDark, forKey: "notifyOnThemeDark") }
    }

    @Published var soundOnThemeDark: String = UserDefaults.standard.string(forKey: "soundOnThemeDark") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnThemeDark, forKey: "soundOnThemeDark") }
    }
    @Published var notifyOnThemeLight: Bool = UserDefaults.standard.object(forKey: "notifyOnThemeLight") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnThemeLight, forKey: "notifyOnThemeLight") }
    }

    @Published var soundOnThemeLight: String = UserDefaults.standard.string(forKey: "soundOnThemeLight") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnThemeLight, forKey: "soundOnThemeLight") }
    }
    @Published var showThemeIndicator: Bool = false
    @Published var isDarkMode: Bool = false
    @Published var themeEventId: UUID = UUID()
    private var themeTimer: Timer?
    private var themeObserver: ThemeObserver?
    
    // Focus Mode
    @Published var enableFocus: Bool = UserDefaults.standard.object(forKey: "enableFocus") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableFocus, forKey: "enableFocus") }
    }
    @Published var notifyOnFocusOn: Bool = UserDefaults.standard.object(forKey: "notifyOnFocusOn") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnFocusOn, forKey: "notifyOnFocusOn") }
    }
    @Published var notifyOnFocusOff: Bool = UserDefaults.standard.object(forKey: "notifyOnFocusOff") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnFocusOff, forKey: "notifyOnFocusOff") }
    }
    @Published var soundOnFocusOn: String = UserDefaults.standard.string(forKey: "soundOnFocusOn") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnFocusOn, forKey: "soundOnFocusOn") }
    }
    @Published var soundOnFocusOff: String = UserDefaults.standard.string(forKey: "soundOnFocusOff") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnFocusOff, forKey: "soundOnFocusOff") }
    }
    @Published var enableFocusReminder: Bool = UserDefaults.standard.object(forKey: "enableFocusReminder") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(enableFocusReminder, forKey: "enableFocusReminder")
            updateFocusReminderTimer()
        }
    }
    @Published var focusReminderInterval: Int = UserDefaults.standard.integer(forKey: "focusReminderInterval") == 0 ? 15 : UserDefaults.standard.integer(forKey: "focusReminderInterval") {
        didSet {
            UserDefaults.standard.set(focusReminderInterval, forKey: "focusReminderInterval")
            updateFocusReminderTimer()
        }
    }
    
    private var focusReminderTimer: Timer?
    @Published var showFocusIndicator: Bool = false
    @Published var isFocusModeActive: Bool = false
    @Published var focusModeName: String = "Focus"
    @Published var focusColorName: String = "systemIndigoColor"
    @Published var focusSymbol: String = "moon.fill"
    @Published var isFocusReminder: Bool = false
    @Published var isFocusSwitched: Bool = false
    struct ActiveFocusDetails: Equatable {
        var startDate: Date?
        var endDate: Date?
        var source: String?
        var device: String?
        var untilLocationLeft: Bool = false
        var endedAt: Date?
        var endedReason: String?
    }
    @Published var focusEventId: UUID = UUID()
    @Published var activeFocusDetails: ActiveFocusDetails? = nil
    @Published var lastEndedFocusDetails: ActiveFocusDetails? = nil
    private var focusTimer: Timer?
    private var focusObserver: FocusObserver?
    
    // Privacy
    @Published var enablePrivacy: Bool = UserDefaults.standard.object(forKey: "enablePrivacy") as? Bool ?? false {
        didSet { 
            UserDefaults.standard.set(enablePrivacy, forKey: "enablePrivacy")
            if !enablePrivacy { withAnimation { self.showMicIndicator = false; self.showCameraIndicator = false; self.showLocationIndicator = false } }
        }
    }
    @Published var notifyOnMicOn: Bool = UserDefaults.standard.object(forKey: "notifyOnMicOn") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnMicOn, forKey: "notifyOnMicOn") }
    }

    @Published var soundOnMicOn: String = UserDefaults.standard.string(forKey: "soundOnMicOn") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnMicOn, forKey: "soundOnMicOn") }
    }
    @Published var notifyOnMicOff: Bool = UserDefaults.standard.object(forKey: "notifyOnMicOff") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnMicOff, forKey: "notifyOnMicOff") }
    }

    @Published var soundOnMicOff: String = UserDefaults.standard.string(forKey: "soundOnMicOff") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnMicOff, forKey: "soundOnMicOff") }
    }
    
    @Published var notifyOnCameraOn: Bool = UserDefaults.standard.object(forKey: "notifyOnCameraOn") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCameraOn, forKey: "notifyOnCameraOn") }
    }

    @Published var soundOnCameraOn: String = UserDefaults.standard.string(forKey: "soundOnCameraOn") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCameraOn, forKey: "soundOnCameraOn") }
    }
    @Published var notifyOnCameraOff: Bool = UserDefaults.standard.object(forKey: "notifyOnCameraOff") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCameraOff, forKey: "notifyOnCameraOff") }
    }

    @Published var soundOnCameraOff: String = UserDefaults.standard.string(forKey: "soundOnCameraOff") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCameraOff, forKey: "soundOnCameraOff") }
    }
    
    @Published var notifyOnLocationOn: Bool = UserDefaults.standard.object(forKey: "notifyOnLocationOn") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnLocationOn, forKey: "notifyOnLocationOn") }
    }

    @Published var soundOnLocationOn: String = UserDefaults.standard.string(forKey: "soundOnLocationOn") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnLocationOn, forKey: "soundOnLocationOn") }
    }
    
    @Published var locationHistory: [String] = (UserDefaults.standard.array(forKey: "locationHistory") as? [String]) ?? ["System Services"] {
        didSet { UserDefaults.standard.set(locationHistory, forKey: "locationHistory") }
    }
    @Published var locationBlocklist: [String] = (UserDefaults.standard.array(forKey: "locationBlocklist") as? [String]) ?? ["System Services"] {
        didSet { UserDefaults.standard.set(locationBlocklist, forKey: "locationBlocklist") }
    }
    
    @Published var showMicIndicator: Bool = false
    @Published var isMicExpanded: Bool = false
    @Published var isMicActive: Bool = false
    @Published var activeMicName: String = ""
    
    @Published var showLocationIndicator: Bool = false
    @Published var isLocationExpanded: Bool = false
    @Published var isLocationActive: Bool = false
    @Published var locationEventId = UUID()
    @Published var activeLocationAppName: String = ""
    private var locationTimer: Timer?
    @Published var currentMicDeviceName: String = ""
    @Published var micEventId: UUID = UUID()
    @Published var isSwitchingMic: Bool = false
    private var micTimer: Timer?
    private var isMicTimerScheduledInstantly = false
    private var lastMicEventTime: Date = Date.distantPast
    
    @Published var showCameraIndicator: Bool = false
    @Published var isCameraExpanded: Bool = false
    @Published var isCameraActive: Bool = false
    @Published var activeCameraName: String = ""
    @Published var activeCameraClientName: String = ""
    @Published var activeCameraClientBundleID: String = ""
    @Published var activeCameraClientPID: Int32? = nil
    @Published var cameraEventId: UUID = UUID()
    private var cameraTimer: Timer?
    private var isCameraTimerScheduledInstantly = false
    
    @Published var activeMicClientName: String = ""
    @Published var activeMicClientBundleID: String = ""
    @Published var activeMicClientPID: Int? = nil
    private var avObserver: AVObserver?
    private var locationObserver: LocationObserver?
    private var cameraClientObserver: CameraClientObserver?
    
    // Peripherals
    @Published var enablePeripheral: Bool = UserDefaults.standard.object(forKey: "enablePeripheral") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enablePeripheral, forKey: "enablePeripheral") }
    }
    @Published var notifyOnPeripheralConnect: Bool = UserDefaults.standard.object(forKey: "notifyOnPeripheralConnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnPeripheralConnect, forKey: "notifyOnPeripheralConnect") }
    }

    @Published var soundOnPeripheralConnect: String = UserDefaults.standard.string(forKey: "soundOnPeripheralConnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnPeripheralConnect, forKey: "soundOnPeripheralConnect") }
    }
    @Published var notifyOnPeripheralDisconnect: Bool = UserDefaults.standard.object(forKey: "notifyOnPeripheralDisconnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnPeripheralDisconnect, forKey: "notifyOnPeripheralDisconnect") }
    }

    @Published var soundOnPeripheralDisconnect: String = UserDefaults.standard.string(forKey: "soundOnPeripheralDisconnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnPeripheralDisconnect, forKey: "soundOnPeripheralDisconnect") }
    }
    @Published var peripheralHistory: [String] = (UserDefaults.standard.array(forKey: "peripheralHistory") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(peripheralHistory, forKey: "peripheralHistory") }
    }
    @Published var peripheralBlocklist: [String] = (UserDefaults.standard.array(forKey: "peripheralBlocklist") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(peripheralBlocklist, forKey: "peripheralBlocklist") }
    }
    @Published var peripheralIcons: [String: String] = (UserDefaults.standard.dictionary(forKey: "peripheralIcons") as? [String: String]) ?? [:] {
        didSet { UserDefaults.standard.set(peripheralIcons, forKey: "peripheralIcons") }
    }
    
    // Displays
    @Published var enableDisplay: Bool = UserDefaults.standard.object(forKey: "enableDisplay") as? Bool ?? false {
        didSet { UserDefaults.standard.set(enableDisplay, forKey: "enableDisplay") }
    }
    @Published var notifyOnDisplayConnect: Bool = UserDefaults.standard.object(forKey: "notifyOnDisplayConnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnDisplayConnect, forKey: "notifyOnDisplayConnect") }
    }
    
    @Published var notifyOnDisplayModeChange: Bool = UserDefaults.standard.object(forKey: "notifyOnDisplayModeChange") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnDisplayModeChange, forKey: "notifyOnDisplayModeChange") }
    }
    
    @Published var soundOnDisplayModeChange: String = UserDefaults.standard.string(forKey: "soundOnDisplayModeChange") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnDisplayModeChange, forKey: "soundOnDisplayModeChange") }
    }
    @Published var soundOnDisplayConnect: String = UserDefaults.standard.string(forKey: "soundOnDisplayConnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnDisplayConnect, forKey: "soundOnDisplayConnect") }
    }
    @Published var notifyOnDisplayDisconnect: Bool = UserDefaults.standard.object(forKey: "notifyOnDisplayDisconnect") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnDisplayDisconnect, forKey: "notifyOnDisplayDisconnect") }
    }
    @Published var soundOnDisplayDisconnect: String = UserDefaults.standard.string(forKey: "soundOnDisplayDisconnect") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnDisplayDisconnect, forKey: "soundOnDisplayDisconnect") }
    }
    
    // Accessory Battery
    @Published var enableAccessoryBattery: Bool = UserDefaults.standard.object(forKey: "enableAccessoryBattery") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableAccessoryBattery, forKey: "enableAccessoryBattery") }
    }
    @Published var accessoryBatteryHistory: [String] = (UserDefaults.standard.array(forKey: "accessoryBatteryHistory") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(accessoryBatteryHistory, forKey: "accessoryBatteryHistory") }
    }
    @Published var accessoryBatteryBlocklist: [String] = (UserDefaults.standard.array(forKey: "accessoryBatteryBlocklist") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(accessoryBatteryBlocklist, forKey: "accessoryBatteryBlocklist") }
    }
    
    // Accessory Triggers
    @Published var accessoryNotifyOn100Percent: Bool = UserDefaults.standard.object(forKey: "accessoryNotifyOn100Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(accessoryNotifyOn100Percent, forKey: "accessoryNotifyOn100Percent") }
    }
    @Published var accessorySoundOn100Percent: String = UserDefaults.standard.string(forKey: "accessorySoundOn100Percent") ?? "None" {
        didSet { UserDefaults.standard.set(accessorySoundOn100Percent, forKey: "accessorySoundOn100Percent") }
    }
    @Published var accessoryNotifyOn20Percent: Bool = UserDefaults.standard.object(forKey: "accessoryNotifyOn20Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(accessoryNotifyOn20Percent, forKey: "accessoryNotifyOn20Percent") }
    }
    @Published var accessorySoundOn20Percent: String = UserDefaults.standard.string(forKey: "accessorySoundOn20Percent") ?? "None" {
        didSet { UserDefaults.standard.set(accessorySoundOn20Percent, forKey: "accessorySoundOn20Percent") }
    }
    @Published var accessoryNotifyOn10Percent: Bool = UserDefaults.standard.object(forKey: "accessoryNotifyOn10Percent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(accessoryNotifyOn10Percent, forKey: "accessoryNotifyOn10Percent") }
    }
    @Published var accessorySoundOn10Percent: String = UserDefaults.standard.string(forKey: "accessorySoundOn10Percent") ?? "None" {
        didSet { UserDefaults.standard.set(accessorySoundOn10Percent, forKey: "accessorySoundOn10Percent") }
    }
    
    @Published var showAccessoryBatteryIndicator: Bool = false
    @Published var accessoryBatteryDeviceName: String = ""
    @Published var accessoryBatteryPercentage: Int = 100
    @Published var accessoryBatteryIsPluggedIn: Bool = false
    @Published var accessoryBatteryIsWarning: Bool = false
    @Published var accessoryBatteryEventId: UUID = UUID()
    @Published var accessoryBatteryLevels: [String: Int] = [:]
    @Published var accessoryBatteryCharging: [String: Bool] = [:]
    @Published var bluetoothDetails: [String: [String: String]] = [:]
    private var accessoryBatteryTimer: Timer?
    private var btPoller: BluetoothBatteryPoller?
    
    @Published var showPeripheralIndicator: Bool = false
    @Published var peripheralDeviceName: String = ""
    @Published var peripheralDeviceType: String = ""
    @Published var peripheralDeviceIcon: String = "cable.connector"
    @Published var peripheralIsConnected: Bool = false
    @Published var peripheralEventId: UUID = UUID()
    
    private var lastBluetoothEventTimeByDevice: [String: Date] = [:]
    
    private var peripheralTimer: Timer?
    private var peripheralObserver: PeripheralObserver?
    private var displayObserver: DisplayObserver?
    private var currentPlayingSound: NSSound?
    private var soundCache: [String: NSSound] = [:]
    
    func playNotificationSound(named soundName: String) {
        if soundName == "None" || soundName.isEmpty { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var sound: NSSound?
            
            DispatchQueue.main.sync {
                sound = self.soundCache[soundName]
            }
            
            if sound == nil {
                if soundName == "Default" {
                    let soundFile = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
                    if FileManager.default.fileExists(atPath: soundFile) {
                        sound = NSSound(contentsOfFile: soundFile, byReference: true)
                    } else {
                        sound = NSSound(named: "Pop")
                    }
                } else if soundName == "Power Chime" {
                    let soundFile = "/System/Library/CoreServices/PowerChime.app/Contents/Resources/connect_power.aif"
                    if FileManager.default.fileExists(atPath: soundFile) {
                        sound = NSSound(contentsOfFile: soundFile, byReference: true)
                    } else {
                        sound = NSSound(named: "Pop")
                    }
                } else {
                    sound = NSSound(named: soundName)
                }
                
                if let newSound = sound {
                    DispatchQueue.main.async {
                        self.soundCache[soundName] = newSound
                    }
                }
            }
            
            if let sound = sound {
                if sound.isPlaying {
                    sound.stop()
                    sound.currentTime = 0
                }
                DispatchQueue.main.async {
                    self.currentPlayingSound = sound
                }
                sound.play()
            }
        }
    }

    func dismissCollidingIndicators(newPosition: String, source: String) {
    }
    
    func triggerThemeIndicator(isDark: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableTheme { return }
        if isDark && !notifyOnThemeDark { return }
        if !isDark && !notifyOnThemeLight { return }
        
        playNotificationSound(named: isDark ? soundOnThemeDark : soundOnThemeLight)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.themeTimer?.invalidate()
            
            let pos = self.getOverlayPosition(for: "themeOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "theme")
            
            self.isDarkMode = isDark
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.themeEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showThemeIndicator = true; self.overlayTriggerTimes["theme"] = Date()

                }

                self.themeTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showThemeIndicator = false

                    }

                }

            }

            

            if self.showThemeIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showThemeIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
        }
    }
    
    private func updateFocusReminderTimer() {
        focusReminderTimer?.invalidate()
        focusReminderTimer = nil
        
        if enableFocus && enableFocusReminder && isFocusModeActive {
            let interval = TimeInterval(focusReminderInterval * 60)
            focusReminderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Show reminder without playing a sound (or play a subtle sound if requested, but default is visual)
                DispatchQueue.main.async {
                    self.focusTimer?.invalidate()
                    
                    let pos = self.getOverlayPosition(for: "focusOverlayPosition")
                    self.dismissCollidingIndicators(newPosition: pos, source: "focus")
                    
                    let executeShow = {
                        self.isFocusReminder = true
                        self.isFocusSwitched = false
                        self.focusEventId = UUID()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            self.showFocusIndicator = true
                            self.overlayTriggerTimes["focus"] = Date()
                        }
                        self.focusTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { _ in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.showFocusIndicator = false
                            }
                        }
                    }
                    
                    if self.showFocusIndicator {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.showFocusIndicator = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            executeShow()
                        }
                    } else {
                        executeShow()
                    }
                }
            }
        }
    }
    
    func triggerFocusIndicator(isActive: Bool, modeName: String?, colorName: String = "systemIndigoColor", symbol: String = "moon.fill", isSwitched: Bool = false, details: ActiveFocusDetails? = nil) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableFocus { return }
        if isActive && !notifyOnFocusOn { return }
        if !isActive && !notifyOnFocusOff { return }
        
        playNotificationSound(named: isActive ? soundOnFocusOn : soundOnFocusOff)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.focusTimer?.invalidate()
            
            let pos = self.getOverlayPosition(for: "focusOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "focus")
            
            self.isFocusModeActive = isActive
            self.focusModeName = modeName ?? "Focus"
            self.focusColorName = colorName
            self.focusSymbol = symbol
            self.isFocusReminder = false
            self.isFocusSwitched = isSwitched
            if isActive {
                self.activeFocusDetails = details
                self.lastEndedFocusDetails = nil
            } else {
                if var lastDetails = self.activeFocusDetails {
                    lastDetails.endedAt = Date()
                    self.lastEndedFocusDetails = lastDetails
                } else if var details = details {
                    details.endedAt = Date()
                    self.lastEndedFocusDetails = details
                }
                self.activeFocusDetails = nil
            }
            
            self.updateFocusReminderTimer()
            
            let executeShow = { [weak self] in
                guard let self = self else { return }
                self.focusEventId = UUID()
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showFocusIndicator = true
                    self.overlayTriggerTimes["focus"] = Date()
                }
                self.focusTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showFocusIndicator = false
                    }
                }
            }
            
            if self.showFocusIndicator {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showFocusIndicator = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    executeShow()
                }
            } else {
                executeShow()
            }
        }
    }
    
    func triggerLanguageIndicator(language: String) {
        if !enableKeyboard { return }
        if !notifyOnLanguageChange { return }
        
        playNotificationSound(named: soundOnLanguageChange)
        
        languageTimer?.invalidate()
        let pos = self.getOverlayPosition(for: "languageOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "language")
        
        self.currentKeyboardLanguage = language
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.languageEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showLanguageIndicator = true; self.overlayTriggerTimes["language"] = Date()

                }

                self.languageTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showLanguageIndicator = false

                    }

                }

            }

            

            if self.showLanguageIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showLanguageIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
    }
    
    func getAvailableLanguages() -> [KeyboardLayout] {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource],
              let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return []
        }
        
        var currentId = ""
        if let currentIdPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) {
            currentId = Unmanaged<CFString>.fromOpaque(currentIdPtr).takeUnretainedValue() as String
        }
        
        var layouts: [KeyboardLayout] = []
        for source in sourceList {
            let categoryPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory)
            guard let catPtr = categoryPtr else { continue }
            
            let category = Unmanaged<CFString>.fromOpaque(catPtr).takeUnretainedValue() as String
            
            if category == (kTISCategoryKeyboardInputSource as String) {
                if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                   let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                    let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
                    layouts.append(KeyboardLayout(id: id, name: name, isSelected: (id == currentId)))
                }
            }
        }
        return layouts
    }
    
    func selectLanguage(idToSelect: String) {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return }
        for source in sourceList {
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                if id == idToSelect {
                    isSwitchingLanguageInternally = true
                    TISSelectInputSource(source)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isSwitchingLanguageInternally = false
                    }
                    return
                }
            }
        }
    }

    func toggleCapsLock() {
        var connect: io_connect_t = 0
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
        var state: Bool = false
        IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
        let newState = !state
        IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), newState)
        IOServiceClose(connect)
        
        DispatchQueue.main.async { [weak self] in
            self?.triggerCapsLockIndicator(isOn: newState)
        }
    }

    func startMicSwitchingBuffer() {
        isSwitchingMic = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.isSwitchingMic = false
        }
    }

        
    func finalizeMicIndicator(appName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.enablePrivacy || !self.isMicActive { return }
            if !self.notifyOnMicOn { return }
            
            if !appName.isEmpty {
                if !self.micHistory.contains(appName) {
                    self.micHistory.append(appName)
                }
                if self.micBlocklist.contains(appName) {
                    self.showMicIndicator = false
                    return
                }
            }
            
            self.showMicIndicator = true
            let micAllow = UserDefaults.standard.object(forKey: "micAllowExpansion") as? Bool ?? true
            if !micAllow { self.isMicExpanded = false }
            self.playNotificationSound(named: self.soundOnMicOn)
            
            if !self.isMicTimerScheduledInstantly {
                self.micTimer?.invalidate()
                if !self.isMicExpanded {
                    self.micTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self?.showMicIndicator = false
                        }
                    }
                }
            }
            self.isMicTimerScheduledInstantly = false
        }
    }
    
    func triggerMicIndicator(isActive: Bool, deviceName: String = "") {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isMicActive = isActive
            self.lastMicEventTime = Date()
            
            if isActive {
                self.micTimer?.invalidate()
                self.micEventId = UUID()
                
                if self.showMicIndicator && !self.isMicExpanded {
                    self.isMicTimerScheduledInstantly = true
                    self.micTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self?.showMicIndicator = false
                        }
                    }
                } else {
                    self.isMicTimerScheduledInstantly = false
                }
                
                self.activeMicName = deviceName.isEmpty ? "System Microphone" : deviceName
                self.activeMicClientName = ""
                self.activeMicClientBundleID = ""
                self.activeMicClientPID = nil
                self.cameraClientObserver?.fetchActiveMicClient()
                return // finalizeMicIndicator will handle the UI
            }
            
            // OFF logic
            if self.isSwitchingMic { return }
            if !self.enablePrivacy { return }
            
            if !self.notifyOnMicOff {
                self.showMicIndicator = false
                return
            }
            
            if !self.activeMicClientName.isEmpty && self.micBlocklist.contains(self.activeMicClientName) {
                self.activeMicClientName = ""
                self.activeMicClientBundleID = ""
                self.activeMicClientPID = nil
                return
            }
            
            self.playNotificationSound(named: self.soundOnMicOff)
            
            self.micTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "micOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "mic")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.micEventId = UUID()
                self.showMicIndicator = true; self.overlayTriggerTimes["mic"] = Date()
            }
            
            if !self.isMicExpanded {
                self.micTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showMicIndicator = false
                    }
                }
            }
        }
    }
    
        
    func finalizeCameraIndicator(appName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.enablePrivacy || !self.isCameraActive { return }
            if !self.notifyOnCameraOn { return }
            
            if !appName.isEmpty {
                if !self.cameraHistory.contains(appName) {
                    self.cameraHistory.append(appName)
                }
                if self.cameraBlocklist.contains(appName) {
                    self.showCameraIndicator = false
                    return
                }
            }
            
            self.showCameraIndicator = true
            let camAllow = UserDefaults.standard.object(forKey: "cameraAllowExpansion") as? Bool ?? true
            if !camAllow { self.isCameraExpanded = false }
            self.playNotificationSound(named: self.soundOnCameraOn)
            
            if !self.isCameraTimerScheduledInstantly {
                self.cameraTimer?.invalidate()
                if !self.isCameraExpanded {
                    self.cameraTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self?.showCameraIndicator = false
                        }
                    }
                }
            }
            self.isCameraTimerScheduledInstantly = false
        }
    }
    
    func triggerCameraIndicator(isActive: Bool, deviceName: String = "") {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isCameraActive = isActive
            
            if isActive {
                self.cameraTimer?.invalidate()
                self.cameraEventId = UUID()
                
                if self.showCameraIndicator && !self.isCameraExpanded {
                    self.isCameraTimerScheduledInstantly = true
                    self.cameraTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self?.showCameraIndicator = false
                        }
                    }
                } else {
                    self.isCameraTimerScheduledInstantly = false
                }
                
                self.activeCameraName = deviceName.isEmpty ? "Built-in Camera" : deviceName
                self.activeCameraClientName = ""
                self.activeCameraClientBundleID = ""
                self.activeCameraClientPID = nil
                self.cameraClientObserver?.fetchActiveCameraClient()
                return // finalizeCameraIndicator will handle the UI
            }
            
            // OFF logic
            if !self.enablePrivacy { return }
            
            if !self.notifyOnCameraOff { return }
            
            if !self.activeCameraClientName.isEmpty && self.cameraBlocklist.contains(self.activeCameraClientName) {
                self.activeCameraClientName = ""
                self.activeCameraClientBundleID = ""
                self.activeCameraClientPID = nil
                return
            }
            
            self.playNotificationSound(named: self.soundOnCameraOff)
            
            self.cameraTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "cameraOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "camera")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.cameraEventId = UUID()
                self.showCameraIndicator = true; self.overlayTriggerTimes["camera"] = Date()
            }
            
            let camAllow = UserDefaults.standard.object(forKey: "cameraAllowExpansion") as? Bool ?? true
            if !camAllow { self.isCameraExpanded = false }
            
            if !self.isCameraExpanded {
                self.cameraTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showCameraIndicator = false
                    }
                }
            }
        }
    }
    
    func triggerLocationIndicator(appName: String = "") {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.enablePrivacy { return }
            if !self.notifyOnLocationOn { return }
            
            self.isLocationActive = true
            if !appName.isEmpty {
                self.activeLocationAppName = appName
            }
            
            self.playNotificationSound(named: self.soundOnLocationOn)
            
            self.locationTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "locationOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "location")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.locationEventId = UUID()
                self.showLocationIndicator = true; self.overlayTriggerTimes["location"] = Date()
            }
            
            if !self.isLocationExpanded {
                self.locationTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showLocationIndicator = false
                        self?.isLocationActive = false
                    }
                }
            }
        }
    }
    
    private var batteryTimer: Timer?
    private var isTestingBattery = false
    private var testOriginalPercentage = 0
    private var testOriginalPluggedIn = false
    
    @MainActor
    func forceHide(overlayId: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if overlayId == "volume" { showVolumeIndicator = false }
            else if overlayId == "brightness" { showBrightnessIndicator = false }
            else if overlayId == "keyboardBrightness" { showKeyboardBrightnessIndicator = false }
            else if overlayId.hasPrefix("battery") { showChargingStatus = false; showLowBatteryWarning = false; showUnpluggedStatus = false }
            else if overlayId.hasPrefix("copy") { showCopyIndicator = false }
            else if overlayId.hasPrefix("capsLock") { showCapsLockIndicator = false }
            else if overlayId.hasPrefix("bluetooth") { activeBluetoothNotifications.removeAll(where: { "bluetooth_\($0.id)" == overlayId }) }
            else if overlayId == "language" { showLanguageIndicator = false }
            else if overlayId == "media" { showMediaIndicator = false }
            else if overlayId == "theme" { showThemeIndicator = false }
            else if overlayId == "focus" { showFocusIndicator = false }
            else if overlayId == "mic" { showMicIndicator = false }
            else if overlayId == "camera" { showCameraIndicator = false }
            else if overlayId == "location" { showLocationIndicator = false }
            else if overlayId == "wifi" { showWiFiIndicator = false }
            else if overlayId.hasPrefix("peripheral") { activePeripheralNotifications.removeAll(where: { "peripheral_\($0.id)" == overlayId }) }
            else if overlayId.hasPrefix("display") { activeDisplayNotifications.removeAll(where: { "display_\($0.id)" == overlayId }) }
            
            else if overlayId.hasPrefix("ram") { showRamIndicator = false }

            else if overlayId.hasPrefix("accessoryBattery") { showAccessoryBatteryIndicator = false }
        }
    }
    
    func hideBatteryOverlay() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = false
                self.showLowBatteryWarning = false
                self.showUnpluggedStatus = false
            }
            if self.isTestingBattery {
                self.isBatteryInitialized = false
                self.currentBatteryPercentage = self.testOriginalPercentage
                self.isPluggedIn = self.testOriginalPluggedIn
                self.isBatteryInitialized = true
                self.isTestingBattery = false
            }
        }
    }
    
    func triggerLowBatteryWarning() {
        if !enableBattery { return }
        startFetchingTopBatteryConsumers()
        let currentLevel = currentBatteryPercentage
        playNotificationSound(named: currentLevel <= 10 ? soundOn10Percent : soundOn20Percent)
        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                showChargingStatus = false
                showLowBatteryWarning = false
                showUnpluggedStatus = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showLowBatteryWarning = true; self.overlayTriggerTimes["battery_warning"] = Date()
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { self.showLowBatteryWarning = true; self.overlayTriggerTimes["battery_warning"] = Date() }
        }
        
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            self?.hideBatteryOverlay()
        }
    }
    
    func triggerChargingStatus() {
        if !enableBattery { return }
        if isPluggedIn {
            playNotificationSound(named: soundOnPlug)
        } else if currentBatteryPercentage >= 100 {
            playNotificationSound(named: soundOn100Percent)
        }
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                showChargingStatus = false
                showLowBatteryWarning = false
                showUnpluggedStatus = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showChargingStatus = true; self.overlayTriggerTimes["battery_charging"] = Date()
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = true; self.overlayTriggerTimes["battery_charging"] = Date()
            }
        }
        
        chargingTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            self?.hideBatteryOverlay()
        }
    }
    
    func triggerUnplugStatus() {
        if !enableBattery { return }
        playNotificationSound(named: soundOnUnplug)
        
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        let battPos = self.getOverlayPosition(for: "batteryOverlayPosition")
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        let wasActive = showChargingStatus || showLowBatteryWarning || showUnpluggedStatus
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                showChargingStatus = false
                showLowBatteryWarning = false
                showUnpluggedStatus = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showUnpluggedStatus = true; self.overlayTriggerTimes["battery_charging"] = Date()
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showUnpluggedStatus = true; self.overlayTriggerTimes["battery_charging"] = Date()
            }
        }
        
        chargingTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            self?.hideBatteryOverlay()
        }
    }
    
    func triggerPeripheralIndicator(id: String? = nil, deviceName: String, type: String, typeIcon: String, isConnected: Bool, details: [String: String]? = nil) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.enablePeripheral { return }
            
            let notifId = id ?? deviceName
            // Fix for USB bus resets: delay disconnects by 3s. If reconnect happens within 3s, ignore both.
            let debounceKey = "peripheral_debounce_\(notifId)"
            if !isConnected {
                self.notificationTimers[debounceKey]?.invalidate()
                self.notificationTimers[debounceKey] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.notificationTimers.removeValue(forKey: debounceKey)
                    self?.showPeripheralOverlay(id: notifId, deviceName: deviceName, type: type, typeIcon: typeIcon, isConnected: false, details: details)
                }
            } else {
                if let timer = self.notificationTimers[debounceKey] {
                    let wasValid = timer.isValid
                    timer.invalidate()
                    self.notificationTimers.removeValue(forKey: debounceKey)
                    
                    if wasValid {
                        // It reconnected before the 1s timer fired. This was a bus reset. Ignore it to prevent spam.
                        return
                    }
                }
                self.showPeripheralOverlay(id: notifId, deviceName: deviceName, type: type, typeIcon: typeIcon, isConnected: true, details: details)
            }
        }
    }
    
    private func showPeripheralOverlay(id: String? = nil, deviceName: String, type: String, typeIcon: String, isConnected: Bool, details: [String: String]? = nil) {
        let notifId = id ?? deviceName
        if isConnected && !self.notifyOnPeripheralConnect { return }
        if !isConnected && !self.notifyOnPeripheralDisconnect { return }
        
        if !self.peripheralHistory.contains(deviceName) {
            self.peripheralHistory.append(deviceName)
        }
        if self.peripheralIcons[deviceName] != typeIcon {
            self.peripheralIcons[deviceName] = typeIcon
        }
        if self.peripheralBlocklist.contains(deviceName) { return }
        self.playNotificationSound(named: isConnected ? self.soundOnPeripheralConnect : self.soundOnPeripheralDisconnect)
        
        let pos = self.getOverlayPosition(for: "peripheralOverlayPosition")
        self.dismissCollidingIndicators(newPosition: pos, source: "peripheral")
        
        let newNotif = DeviceNotification(id: notifId, deviceName: deviceName, type: type, icon: typeIcon, isConnected: isConnected, timestamp: Date(), details: details)
        
        withAnimation(.easeInOut(duration: 0.15)) {
            if let idx = self.activePeripheralNotifications.firstIndex(where: { $0.id == notifId }) {
                self.activePeripheralNotifications[idx] = newNotif
            } else {
                self.activePeripheralNotifications.append(newNotif)
            }
            self.enforceNotificationLimit()
        }
        
        let timerKey = "peripheral_\(notifId)"
        self.notificationTimers[timerKey]?.invalidate(); self.overlayTriggerTimes[timerKey] = Date()
        self.notificationTimers[timerKey] = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.activePeripheralNotifications.removeAll(where: { $0.id == notifId })
            }
        }
    }
    
    func triggerDisplayIndicator(id: String, deviceName: String, type: String, typeIcon: String, isConnected: Bool, isModeChange: Bool = false, details: [String: String]? = nil) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.enableDisplay { return }
            if isModeChange {
                if !self.notifyOnDisplayModeChange { return }
            } else {
                if isConnected && !self.notifyOnDisplayConnect { return }
                if !isConnected && !self.notifyOnDisplayDisconnect { return }
            }
            
            let sound = isModeChange ? self.soundOnDisplayModeChange : (isConnected ? self.soundOnDisplayConnect : self.soundOnDisplayDisconnect)
            if sound != "None" {
                self.playNotificationSound(named: sound)
                self.playNotificationSound(named: sound)
            }
            
            let pos = self.getOverlayPosition(for: "displayOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "display")
            
            let newNotif = DeviceNotification(
                id: id,
                deviceName: deviceName,
                type: type,
                icon: typeIcon,
                isConnected: isConnected,
                timestamp: Date(),
                details: details
            )
            
            withAnimation(.easeInOut(duration: 0.2)) {
                if let idx = self.activeDisplayNotifications.firstIndex(where: { $0.id == id }) {
                    self.activeDisplayNotifications[idx] = newNotif
                } else if !self.activeDisplayNotifications.isEmpty {
                    let oldId = self.activeDisplayNotifications[0].id
                    self.notificationTimers["display_\(oldId)"]?.invalidate()
                    self.activeDisplayNotifications[0] = newNotif
                } else {
                    self.activeDisplayNotifications.append(newNotif)
                }
            }
            
            let timerKey = "display_\(id)"
            self.notificationTimers[timerKey]?.invalidate(); self.overlayTriggerTimes[timerKey] = Date()
            self.notificationTimers[timerKey] = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.activeDisplayNotifications.removeAll(where: { $0.id == id })
                }
            }
        }
    }
    
    private func getMountPoint(for notification: DeviceNotification) -> URL? {
        let keys: [URLResourceKey] = [.volumeIsInternalKey, .volumeTotalCapacityKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) ?? []
        let bsdName = notification.details?["BSD Name"]
        let productName = notification.details?["Product"]?.lowercased() ?? ""
        let deviceName = notification.deviceName.lowercased()
        
        var matchingUrls: [URL] = []
        
        for url in urls {
            guard url.path.hasPrefix("/Volumes/") else { continue }
            if let session = DASessionCreate(kCFAllocatorDefault),
               let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                
                var matched = false
                
                // 1. Try strict BSD match if available and valid
                if let bsdCStr = DADiskGetBSDName(disk) {
                    let volBsd = String(cString: bsdCStr)
                    if let b = bsdName, b.hasPrefix("disk"), (volBsd == b || volBsd.hasPrefix(b + "s")) {
                        matched = true
                    }
                }
                
                // 2. Try matching the hardware product name via DiskArbitration
                if !matched, let desc = DADiskCopyDescription(disk) as? [String: Any] {
                    let model = (desc[kDADiskDescriptionDeviceModelKey as String] as? String ?? "").lowercased()
                    let vendor = (desc[kDADiskDescriptionDeviceVendorKey as String] as? String ?? "").lowercased()
                    let combined = "\(vendor) \(model)"
                    
                    if !productName.isEmpty && (combined.contains(productName) || productName.contains(model)) {
                        matched = true
                    } else if !deviceName.isEmpty && deviceName != "usb device" && deviceName != "mass storage" {
                        if combined.contains(deviceName) || deviceName.contains(model) {
                            matched = true
                        }
                    }
                }
                
                // 3. Try matching the volume name itself as a fallback
                if !matched {
                    let pathLower = url.lastPathComponent.lowercased()
                    if !productName.isEmpty && (pathLower.contains(productName) || productName.contains(pathLower)) {
                        matched = true
                    } else if !deviceName.isEmpty && deviceName != "usb device" && deviceName != "mass storage" {
                        if pathLower.contains(deviceName) || deviceName.contains(pathLower) {
                            matched = true
                        }
                    }
                }
                
                if matched {
                    matchingUrls.append(url)
                }
            }
        }
        
        // If multiple partitions matched (e.g. HDD with System Reserved + Data), pick the largest one!
        if matchingUrls.count > 1 {
            return matchingUrls.max { u1, u2 in
                let c1 = (try? u1.resourceValues(forKeys: [.volumeTotalCapacityKey]))?.volumeTotalCapacity ?? 0
                let c2 = (try? u2.resourceValues(forKeys: [.volumeTotalCapacityKey]))?.volumeTotalCapacity ?? 0
                return c1 < c2
            }
        }
        
        return matchingUrls.first
    }
    
    func hasOpticalMedia() -> Bool? {
        let task = Process()
        task.launchPath = "/usr/bin/drutil"
        task.arguments = ["status"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
            let lower = output.lowercased()
            if lower.contains("no media inserted") || lower.contains("no media") || lower.contains("empty") {
                return false
            }
            return true
        }
        return nil
    }

    func getDriveCapacity(for notification: DeviceNotification) -> (total: Int, available: Int)? {
        guard let target = getMountPoint(for: notification) else { return nil }
        
        let keys: [URLResourceKey] = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        if let values = try? target.resourceValues(forKeys: Set(keys)),
           let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
            return (total, available)
        }
        return nil
    }
    
    private func getDeviceNode(for volume: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["info", "-plist", volume]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let deviceNode = plist["DeviceNode"] as? String {
            return deviceNode
        }
        return nil
    }
    
    func openDrive(for notification: DeviceNotification) {
        if let target = getMountPoint(for: notification) {
            if notification.type == "CD/DVD Drive" {
                let videoTs = target.appendingPathComponent("VIDEO_TS")
                if FileManager.default.fileExists(atPath: videoTs.path) {
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-a", "DVD Player"]
                    try? task.run()
                    return
                }
                
                if let files = try? FileManager.default.contentsOfDirectory(atPath: target.path), files.contains(where: { $0.lowercased().hasSuffix(".aiff") || $0.lowercased().hasSuffix(".cda") }) {
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-a", "Music"]
                    try? task.run()
                    return
                }
            }
            
            NSWorkspace.shared.open(target)
        }
    }
    
    func ejectDrive(for notification: DeviceNotification, completion: @escaping (Bool, String?) -> Void = { _,_ in }) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let target = self.getMountPoint(for: notification) else {
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            
            let deviceNode = self.getDeviceNode(for: target.path)
            let task = Process()
            task.launchPath = "/usr/sbin/diskutil"
            task.arguments = ["unmount", target.path]
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async { completion(task.terminationStatus == 0, deviceNode) }
            } catch {
                LogManager.shared.log("Error in MediaKeyManager.swift: \(error)", level: "ERROR")
                DispatchQueue.main.async { completion(false, nil) }
            }
        }
    }
    
    func mountDrive(deviceNode: String, completion: @escaping (Bool) -> Void = { _ in }) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/sbin/diskutil"
            task.arguments = ["mount", deviceNode]
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async { completion(task.terminationStatus == 0) }
            } catch {
                LogManager.shared.log("Error in MediaKeyManager.swift: \(error)", level: "ERROR")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    func triggerAccessoryBatteryIndicator(deviceName: String, percentage: Int, isPluggedIn: Bool, isWarning: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.accessoryBatteryLevels[deviceName] = percentage
            self.accessoryBatteryCharging[deviceName] = isPluggedIn
            
            if !self.enableAccessoryBattery { return }
            
            if !self.accessoryBatteryHistory.contains(deviceName) {
                self.accessoryBatteryHistory.append(deviceName)
            }
            if self.accessoryBatteryBlocklist.contains(deviceName) { return }
            
            self.accessoryBatteryDeviceName = deviceName
            self.accessoryBatteryPercentage = percentage
            self.accessoryBatteryIsPluggedIn = isPluggedIn
            self.accessoryBatteryIsWarning = isWarning
            
            if percentage == 100 {
                self.playNotificationSound(named: self.accessorySoundOn100Percent)
            } else if percentage <= 10 {
                self.playNotificationSound(named: self.accessorySoundOn10Percent)
            } else if percentage <= 20 {
                self.playNotificationSound(named: self.accessorySoundOn20Percent)
            }
            
            self.accessoryBatteryTimer?.invalidate()
            let pos = self.getOverlayPosition(for: "batteryOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "accessoryBattery")
            withAnimation(.easeInOut(duration: 0.15)) {
                self.accessoryBatteryEventId = UUID()
                self.showAccessoryBatteryIndicator = true
                self.overlayTriggerTimes["accessoryBattery"] = Date()
            }
            
            let displayTime: TimeInterval = isWarning ? 4.5 : 3.5
            self.accessoryBatteryTimer = Timer.scheduledTimer(withTimeInterval: displayTime, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showAccessoryBatteryIndicator = false
                }
            }
        }
    }
    
    func updateAccessoryState(deviceName: String, percentage: Int, isPluggedIn: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.accessoryBatteryLevels[deviceName] = percentage
            self.accessoryBatteryCharging[deviceName] = isPluggedIn
            
            if !self.accessoryBatteryHistory.contains(deviceName) {
                self.accessoryBatteryHistory.append(deviceName)
            }
        }
    }
    
    func updateBluetoothDetails(deviceName: String, details: [String: String]) {
        DispatchQueue.main.async { [weak self] in
            self?.bluetoothDetails[deviceName] = details
        }
    }
    
    func fetchBluetoothDetails() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.btPoller?.forcePoll()
        }
    }
    
    func disconnectBluetoothDevice(macAddress: String) {
        guard let device = IOBluetoothDevice(addressString: macAddress) else { return }
        if device.isConnected() {
            device.closeConnection()
        }
    }
    
    func triggerVolumeIndicator(playSound: Bool = false) {
        if !enableVolume { return }
        if playSound {
            playNotificationSound(named: soundOnVolume)
        }

        cancelOverlayHide(for: "volume")
        volumeTimer?.invalidate()
        let volPos = self.getOverlayPosition(for: "volumeOverlayPosition")
        dismissCollidingIndicators(newPosition: volPos, source: "volume")
        
        if !showVolumeIndicator {
            withAnimation(.easeInOut(duration: 0.25)) {
                showVolumeIndicator = true
            }
        }
        self.overlayTriggerTimes["volume"] = Date()
        
        volumeTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showVolumeIndicator = false
            }
        }
    }
    
    func triggerBrightnessIndicator(playSound: Bool = false) {
        if !enableBrightness { return }
        if playSound {
            playNotificationSound(named: soundOnBrightness)
        }
        cancelOverlayHide(for: "brightness")
        brightnessTimer?.invalidate()
        let brightPos = self.getOverlayPosition(for: "brightnessOverlayPosition")
        dismissCollidingIndicators(newPosition: brightPos, source: "brightness")
        
        if !showBrightnessIndicator {
            withAnimation(.easeInOut(duration: 0.25)) {
                showBrightnessIndicator = true
            }
        }
        self.overlayTriggerTimes["brightness"] = Date()
        
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showBrightnessIndicator = false
            }
        }
    }
    
    func triggerKeyboardBrightnessIndicator(playSound: Bool = false) {
        if !enableKeyboardBrightness { return }
        if playSound {
            playNotificationSound(named: soundOnKeyboardBrightness)
        }
        cancelOverlayHide(for: "keyboardBrightness")
        keyboardBrightnessTimer?.invalidate()
        let kbPos = self.getOverlayPosition(for: "keyboardBrightnessOverlayPosition")
        dismissCollidingIndicators(newPosition: kbPos, source: "keyboardBrightness")
        
        if !showKeyboardBrightnessIndicator {
            withAnimation(.easeInOut(duration: 0.25)) {
                showKeyboardBrightnessIndicator = true
            }
        }
        self.overlayTriggerTimes["keyboardBrightness"] = Date()
        
        keyboardBrightnessTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showKeyboardBrightnessIndicator = false
            }
        }
    }
    
    func triggerClipboardIndicator(text: String, action: String = "copy", app: String = "", folder: String? = nil, size: String = "") {
        if !enableKeyboard { return }
        if action == "copy" && !notifyOnCopy { return }
        if action == "cut" && !notifyOnCut { return }
        if action == "paste" && !notifyOnPaste { return }
        
        if action == "copy" { playNotificationSound(named: soundOnCopy) }
        else if action == "cut" { playNotificationSound(named: soundOnCut) }
        else if action == "paste" { playNotificationSound(named: soundOnPaste) }
        
        copyTimer?.invalidate()
        pendingClipboardShowTask?.cancel()
        
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
            self.clipboardEventId = UUID()
            
            withAnimation(.easeInOut(duration: 0.15)) {
                self.showCopyIndicator = true
                self.overlayTriggerTimes["copy"] = Date()
            }
            
            self.copyTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showCopyIndicator = false
                }
            }
        }
        
        if self.showCopyIndicator {
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

    func triggerRamOverlay() {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !notifyOnHighRam { return }
        
        playNotificationSound(named: self.soundOnHighRam)
        
        self.hideRamIndicatorTask?.cancel()
        let pos = self.getOverlayPosition(for: "ramOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "ram")
        
        let executeShow = { [weak self] in
            guard let self = self else { return }
            self.ramEventId = UUID()
            withAnimation(.easeInOut(duration: 0.15)) {
                self.showRamIndicator = true
                self.overlayTriggerTimes["ram"] = Date()
            }
            
            let task = DispatchWorkItem { [weak self] in
                withAnimation(.easeInOut(duration: 0.15)) {
                    self?.showRamIndicator = false
                }
            }
            self.hideRamIndicatorTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + MediaKeyManager.notificationDuration, execute: task)
        }
        
        if self.showRamIndicator {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.showRamIndicator = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                executeShow()
            }
        } else {
            executeShow()
        }
    }

    
    func triggerCapsLockIndicator(isOn: Bool) {
        if !enableKeyboard { return }
        if !notifyOnCapsLock { return }
        
        playNotificationSound(named: soundOnCapsLock)
        
        capsLockTimer?.invalidate()
        let pos = self.getOverlayPosition(for: "capsLockOverlayPosition")
        dismissCollidingIndicators(newPosition: pos, source: "capsLock")
        
        self.isCapsLockOn = isOn
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.capsLockEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showCapsLockIndicator = true; self.overlayTriggerTimes["capsLock"] = Date()

                }

                self.capsLockTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showCapsLockIndicator = false

                    }

                }

            }

            

            executeShow()
    }
    
    
    func triggerBluetoothIndicator(deviceName: String, deviceAddress: String, isConnected: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableBluetooth { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.bluetoothHistory.contains(deviceName) {
                self.bluetoothHistory.append(deviceName)
            }
        }
        
        if isConnected && !notifyOnBluetoothConnect { return }
        if !isConnected && !notifyOnBluetoothDisconnect { return }
        if bluetoothBlocklist.contains(deviceName) { return }
        
        let now = Date()
        let eventKey = "\(deviceAddress)_\(isConnected ? "connect" : "disconnect")"
        if let lastTime = lastBluetoothEventTimeByDevice[eventKey], now.timeIntervalSince(lastTime) < 2.0 {
            return
        }
        lastBluetoothEventTimeByDevice[eventKey] = now
        
        let soundToPlay = isConnected ? soundOnBluetoothConnect : soundOnBluetoothDisconnect
        playNotificationSound(named: soundToPlay)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let pos = self.getOverlayPosition(for: "bluetoothOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "bluetooth")
            
            let newNotif = DeviceNotification(id: deviceAddress, deviceName: deviceName, type: "bluetooth", icon: "bluetooth", isConnected: isConnected, timestamp: Date())
            
            withAnimation(.easeInOut(duration: 0.15)) {
                if let idx = self.activeBluetoothNotifications.firstIndex(where: { $0.id == deviceAddress }) {
                    self.activeBluetoothNotifications[idx] = newNotif
                } else {
                    self.activeBluetoothNotifications.append(newNotif)
                }
                self.enforceNotificationLimit()
            }
            
            let timerKey = "bluetooth_\(deviceAddress)"
            self.notificationTimers[timerKey]?.invalidate(); self.overlayTriggerTimes[timerKey] = Date()
            self.notificationTimers[timerKey] = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.activeBluetoothNotifications.removeAll(where: { $0.id == deviceAddress })
                }
            }
        }
    }
    
    private var wiFiTimer: Timer?
    @Published var wiFiEventId: UUID = UUID()
    
    func triggerWiFiIndicator(ssid: String, isConnected: Bool, isHotspot: Bool = false) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableWiFi { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.wifiHistory.contains(ssid) {
                self.wifiHistory.append(ssid)
            }
        }
        
        if isConnected && !notifyOnWiFiConnect { return }
        if !isConnected && !notifyOnWiFiDisconnect { return }
        if wifiBlocklist.contains(ssid) { return }
        
        let soundToPlay = isConnected ? soundOnWiFiConnect : soundOnWiFiDisconnect
        playNotificationSound(named: soundToPlay)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.wiFiTimer?.invalidate()
            
            let pos = self.getOverlayPosition(for: "wifiOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "wifi")
            
            self.wiFiSSID = ssid
            self.wiFiIsConnected = isConnected
            self.wiFiIsHotspot = isHotspot
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.wiFiEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showWiFiIndicator = true; self.overlayTriggerTimes["wifi"] = Date()

                }

                self.wiFiTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showWiFiIndicator = false

                    }

                }

            }

            

            if self.showWiFiIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showWiFiIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
        }
    }
    
    func fetchWiFiDetails() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let interface = CWWiFiClient.shared().interface() else { return }
            
            let rssi = interface.rssiValue()
            let txRate = interface.transmitRate()
            
            var channelStr: String? = nil
            if let channel = interface.wlanChannel() {
                let band: String
                if channel.channelBand == .band5GHz {
                    band = "5 GHz"
                } else if channel.channelBand == .band6GHz {
                    band = "6 GHz"
                } else {
                    band = "2.4 GHz"
                }
                channelStr = "Ch \(channel.channelNumber) (\(band))"
            }
            
            var ipAddr: String? = nil
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaddr) == 0 {
                var ptr = ifaddr
                while ptr != nil {
                    defer { ptr = ptr?.pointee.ifa_next }
                    
                    let interfaceInfo = ptr?.pointee
                    let addrFamily = interfaceInfo?.ifa_addr.pointee.sa_family
                    if addrFamily == UInt8(AF_INET) {
                        let name = String(cString: (interfaceInfo?.ifa_name)!)
                        if name == "en0" { // en0 is typically Wi-Fi on Mac
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(interfaceInfo?.ifa_addr, socklen_t((interfaceInfo?.ifa_addr.pointee.sa_len)!),
                                        &hostname, socklen_t(hostname.count),
                                        nil, socklen_t(0), NI_NUMERICHOST)
                            ipAddr = String(cString: hostname)
                        }
                    }
                }
                freeifaddrs(ifaddr)
            }
            
            DispatchQueue.main.async {
                self.wiFiRSSI = rssi
                self.wiFiTxRate = txRate
                self.wiFiChannel = channelStr
                self.wiFiIPAddress = ipAddr
                self.wiFiDetailsFetched = true
            }
        }
    }
    
    func disconnectWiFi() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let interface = CWWiFiClient.shared().interface() {
                interface.disassociate()
            }
        }
    }
    
    func fetchDynamicWiFiDetails() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let interface = CWWiFiClient.shared().interface() else { return }
            
            let rssi = interface.rssiValue()
            let txRate = interface.transmitRate()
            
            var channelStr: String? = nil
            if let channel = interface.wlanChannel() {
                let band: String
                if channel.channelBand == .band5GHz {
                    band = "5 GHz"
                } else if channel.channelBand == .band6GHz {
                    band = "6 GHz"
                } else {
                    band = "2.4 GHz"
                }
                channelStr = "Ch \(channel.channelNumber) (\(band))"
            }
            
            var ipAddr: String? = nil
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaddr) == 0 {
                var ptr = ifaddr
                while ptr != nil {
                    defer { ptr = ptr?.pointee.ifa_next }
                    let interfaceInfo = ptr?.pointee
                    if interfaceInfo?.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                        if String(cString: (interfaceInfo?.ifa_name)!) == "en0" {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(interfaceInfo?.ifa_addr, socklen_t((interfaceInfo?.ifa_addr.pointee.sa_len)!),
                                        &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                            ipAddr = String(cString: hostname)
                        }
                    }
                }
                freeifaddrs(ifaddr)
            }
            
            DispatchQueue.main.async {
                self.wiFiRSSI = rssi
                self.wiFiTxRate = txRate
                if let newChannel = channelStr {
                    self.wiFiChannel = newChannel
                }
                if let newIp = ipAddr {
                    self.wiFiIPAddress = newIp
                }
            }
        }
    }
    
    func openNetworkSettings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Network.prefPane"))
    }
    
    func openBluetoothSettings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Bluetooth.prefPane"))
    }
    
    func updateMediaInfo(title: String, artist: String, album: String, duration: Double, elapsedTime: Double, isPlaying: Bool, mediaAction: String, bundleId: String, triggerNotification: Bool) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        let isVisible = activePeripheralNotifications.contains { $0.id == "media" }
        if isVisible && !self.mediaBundleId.isEmpty && bundleId != "" && self.mediaBundleId != bundleId {
            return
        }

        if mediaTitle == title && mediaArtist == artist && mediaDuration == duration && mediaElapsedTime == elapsedTime && mediaIsPlaying == isPlaying && mediaAction == self.mediaAction {
            return
        }
        
        self.mediaTitle = title
        self.mediaArtist = artist
        self.mediaAlbum = album
        self.mediaDuration = duration
        self.mediaElapsedTime = elapsedTime
        self.mediaIsPlaying = isPlaying
        self.mediaBundleId = bundleId
        
        var finalTrigger = triggerNotification
        if finalTrigger {
            if mediaAction == "start" && !notifyMediaStart { finalTrigger = false }
            if mediaAction == "pause" && !notifyMediaPause { finalTrigger = false }
            if mediaAction == "resume" && !notifyMediaResume { finalTrigger = false }
            if mediaAction == "end" && !notifyMediaEnd { finalTrigger = false }
        }
        
        if finalTrigger {
            if let frontmostId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, !frontmostId.isEmpty, frontmostId == bundleId {
                finalTrigger = false
            } else if isAnyAppInFullScreen() {
                finalTrigger = false
            }
        }
        
        if finalTrigger {
            if mediaAction == "start" { playNotificationSound(named: soundMediaStart) }
            else if mediaAction == "pause" { playNotificationSound(named: soundMediaPause) }
            else if mediaAction == "resume" { playNotificationSound(named: soundMediaResume) }
            else if mediaAction == "end" { playNotificationSound(named: soundMediaEnd) }
        }
        
        let lastTrigger = self.overlayTriggerTimes["media"] ?? Date.distantPast
        let overlayIsActive = self.showMediaIndicator && Date().timeIntervalSince(lastTrigger) <= MediaKeyManager.notificationDuration

        if finalTrigger || !overlayIsActive {
            self.mediaAction = mediaAction
        }
        
        if finalTrigger && enableMediaNotification {
            // Show overlay
            withAnimation {
                self.showMediaIndicator = true; self.overlayTriggerTimes["media"] = Date()
                self.mediaHideTimer?.invalidate()
                if !self.globalHoveredTypes.contains("media") {
                    self.mediaHideTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { _ in
                        withAnimation {
                            self.showMediaIndicator = false
                        }
                    }
                }
            }
        }
    }
    
    func scheduleOverlayHide(for overlayId: String, delay: TimeInterval = MediaKeyManager.notificationDuration) {
        cancelOverlayHide(for: overlayId)
        
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.forceHide(overlayId: overlayId)
            }
        }
        overlayHideTimers[overlayId] = timer
    }
    
    func cancelOverlayHide(for overlayId: String) {
        overlayHideTimers[overlayId]?.invalidate()
        overlayHideTimers.removeValue(forKey: overlayId)
        
        notificationTimers[overlayId]?.invalidate()
        notificationTimers.removeValue(forKey: overlayId)
        
        // Also cancel legacy individual timers if applicable for backwards-compatibility
        switch overlayId {
        case "volume": volumeTimer?.invalidate(); volumeTimer = nil
        case "brightness": brightnessTimer?.invalidate(); brightnessTimer = nil
        case "keyboardBrightness": keyboardBrightnessTimer?.invalidate(); keyboardBrightnessTimer = nil
        case "battery", "battery_charging", "battery_warning":
            chargingTimer?.invalidate(); chargingTimer = nil
            batteryTimer?.invalidate(); batteryTimer = nil
        case "copy": copyTimer?.invalidate(); copyTimer = nil
        case "capsLock": capsLockTimer?.invalidate(); capsLockTimer = nil
        case "language": languageTimer?.invalidate(); languageTimer = nil
        case "mic": micTimer?.invalidate(); micTimer = nil
        case "camera": cameraTimer?.invalidate(); cameraTimer = nil
        case "location": locationTimer?.invalidate(); locationTimer = nil
        case "bluetooth": bluetoothTimer?.invalidate(); bluetoothTimer = nil
        case "wifi": wiFiTimer?.invalidate(); wiFiTimer = nil
        case "media":
            mediaHideTimer?.invalidate(); mediaHideTimer = nil
            mediaTimer?.invalidate(); mediaTimer = nil
        case "ram": hideRamIndicatorTask?.cancel(); hideRamIndicatorTask = nil

        
        case "theme": themeTimer?.invalidate(); themeTimer = nil
        case "focus": focusTimer?.invalidate(); focusTimer = nil
        case "accessoryBattery": accessoryBatteryTimer?.invalidate(); accessoryBatteryTimer = nil
        default: break
        }
    }
    
    func keepAlive(for type: String, isHovering: Bool) {
        if isHovering {
            globalHoveredTypes.insert(type)
        } else {
            globalHoveredTypes.remove(type)
        }
        
        let defaultDelay: TimeInterval = MediaKeyManager.notificationDuration
        
        // 1. Invalidate any active hide timer/task
        cancelOverlayHide(for: type)
        
        // 2. If finished hovering, schedule auto-hide after defaultDelay
        if !isHovering {
            scheduleOverlayHide(for: type, delay: defaultDelay)
        }
    }
    
    func setActualHover(for type: String, isHovering: Bool) {
        if isHovering {
            actualHoveredTypes.insert(type)
        } else {
            actualHoveredTypes.remove(type)
        }
    }
    
    private func isAnyAppInFullScreen() -> Bool {
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        
        let screens = NSScreen.screens
        for info in windowInfoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"] else { continue }
            
            let windowRect = NSRect(x: x, y: y, width: w, height: h)
            
            for screen in screens {
                let screenFrame = screen.frame
                if windowRect.size.width >= screenFrame.width && windowRect.size.height >= screenFrame.height {
                    if let ownerName = info[kCGWindowOwnerName as String] as? String {
                        if ownerName == "Dock" || ownerName == "Finder" || ownerName == "Window Server" {
                            continue
                        }
                        return true
                    }
                }
            }
        }
        return false
    }
    private var initialPercentageWhenPluggedIn: Int? = nil
    private var hasChargedSincePluggedIn: Bool = false
    
    func updateBatteryState(percentage: Int, pluggedIn: Bool, timeRemaining: String, cycleCount: Int = 0, healthPercentage: Int = 100, condition: String = "Normal", powerDraw: String = "0.0 W", isCharging: Bool = false) {
        if !enableBattery || isTestingBattery { return }
        let wasInitialized = self.isBatteryInitialized
        
        if pluggedIn && !self.isPluggedIn {
            self.initialPercentageWhenPluggedIn = percentage
            self.hasChargedSincePluggedIn = false
        } else if !pluggedIn {
            self.initialPercentageWhenPluggedIn = nil
            self.hasChargedSincePluggedIn = false
        }
        
        if pluggedIn, let initial = self.initialPercentageWhenPluggedIn, percentage > initial {
            self.hasChargedSincePluggedIn = true
        }
        
        if !wasInitialized && pluggedIn {
            self.hasChargedSincePluggedIn = true
        }
        
        let systemPriorLimit = self.readChargeLimit(currentCapacity: percentage)
        let isLimitReached = pluggedIn && !isCharging && percentage == systemPriorLimit && self.hasChargedSincePluggedIn
        
        var newLimit = 100
        if isLimitReached {
            newLimit = percentage
        }
        
        if self.chargeLimit != newLimit {
            self.chargeLimit = newLimit
        }
        
        let effectivelyFull = isLimitReached || (pluggedIn && !isCharging && percentage == 100)
        if self.isEffectivelyFullyCharged != effectivelyFull {
            self.isEffectivelyFullyCharged = effectivelyFull
        }
        
        if self.isPluggedIn != pluggedIn {
            self.isPluggedIn = pluggedIn
        }
        if self.currentBatteryPercentage != percentage {
            self.currentBatteryPercentage = percentage
        }
        self.batteryTimeRemaining = timeRemaining
        self.batteryCycleCount = cycleCount
        self.batteryHealthPercentage = healthPercentage
        self.batteryCondition = condition
        self.batteryPowerDraw = powerDraw
        if !wasInitialized {
            self.isBatteryInitialized = true
        }
    }
    
    func readChargeLimit(currentCapacity: Int = 0) -> Int {
        if let defaults = UserDefaults(suiteName: "com.apple.batteryui.charging.mac"),
           let limit = defaults.object(forKey: "com.apple.batteryui.charging.mac.prior.limit") as? Int,
           limit >= 50 && limit < 100 {
            return limit
        }
        return 100
    }
    
    func openBatterySettings() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["x-apple.systempreferences:com.apple.Battery-Settings.extension"]
        task.launch()
    }
    
    private var topBatteryConsumersTimer: Timer?
    
    func startFetchingTopBatteryConsumers() {
        fetchTopBatteryConsumers()
        topBatteryConsumersTimer?.invalidate()
        topBatteryConsumersTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.showLowBatteryWarning else {
                self?.topBatteryConsumersTimer?.invalidate()
                return
            }
            self.fetchTopBatteryConsumers()
        }
    }
    
    func fetchTopBatteryConsumers() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
            task.arguments = ["-l", "2", "-n", "8", "-stats", "command,power", "-o", "power"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    self.parseTopOutput(output)
                }
            } catch {
                LogManager.shared.log("Error in MediaKeyManager.swift: \(error)", level: "ERROR")
            }
        }
    }
    
    private func parseTopOutput(_ output: String) {
        let blocks = output.components(separatedBy: "COMMAND")
        guard let lastBlock = blocks.last else { return }
        
        let lines = lastBlock.components(separatedBy: .newlines)
        var results: [(String, String, NSImage?)] = []
        
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if words.count >= 2 {
                if let power = words.last, let doublePower = Double(power), doublePower > 0.0 {
                    let name = words.dropLast().joined(separator: " ")
                    if name != "top" && name != "kernel_task" && name != "WindowServer" && name != "coreaudiod" && name != "VisorPro" {
                        let icon = self.getIconForProcess(name: name)
                        results.append((name, power, icon))
                        if results.count == 4 { break }
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.topBatteryConsumers = results
        }
    }
    
    func getIconForProcess(name: String) -> NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name || $0.executableURL?.lastPathComponent == name }) {
            return app.icon
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        
        let appsURL = URL(fileURLWithPath: "/Applications")
        if let enumerator = FileManager.default.enumerator(at: appsURL, includingPropertiesForKeys: nil),
           let file = enumerator.allObjects.first(where: { ($0 as? URL)?.lastPathComponent.lowercased() == "\(name.lowercased()).app" }) as? URL {
            return NSWorkspace.shared.icon(forFile: file.path)
        }
        
        return nil
    }
    
    private var mediaKeyTap: CFMachPort?
    private var mediaKeyRunLoopSource: CFRunLoopSource?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var hasStarted = false
    private var audioRouteObserver: AudioRouteObserver?
    private var batteryObserver: BatteryObserver?
    private var wifiObserver: WiFiObserver?
    
    var copyShortcut: Shortcut = Shortcut(character: "c", modifiers: .command)
    var pasteShortcut: Shortcut = Shortcut(character: "v", modifiers: .command)
    var cutShortcut: Shortcut = Shortcut(character: "x", modifiers: .command)
    
    init() {
        if !accessoryBatteryHistory.isEmpty {
            let filtered = accessoryBatteryHistory.filter { !$0.hasSuffix(" (Lewa)") && !$0.hasSuffix(" (Prawa)") && !$0.hasSuffix(" (Etui)") }
            if filtered.count != accessoryBatteryHistory.count {
                accessoryBatteryHistory = filtered
            }
        }
        
        checkAccessibility()
        loadShortcuts()
        self.bluetoothObserver = BluetoothObserver(manager: self)
        self.audioRouteObserver = AudioRouteObserver(manager: self)
        self.chargeLimit = readChargeLimit()
        self.batteryObserver = BatteryObserver(manager: self)
        self.wifiObserver = WiFiObserver(manager: self)
        self.pasteboardObserver = PasteboardObserver(manager: self)
        self.themeObserver = ThemeObserver(manager: self)
        self.focusObserver = FocusObserver(manager: self)
        self.peripheralObserver = PeripheralObserver(manager: self)
        self.displayObserver = DisplayObserver(manager: self)
        self.btPoller = BluetoothBatteryPoller(manager: self)
        
        self.lastAction = "Gotowe!"
        VolumeManager.shared.fetchCurrentVolume { [weak self] vol, muted in
            self?.currentVolume = vol
            self?.isMuted = muted
            self?.currentAudioDeviceName = VolumeManager.shared.getCurrentAudioDeviceName()
            self?.currentMicDeviceName = VolumeManager.shared.getCurrentInputDeviceName()
        }
        
        BrightnessManager.shared.fetchCurrentBrightness { [weak self] brightness in
            self?.currentBrightness = brightness
        }
        KeyboardBrightnessManager.shared.fetchCurrentBrightness { [weak self] brightness in
            self?.currentKeyboardBrightness = brightness
        }
        
        self.mediaObserver = MediaObserver(manager: self)
        self.mediaObserver?.startObserving()
        
        self.bluetoothObserver?.startObserving()
        
        self.avObserver = AVObserver(manager: self)
        self.avObserver?.startObserving()
        
        self.locationObserver = LocationObserver(manager: self)
        self.locationObserver?.startObserving()
        
        self.cameraClientObserver = CameraClientObserver(manager: self)
        self.cameraClientObserver?.startObserving()
        
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                self.currentKeyboardLanguage = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            }
        }
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        
        syncPermissions()
    }
    
    @objc private func handleLanguageChange(_ notification: Notification) {
        if self.isSwitchingLanguageInternally { return }
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                let name = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
                self.triggerLanguageIndicator(language: name)
            }
        }
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
    
    func syncPermissions() {
        if self.enableBluetooth && !PermissionHelper.checkBluetoothPermission() {
            self.enableBluetooth = false
        }
        
        let locStatus = PermissionHelper.sharedLocationManager.authorizationStatus
        if locStatus == .denied || locStatus == .restricted {
            if self.enableWiFi { self.enableWiFi = false }
            if self.notifyOnLocationOn { self.notifyOnLocationOn = false }
        }
        
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus != .authorized && micStatus != .notDetermined {
            if UserDefaults.standard.bool(forKey: "micShowVisualizer") {
                UserDefaults.standard.set(false, forKey: "micShowVisualizer")
            }
        }
    }
    
    func start() {
        if !self.isTrusted {
            checkAccessibility()
            if !self.isTrusted {
                return
            }
        }
        

        
        let handleKeyEvent: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            
            if event.type == .flagsChanged {
                if event.keyCode == 57 { // 57 to kVK_CapsLock
                    if !self.enableKeyboard { return }
                    let isCapsOn = event.modifierFlags.contains(.capsLock)
                    DispatchQueue.main.async {
                        if !self.useSystemOSD {
                            self.lastAction = "Caps Lock: \(isCapsOn ? "On" : "Off")"
                        }
                        self.triggerCapsLockIndicator(isOn: isCapsOn)
                    }
                }
            } else if event.type == .keyDown {
                let eventModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                let char = event.charactersIgnoringModifiers?.lowercased() ?? ""
                
                if self.enableKeyboard {
                    let isCustomCopy = (eventModifiers == self.copyShortcut.modifiers && char == self.copyShortcut.character.lowercased())
                    let isNativeCopy = (eventModifiers == .command && char == "c")
                    
                    let isCustomPaste = (eventModifiers == self.pasteShortcut.modifiers && char == self.pasteShortcut.character.lowercased())
                    let isNativePaste = (eventModifiers == .command && char == "v")
                    
                    let isCustomCut = (eventModifiers == self.cutShortcut.modifiers && char == self.cutShortcut.character.lowercased())
                    let isNativeCut = (eventModifiers == .command && char == "x")
                    
                    if isCustomCopy || isNativeCopy {
                        self.pendingClipboardAction = "copy"
                        self.pendingClipboardActionTimestamp = Date()
                    } else if isCustomPaste || isNativePaste {
                        let types = NSPasteboard.general.types ?? []
                        let isFile = types.contains(.fileURL) || 
                                     types.contains(NSPasteboard.PasteboardType("public.file-url")) || 
                                     types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
                        
                        let hasCustomPaste = !(self.pasteShortcut.character == "v" && self.pasteShortcut.modifiers == .command)
                        
                        if isFile {
                            if !isNativePaste { return }
                        } else {
                            if hasCustomPaste {
                                if !isCustomPaste { return }
                            }
                        }
                        
                        if !self.canPasteInFrontmostApp() {
                            return
                        }
                        
                        self.pendingClipboardAction = "paste"
                        self.pendingClipboardActionTimestamp = Date()
                        DispatchQueue.main.async {
                            let data = self.processClipboardData(for: "paste")
                            self.triggerClipboardIndicator(text: data.text, action: "paste", app: data.app, folder: data.folder, size: data.size)
                        }
                    } else if isCustomCut || isNativeCut {
                        self.pendingClipboardAction = "cut"
                        self.pendingClipboardActionTimestamp = Date()
                    }
                }
            }
        }
        
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
            return event
        }
        

        
        
        startHardwareKeyPolling()
        
        hasStarted = true
        setupMediaKeyTap()
    }
    
    private func getFinderActiveFolder() -> String? {
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

    func processClipboardData(for action: String) -> (text: String, app: String, folder: String?, size: String) {
        let board = NSPasteboard.general
        var text = "File / Image"
        var sizeStr = ""
        var folder: String? = nil
        
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
        } else {
            sizeStr = "Unknown"
        }
        
        return (text: text, app: frontApp, folder: folder, size: sizeStr)
    }
    
    private func startHardwareKeyPolling() {
        hardwareKeyPollingTimer?.invalidate()
        hardwareKeyPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.enableKeyboard, self.isTrusted else { return }
            
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
                    self.triggerClipboardIndicator(text: data.text, action: "paste", app: data.app, folder: data.folder, size: data.size)
                }
            }
        }
    }
    
    private func enforceNotificationLimit() {
        let allNotifs = activeBluetoothNotifications + activePeripheralNotifications + activeDisplayNotifications
        let limit = max(1, maxSimultaneousNotifications)
        if allNotifs.count <= limit { return }
        
        let allowed = Array(allNotifs.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
        
        for notif in activeBluetoothNotifications where !allowed.contains(notif) {
            notificationTimers["bluetooth_\(notif.id)"]?.invalidate()
            notificationTimers.removeValue(forKey: "bluetooth_\(notif.id)")
        }
        for notif in activePeripheralNotifications where !allowed.contains(notif) {
            notificationTimers["peripheral_\(notif.id)"]?.invalidate()
            notificationTimers.removeValue(forKey: "peripheral_\(notif.id)")
        }
        for notif in activeDisplayNotifications where !allowed.contains(notif) {
            notificationTimers["display_\(notif.id)"]?.invalidate()
            notificationTimers.removeValue(forKey: "display_\(notif.id)")
        }
        
        activeBluetoothNotifications = activeBluetoothNotifications.filter { allowed.contains($0) }
        activePeripheralNotifications = activePeripheralNotifications.filter { allowed.contains($0) }
        activeDisplayNotifications = activeDisplayNotifications.filter { allowed.contains($0) }
    }
    
    func setupMediaKeyTap() {
        guard hasStarted else { return }
        
        if let tap = mediaKeyTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = mediaKeyRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        mediaKeyTap = nil
        mediaKeyRunLoopSource = nil
        
        // i nie korzystamy z systemowego OSD
        guard (enableVolume || enableBrightness || enableKeyboardBrightness || enableMediaNotification) && !useSystemOSD && self.isTrusted else {
            return
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let mediaEventMask = 1 << CGEventType(rawValue: UInt32(NX_SYSDEFINED))!.rawValue
        
        let mediaCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            let manager = Unmanaged<MediaKeyManager>.fromOpaque(refcon!).takeUnretainedValue()
            
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.mediaKeyTap {
                    if checkAXIsProcessTrustedReliably() {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    } else {
                        DispatchQueue.main.async {
                            manager.isTrusted = false
                        }
                    }
                }
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
                
                let flags = event.flags
                let isCommand = flags.contains(.maskCommand)
                let isOption = flags.contains(.maskAlternate)
                let isControl = flags.contains(.maskControl)
                
                let NX_KEYTYPE_SOUND_UP = 0
                let NX_KEYTYPE_SOUND_DOWN = 1
                let NX_KEYTYPE_BRIGHTNESS_UP = 2
                let NX_KEYTYPE_BRIGHTNESS_DOWN = 3
                let NX_KEYTYPE_MUTE = 7
                let NX_KEYTYPE_PLAY = 16
                let NX_KEYTYPE_NEXT = 17
                let NX_KEYTYPE_PREVIOUS = 18
                
                let isVolumeKey = (keyCode == NX_KEYTYPE_SOUND_UP || keyCode == NX_KEYTYPE_SOUND_DOWN || keyCode == NX_KEYTYPE_MUTE)
                let isBrightnessKey = (keyCode == NX_KEYTYPE_BRIGHTNESS_UP || keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN)
                
                // --- Passthrough: Volume wyłączony ---
                if isVolumeKey && !manager.enableVolume {
                    return Unmanaged.passRetained(event)
                }
                
                // --- Passthrough: Brightness wyłączony ---
                if isBrightnessKey && !manager.enableBrightness {
                    // Jeśli keyboard brightness jest włączony i modifier jest wciśnięty,
                    // nie robimy passthrough — niech main handler obsłuży keyboard brightness
                    let hasModifier = (manager.keyboardBrightnessModifier == "command" && isCommand) ||
                                      (manager.keyboardBrightnessModifier == "option" && isOption) ||
                                      (manager.keyboardBrightnessModifier == "control" && isControl)
                    
                    if !(manager.enableKeyboardBrightness && hasModifier) {
                        return Unmanaged.passRetained(event)
                    }
                }
                
                if keyCode == NX_KEYTYPE_PLAY || keyCode == NX_KEYTYPE_NEXT || keyCode == NX_KEYTYPE_PREVIOUS {
                    // We let the system handle the key.
                    // The MediaObserver's helper script will detect the state change
                    // and automatically trigger the UI via the notification.
                    return Unmanaged.passRetained(event)
                }
                
                if keyCode == NX_KEYTYPE_SOUND_UP || keyCode == NX_KEYTYPE_SOUND_DOWN || keyCode == NX_KEYTYPE_MUTE || keyCode == NX_KEYTYPE_BRIGHTNESS_UP || keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN {
                    if isKeyDown {
                        DispatchQueue.main.async {
                            if keyCode == NX_KEYTYPE_SOUND_UP {
                                manager.lastAction = "Volume up"
                                VolumeManager.shared.increaseVolume { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.triggerVolumeIndicator(playSound: true)
                                }
                            } else if keyCode == NX_KEYTYPE_SOUND_DOWN {
                                manager.lastAction = "Volume down"
                                VolumeManager.shared.decreaseVolume { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.triggerVolumeIndicator(playSound: true)
                                }
                            } else if keyCode == NX_KEYTYPE_MUTE {
                                VolumeManager.shared.toggleMute { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.lastAction = muted ? "Muted" : "Unmuted"
                                    manager.triggerVolumeIndicator(playSound: true)
                                }
                            } else if keyCode == NX_KEYTYPE_BRIGHTNESS_UP {
                                let hasModifier = (manager.keyboardBrightnessModifier == "command" && isCommand) ||
                                                  (manager.keyboardBrightnessModifier == "option" && isOption) ||
                                                  (manager.keyboardBrightnessModifier == "control" && isControl)
                                                  
                                if manager.enableKeyboardBrightness && hasModifier {
                                    manager.lastAction = "Keyboard brightness up"
                                    KeyboardBrightnessManager.shared.increaseBrightness { newBright in
                                        manager.currentKeyboardBrightness = newBright
                                        manager.triggerKeyboardBrightnessIndicator(playSound: true)
                                    }
                                } else {
                                    manager.lastAction = "Brightness up"
                                    BrightnessManager.shared.increaseBrightness { newBright in
                                        manager.currentBrightness = newBright
                                        manager.triggerBrightnessIndicator(playSound: true)
                                    }
                                }
                            } else if keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN {
                                let hasModifier = (manager.keyboardBrightnessModifier == "command" && isCommand) ||
                                                  (manager.keyboardBrightnessModifier == "option" && isOption) ||
                                                  (manager.keyboardBrightnessModifier == "control" && isControl)
                                                  
                                if manager.enableKeyboardBrightness && hasModifier {
                                    manager.lastAction = "Keyboard brightness down"
                                    KeyboardBrightnessManager.shared.decreaseBrightness { newBright in
                                        manager.currentKeyboardBrightness = newBright
                                        manager.triggerKeyboardBrightnessIndicator(playSound: true)
                                    }
                                } else {
                                    manager.lastAction = "Brightness down"
                                    BrightnessManager.shared.decreaseBrightness { newBright in
                                        manager.currentBrightness = newBright
                                        manager.triggerBrightnessIndicator(playSound: true)
                                    }
                                }
                            }
                        }
                        return nil
                    }
                    
                    // Przepuszczamy zdarzenie puszczenia klawisza (KeyUp) do systemu!
                    return Unmanaged.passRetained(event)
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        mediaKeyTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mediaEventMask),
            callback: mediaCallback,
            userInfo: selfPtr
        )
        
        if let tap = mediaKeyTap {
            mediaKeyRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source = mediaKeyRunLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        } else {
        }
    }
    
    private func canPasteInFrontmostApp() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return true }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var menuBar: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) != .success { return true }
        guard let menuBarElement = menuBar as! AXUIElement? else { return true }
        
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

    func stopEventTaps() {
        if let tap = mediaKeyTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = mediaKeyRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        mediaKeyTap = nil
        mediaKeyRunLoopSource = nil
        
    }
    
    func sendMediaRemoteCommand(_ commandId: Int32) {
        let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        if let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            typealias MRMediaRemoteSendCommandFunc = @convention(c) (Int32, Any?) -> Void
            let command = unsafeBitCast(pointer, to: MRMediaRemoteSendCommandFunc.self)
            command(commandId, nil)
        }
    }
    
    func setVolume(to level: Int) {
        self.currentVolume = level
        VolumeManager.shared.setVolume(to: level) { _, _ in }
    }
    
    func toggleVolumeMute() {
        self.isMuted.toggle()
        VolumeManager.shared.toggleMute { _, _ in }
    }
    
    func setBrightness(to level: Int) {
        self.currentBrightness = level
        BrightnessManager.shared.setBrightness(to: level) { _ in }
    }
    
    func setKeyboardBrightness(to level: Int) {
        self.currentKeyboardBrightness = level
        KeyboardBrightnessManager.shared.setBrightness(to: level) { _ in }
    }
    
    func simulatePlayPause() {
        sendMediaRemoteCommand(2) // togglePlayPause
    }
    
    func simulateNext() {
        sendMediaRemoteCommand(4) // nextTrack
    }
    
    func simulatePrevious() {
        sendMediaRemoteCommand(5) // previousTrack
    }
    

    func simulateSeek(to time: Double) {
        let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        if let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
            typealias MRMediaRemoteSetElapsedTimeFunc = @convention(c) (Double) -> Void
            let command = unsafeBitCast(pointer, to: MRMediaRemoteSetElapsedTimeFunc.self)
            command(time)
        }
    }
    
    func openMediaApp() {
        guard !mediaBundleId.isEmpty else { return }
        
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: mediaBundleId)
        if let app = runningApps.first {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        } else {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mediaBundleId) {
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            }
        }
    }
}



