import Cocoa
import ApplicationServices
import SwiftUI
import Combine
import IOBluetooth
import Carbon
import IOKit
import Foundation
import CoreGraphics
import IOKit.pwr_mgt
import IOKit.hid
import IOKit.hidsystem
import Carbon.HIToolbox
import CoreWLAN
import SystemConfiguration

struct KeyboardLayout: Hashable, Identifiable {
    let id: String
    let name: String
    let isSelected: Bool
}

struct Shortcut {
    let character: String
    let modifiers: NSEvent.ModifierFlags
}

struct DeviceNotification: Identifiable, Equatable {
    let id: String
    let deviceName: String
    let type: String
    let icon: String
    let isConnected: Bool
    let timestamp: Date
}

class MediaKeyManager: ObservableObject {
    static let shared = MediaKeyManager()
    static let notificationDuration: TimeInterval = 3.0
    
    @Published var lastAction: String = "Oczekuję na akcje..."
    @Published var isTrusted: Bool = false
    @Published var activeBluetoothNotifications: [DeviceNotification] = []
    @Published var activePeripheralNotifications: [DeviceNotification] = []
    private var notificationTimers: [String: Timer] = [:]
    
    @AppStorage("maxSimultaneousNotifications") var maxSimultaneousNotifications: Int = 5
    @AppStorage("overlayTheme") var overlayTheme: String = "dark"
    
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
            if !enableBattery { withAnimation { self.showLowBatteryWarning = false; self.showChargingStatus = false } }
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
    @Published var enableBluetooth: Bool = UserDefaults.standard.object(forKey: "enableBluetooth") as? Bool ?? true {
        didSet { 
            UserDefaults.standard.set(enableBluetooth, forKey: "enableBluetooth")
            if !enableBluetooth { withAnimation { self.activeBluetoothNotifications.removeAll() } }
        }
    }
    @Published var enableWiFi: Bool = UserDefaults.standard.object(forKey: "enableWiFi") as? Bool ?? true {
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
    
    @Published var notifyOnCopy: Bool = UserDefaults.standard.object(forKey: "notifyOnCopy") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCopy, forKey: "notifyOnCopy") }
    }

    @Published var soundOnCopy: String = UserDefaults.standard.string(forKey: "soundOnCopy") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCopy, forKey: "soundOnCopy") }
    }
    @Published var notifyOnCut: Bool = UserDefaults.standard.object(forKey: "notifyOnCut") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCut, forKey: "notifyOnCut") }
    }

    @Published var soundOnCut: String = UserDefaults.standard.string(forKey: "soundOnCut") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCut, forKey: "soundOnCut") }
    }
    @Published var notifyOnPaste: Bool = UserDefaults.standard.object(forKey: "notifyOnPaste") as? Bool ?? true {
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
            
            if isPluggedIn && currentBatteryPercentage == 100 && oldValue != currentBatteryPercentage {
                if notifyOn100Percent {
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
                    withAnimation(.easeInOut(duration: 0.25)) { showLowBatteryWarning = false }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.25)) { showChargingStatus = false }
                if oldValue != isPluggedIn {
                    if currentBatteryPercentage == 20 && notifyOn20Percent {
                        triggerLowBatteryWarning()
                    } else if currentBatteryPercentage == 10 && notifyOn10Percent {
                        triggerLowBatteryWarning()
                    }
                }
            }
        }
    }
    
    @Published var isBatteryInitialized: Bool = false
    
    @Published var isSimulated: Bool = false
    @Published var showLowBatteryWarning: Bool = false
    @Published var showChargingStatus: Bool = false
    @Published var batteryTimeRemaining: String = "Calculating..."
    @Published var batteryCycleCount: Int = 0
    @Published var batteryHealthPercentage: Int = 100
    @Published var batteryCondition: String = "Normal"
    @Published var batteryPowerDraw: String = "0.0 W"
    
    @Published var currentVolume: Int = 50
    @Published var isMuted: Bool = false
    @Published var showVolumeIndicator: Bool = false
    @Published var currentAudioDeviceName: String = "Volume"
    @Published var audioDevicesChanged: UUID = UUID()
    private var volumeTimer: Timer?
    
    @Published var currentBrightness: Int = 50
    @Published var showBrightnessIndicator: Bool = false
    private var brightnessTimer: Timer?
    
    @Published var currentKeyboardBrightness: Int = 50
    @Published var showKeyboardBrightnessIndicator: Bool = false
    private var keyboardBrightnessTimer: Timer?
    private var chargingTimer: Timer?
    
    // Zmienne do niezawodnego sprzętowego wykrywania skrótów schowka
    private var hardwareKeyPollingTimer: Timer?
    var detectedHardwareAction: String?
    var detectedHardwareActionTimestamp: Date?
    var lastPasteTrigger: Date?
    
    public var lastChangeCount: Int = 0
    @Published var showCopyIndicator: Bool = false
    @Published var copiedText: String = ""
    @Published var clipboardAction: String = "copy" // "copy", "cut", "paste"
    @Published var clipboardEventId: UUID = UUID()
    var pendingClipboardAction: String?
    var pendingClipboardActionTimestamp: Date?
    private var copyTimer: Timer?
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
    // Przestarzałe pojedyncze powiadomienia zastąpione przez activeBluetoothNotifications
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
    @Published var enableTheme: Bool = UserDefaults.standard.object(forKey: "enableTheme") as? Bool ?? true {
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
    
    // Privacy
    @Published var enablePrivacy: Bool = UserDefaults.standard.object(forKey: "enablePrivacy") as? Bool ?? true {
        didSet { 
            UserDefaults.standard.set(enablePrivacy, forKey: "enablePrivacy")
            if !enablePrivacy { withAnimation { self.showMicIndicator = false; self.showCameraIndicator = false } }
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
    
    @Published var showMicIndicator: Bool = false
    @Published var isMicExpanded: Bool = false
    @Published var isMicActive: Bool = false
    @Published var activeMicName: String = ""
    @Published var currentMicDeviceName: String = ""
    @Published var micEventId: UUID = UUID()
    private var micTimer: Timer?
    private var lastMicEventTime: Date = Date.distantPast
    
    @Published var showCameraIndicator: Bool = false
    @Published var isCameraExpanded: Bool = false
    @Published var isCameraActive: Bool = false
    @Published var activeCameraName: String = ""
    @Published var cameraEventId: UUID = UUID()
    private var cameraTimer: Timer?
    
    private var avObserver: AVObserver?
    
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
    
    // Przestarzałe pojedyncze powiadomienia zastąpione przez activePeripheralNotifications
    @Published var showPeripheralIndicator: Bool = false
    @Published var peripheralDeviceName: String = ""
    @Published var peripheralDeviceType: String = ""
    @Published var peripheralDeviceIcon: String = "cable.connector"
    @Published var peripheralIsConnected: Bool = false
    @Published var peripheralEventId: UUID = UUID()
    
    private var lastBluetoothEventTimeByDevice: [String: Date] = [:]
    
    private var peripheralTimer: Timer?
    private var peripheralObserver: PeripheralObserver?
    private var currentPlayingSound: NSSound?
    
    func playNotificationSound(named soundName: String) {
        if soundName == "None" || soundName.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var sound: NSSound?
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
            
            if let sound = sound {
                if sound.isPlaying {
                    sound.stop()
                    sound.currentTime = 0
                }
                self.currentPlayingSound = sound // Zatrzymanie referencji, by dźwięk zdążył się odtworzyć
                sound.play()
            }
        }
    }

    func dismissCollidingIndicators(newPosition: String, source: String) {
        // Celowo pozostawione puste, aby kafelki mogły pojawiać się jednocześnie
        // i rozsuwać na boki (zarządzane przez HStack w ContentView).
    }
    
    func triggerThemeIndicator(isDark: Bool) {
        if !enableTheme { return }
        playNotificationSound(named: isDark ? soundOnThemeDark : soundOnThemeLight)
        if isDark && !notifyOnThemeDark { return }
        if !isDark && !notifyOnThemeLight { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.themeTimer?.invalidate()
            
            let pos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "top"
            self.dismissCollidingIndicators(newPosition: pos, source: "theme")
            
            self.isDarkMode = isDark
            let executeShow = {

                self.themeEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showThemeIndicator = true

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
    
    func triggerLanguageIndicator(language: String) {
        if !enableKeyboard { return }
        if !notifyOnLanguageChange { return }
        
        playNotificationSound(named: soundOnLanguageChange)
        
        languageTimer?.invalidate()
        let pos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        dismissCollidingIndicators(newPosition: pos, source: "language")
        
        self.currentKeyboardLanguage = language
            let executeShow = {

                self.languageEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showLanguageIndicator = true

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
                    TISSelectInputSource(source)
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

    func triggerMicIndicator(isActive: Bool, deviceName: String = "") {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // ALWAYS update the underlying hardware state so AVObserver can detect future changes correctly
            self.isMicActive = isActive
            self.lastMicEventTime = Date()
            
            if isActive {
                self.activeMicName = deviceName.isEmpty ? "System Microphone" : deviceName
            }
            
            if !self.enablePrivacy { return }
            if isActive {
                if !self.notifyOnMicOn { return }
            } else {
                if !self.notifyOnMicOff { return }
            }
            
            self.playNotificationSound(named: isActive ? self.soundOnMicOn : self.soundOnMicOff)
            
            self.micTimer?.invalidate()
            let pos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
            self.dismissCollidingIndicators(newPosition: pos, source: "mic")
            withAnimation(.easeInOut(duration: 0.15)) {

            
            self.micEventId = UUID()
                self.showMicIndicator = true
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
    
    func triggerCameraIndicator(isActive: Bool, deviceName: String = "") {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // ALWAYS update the underlying hardware state so AVObserver can detect future changes correctly
            self.isCameraActive = isActive
            if isActive {
                self.activeCameraName = deviceName.isEmpty ? "Built-in Camera" : deviceName
            }
            
            if !self.enablePrivacy { return }
            if isActive {
                if !self.notifyOnCameraOn { return }
            } else {
                if !self.notifyOnCameraOff { return }
            }
            
            self.playNotificationSound(named: isActive ? self.soundOnCameraOn : self.soundOnCameraOff)
            
            self.cameraTimer?.invalidate()
            let pos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
            self.dismissCollidingIndicators(newPosition: pos, source: "camera")
            withAnimation(.easeInOut(duration: 0.15)) {

            
            self.cameraEventId = UUID()
                self.showCameraIndicator = true
            }
            
            
            if !self.isCameraExpanded {
                self.cameraTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showCameraIndicator = false
                    }
                }
            }
        }
    }
    
    private var batteryTimer: Timer?
    
    func triggerLowBatteryWarning() {
        if !enableBattery { return }
        let currentLevel = currentBatteryPercentage
        playNotificationSound(named: currentLevel <= 10 ? soundOn10Percent : soundOn20Percent)
        let battPos = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        withAnimation(.easeInOut(duration: 0.25)) { showLowBatteryWarning = true }
        
        chargingTimer?.invalidate()
        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showLowBatteryWarning = false
            }
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
        let battPos = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: battPos, source: "battery")
        
        // Wymuś odświeżenie UI poprzez krótkie zrzucenie stanu, jeśli był już aktywny
        let wasActive = showChargingStatus || showLowBatteryWarning
        if wasActive {
            withAnimation(.easeInOut(duration: 0.25)) {
                showChargingStatus = false
                showLowBatteryWarning = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showChargingStatus = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = true
            }
        }
        
        chargingTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showChargingStatus = false
            }
        }
    }
    
    func triggerPeripheralIndicator(deviceName: String, type: String, typeIcon: String, isConnected: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.enablePeripheral { return }
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
            
            let pos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "top"
            self.dismissCollidingIndicators(newPosition: pos, source: "peripheral")
            
            let newNotif = DeviceNotification(id: deviceName, deviceName: deviceName, type: type, icon: typeIcon, isConnected: isConnected, timestamp: Date())
            
            withAnimation(.easeInOut(duration: 0.15)) {
                if let idx = self.activePeripheralNotifications.firstIndex(where: { $0.id == deviceName }) {
                    self.activePeripheralNotifications[idx] = newNotif
                } else {
                    self.activePeripheralNotifications.append(newNotif)
                }
                self.enforceNotificationLimit()
            }
            
            let timerKey = "peripheral_\(deviceName)"
            self.notificationTimers[timerKey]?.invalidate()
            self.notificationTimers[timerKey] = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.activePeripheralNotifications.removeAll(where: { $0.id == deviceName })
                }
            }
        }
    }
    
    func triggerAccessoryBatteryIndicator(deviceName: String, percentage: Int, isPluggedIn: Bool, isWarning: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Zawsze aktualizuj bieżący stan, by był widoczny w ustawieniach
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
            
            self.accessoryBatteryTimer?.invalidate()
            let pos = UserDefaults.standard.string(forKey: "batteryOverlayPosition") ?? "top"
            self.dismissCollidingIndicators(newPosition: pos, source: "accessoryBattery")
            withAnimation(.easeInOut(duration: 0.15)) {

            
            self.accessoryBatteryEventId = UUID()
                self.showAccessoryBatteryIndicator = true
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
        // Pomijaj powiadomienie o głośności jeśli przed chwilą było zdarzenie Bluetooth (np. podłączono słuchawki)
        if Date().timeIntervalSince(lastBluetoothEventTime) < 2.0 { return }
        // Pomijaj powiadomienie o głośności jeśli przed chwilą zmieniono stan mikrofonu (zapobiega fałszywym powiadomieniom przy przełączaniu profili AirPods)
        if Date().timeIntervalSince(lastMicEventTime) < 2.5 { return }
        
        volumeTimer?.invalidate()
        let volPos = UserDefaults.standard.string(forKey: "volumeOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: volPos, source: "volume")
        
        withAnimation(.easeInOut(duration: 0.25)) {
            showVolumeIndicator = true
        }
        
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
        brightnessTimer?.invalidate()
        let brightPos = UserDefaults.standard.string(forKey: "brightnessOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: brightPos, source: "brightness")
        
        withAnimation(.easeInOut(duration: 0.25)) {
            showBrightnessIndicator = true
        }
        
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
        keyboardBrightnessTimer?.invalidate()
        let brightPos = UserDefaults.standard.string(forKey: "keyboardBrightnessOverlayPosition") ?? "top"
        dismissCollidingIndicators(newPosition: brightPos, source: "keyboardBrightness")
        
        withAnimation(.easeInOut(duration: 0.25)) {
            showKeyboardBrightnessIndicator = true
        }
        
        keyboardBrightnessTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showKeyboardBrightnessIndicator = false
            }
        }
    }
    
    func triggerClipboardIndicator(text: String, action: String = "copy") {
        if !enableKeyboard { return }
        if action == "copy" && !notifyOnCopy { return }
        if action == "cut" && !notifyOnCut { return }
        if action == "paste" && !notifyOnPaste { return }
        
        if action == "copy" { playNotificationSound(named: soundOnCopy) }
        else if action == "cut" { playNotificationSound(named: soundOnCut) }
        else if action == "paste" { playNotificationSound(named: soundOnPaste) }
        
        copyTimer?.invalidate()
        let copyPos = UserDefaults.standard.string(forKey: "copyOverlayPosition") ?? "bottom"
        dismissCollidingIndicators(newPosition: copyPos, source: "copy")
        
        self.copiedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clipboardAction = action
            let executeShow = {

                self.clipboardEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showCopyIndicator = true

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

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

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
        let pos = UserDefaults.standard.string(forKey: "capsLockOverlayPosition") ?? "bottom"
        dismissCollidingIndicators(newPosition: pos, source: "capsLock")
        
        self.isCapsLockOn = isOn
            let executeShow = {

                self.capsLockEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showCapsLockIndicator = true

                }

                self.capsLockTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showCapsLockIndicator = false

                    }

                }

            }

            

            if self.showCapsLockIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showCapsLockIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
    }
    
    
    func triggerBluetoothIndicator(deviceName: String, deviceAddress: String, isConnected: Bool) {
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
            return // Debounce: ignoruj to samo zdarzenie dla tego samego urządzenia w ciągu 2 sekund
        }
        lastBluetoothEventTimeByDevice[eventKey] = now
        
        let soundToPlay = isConnected ? soundOnBluetoothConnect : soundOnBluetoothDisconnect
        playNotificationSound(named: soundToPlay)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let pos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
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
            self.notificationTimers[timerKey]?.invalidate()
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.wiFiTimer?.invalidate()
            
            let pos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
            self.dismissCollidingIndicators(newPosition: pos, source: "wifi")
            
            self.wiFiSSID = ssid
            self.wiFiIsConnected = isConnected
            self.wiFiIsHotspot = isHotspot
            let executeShow = {

                self.wiFiEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showWiFiIndicator = true

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
        let isVisible = activePeripheralNotifications.contains { $0.id == "media" }
        if isVisible && !self.mediaBundleId.isEmpty && bundleId != "" && self.mediaBundleId != bundleId {
            // Ignorujemy powiadomienia z innej aplikacji, dopóki obecna nakładka nie zniknie
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
        self.mediaAction = mediaAction
        self.mediaBundleId = bundleId
        
        var finalTrigger = triggerNotification
        if finalTrigger {
            if mediaAction == "start" && !notifyMediaStart { finalTrigger = false }
            if mediaAction == "pause" && !notifyMediaPause { finalTrigger = false }
            if mediaAction == "resume" && !notifyMediaResume { finalTrigger = false }
            if mediaAction == "end" && !notifyMediaEnd { finalTrigger = false }
        }
        if finalTrigger {
            if mediaAction == "start" { playNotificationSound(named: soundMediaStart) }
            else if mediaAction == "pause" { playNotificationSound(named: soundMediaPause) }
            else if mediaAction == "resume" { playNotificationSound(named: soundMediaResume) }
            else if mediaAction == "end" { playNotificationSound(named: soundMediaEnd) }
        }
        
        if finalTrigger || !self.showMediaIndicator {
            self.mediaTitle = title
            self.mediaArtist = artist
            self.mediaAction = mediaAction
        }
        
        if finalTrigger && enableMediaNotification {
            // Show overlay
            withAnimation {
                self.showMediaIndicator = true
                self.mediaHideTimer?.invalidate()
                self.mediaHideTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { _ in
                    withAnimation {
                        self.showMediaIndicator = false
                    }
                }
            }
        }
    }
    
    func keepAlive(for type: String, isHovering: Bool) {
        let defaultDelay: TimeInterval = MediaKeyManager.notificationDuration
        
        if type.hasPrefix("peripheral_") {
            let deviceName = String(type.dropFirst("peripheral_".count))
            notificationTimers[type]?.invalidate()
            if !isHovering {
                notificationTimers[type] = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.activePeripheralNotifications.removeAll(where: { $0.id == deviceName })
                    }
                }
            }
            return
        }
        
        if type.hasPrefix("bluetooth_") {
            let deviceId = String(type.dropFirst("bluetooth_".count))
            notificationTimers[type]?.invalidate()
            if !isHovering {
                notificationTimers[type] = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.activeBluetoothNotifications.removeAll(where: { $0.id == deviceId })
                    }
                }
            }
            return
        }
        
        switch type {
        case "volume":
            volumeTimer?.invalidate()
            if !isHovering {
                volumeTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showVolumeIndicator = false }
                }
            }
        case "brightness":
            brightnessTimer?.invalidate()
            if !isHovering {
                brightnessTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showBrightnessIndicator = false }
                }
            }
        case "keyboardBrightness":
            keyboardBrightnessTimer?.invalidate()
            if !isHovering {
                keyboardBrightnessTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showKeyboardBrightnessIndicator = false }
                }
            }
        case "battery":
            chargingTimer?.invalidate()
            batteryTimer?.invalidate()
            if !isHovering {
                chargingTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { 
                        self?.showChargingStatus = false
                        self?.showLowBatteryWarning = false
                    }
                }
            }
        case "copy":
            copyTimer?.invalidate()
            if !isHovering {
                copyTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showCopyIndicator = false }
                }
            }
        case "capsLock":
            capsLockTimer?.invalidate()
            if !isHovering {
                capsLockTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showCapsLockIndicator = false }
                }
            }
        case "language":
            languageTimer?.invalidate()
            if !isHovering {
                languageTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showLanguageIndicator = false }
                }
            }
        case "mic":
            micTimer?.invalidate()
            if !isHovering {
                micTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showMicIndicator = false }
                }
            }
        case "camera":
            cameraTimer?.invalidate()
            if !isHovering {
                cameraTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showCameraIndicator = false }
                }
            }
        case "bluetooth":
            bluetoothTimer?.invalidate()
            if !isHovering {
                bluetoothTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showBluetoothIndicator = false }
                }
            }
        case "wifi":
            wiFiTimer?.invalidate()
            if !isHovering {
                wiFiTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showWiFiIndicator = false }
                }
            }
        case "media":
            mediaHideTimer?.invalidate()
            if !isHovering {
                mediaHideTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showMediaIndicator = false }
                }
            }
        case "theme":
            themeTimer?.invalidate()
            if !isHovering {
                themeTimer = Timer.scheduledTimer(withTimeInterval: defaultDelay, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) { self?.showThemeIndicator = false }
                }
            }
        default: break
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
    
    func triggerMediaIndicator() {
        if !enableMediaNotification { return }
        if isAnyAppInFullScreen() { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.mediaTimer?.invalidate()
            
            let pos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
            self.dismissCollidingIndicators(newPosition: pos, source: "media")
            let executeShow = {

                self.mediaEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showMediaIndicator = true

                }

                self.mediaTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showMediaIndicator = false

                    }

                }

            }

            

            if self.showMediaIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showMediaIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
        }
    }
    
    func updateBatteryState(percentage: Int, pluggedIn: Bool, timeRemaining: String, cycleCount: Int = 0, healthPercentage: Int = 100, condition: String = "Normal", powerDraw: String = "0.0 W") {
        if !enableBattery { return }
        let wasInitialized = self.isBatteryInitialized
        self.isPluggedIn = pluggedIn
        self.currentBatteryPercentage = percentage
        self.batteryTimeRemaining = timeRemaining
        self.batteryCycleCount = cycleCount
        self.batteryHealthPercentage = healthPercentage
        self.batteryCondition = condition
        self.batteryPowerDraw = powerDraw
        if !wasInitialized {
            self.isBatteryInitialized = true
        }
    }
    
    func refreshBatteryState() {
        batteryObserver?.refresh()
    }
    
    func openBatterySettings() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["x-apple.systempreferences:com.apple.Battery-Settings.extension"]
        task.launch()
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
        // Cleanup starej historii z polskimi końcówkami
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
        self.batteryObserver = BatteryObserver(manager: self)
        self.wifiObserver = WiFiObserver(manager: self)
        self.pasteboardObserver = PasteboardObserver(manager: self)
        self.themeObserver = ThemeObserver(manager: self)
        self.peripheralObserver = PeripheralObserver(manager: self)
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
        
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                self.currentKeyboardLanguage = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            }
        }
        
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main) { [weak self] _ in
            if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
                if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                    let name = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
                    self?.triggerLanguageIndicator(language: name)
                }
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
    
    func start() {
        if !self.isTrusted {
            checkAccessibility()
            if !self.isTrusted {
                return
            }
        }
        

        
        // === TAP 1: Listen-only – klawiatura (Caps Lock + skróty schowka) ===
        // Zamiast CGEventTap używamy NSEvent monitorów (globalnego i lokalnego), 
        // które są w 100% niezawodne, nie blokują klawiszy i omijają problemy z cachem Dostępności w macOS.
        let handleKeyEvent: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            
            if event.type == .flagsChanged {
                if event.keyCode == 57 { // 57 to kVK_CapsLock
                    if !self.enableKeyboard { return }
                    let isCapsOn = event.modifierFlags.contains(.capsLock)
                    DispatchQueue.main.async {
                        if !self.useSystemOSD {
                            self.lastAction = "Caps Lock: \(isCapsOn ? "Wł." : "Wył.")"
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            let text = NSPasteboard.general.string(forType: .string) ?? "Skopiowany plik"
                            self.triggerClipboardIndicator(text: text, action: "copy")
                        }
                    } else if isCustomPaste || isNativePaste {
                        let types = NSPasteboard.general.types ?? []
                        let isFile = types.contains(.fileURL) || 
                                     types.contains(NSPasteboard.PasteboardType("public.file-url")) || 
                                     types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
                        
                        if isFile {
                            if isCustomPaste && !isNativePaste { return }
                        } else {
                            if isNativePaste && !isCustomPaste { return }
                        }
                        
                        if !self.canPasteInFrontmostApp() {
                            return
                        }
                        
                        self.pendingClipboardAction = "paste"
                        self.pendingClipboardActionTimestamp = Date()
                        DispatchQueue.main.async {
                            let text = NSPasteboard.general.string(forType: .string) ?? "Wklejony plik"
                            self.triggerClipboardIndicator(text: text, action: "paste")
                        }
                    } else if isCustomCut || isNativeCut {
                        self.pendingClipboardAction = "cut"
                        self.pendingClipboardActionTimestamp = Date()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            let text = NSPasteboard.general.string(forType: .string) ?? "Wycięty plik"
                            self.triggerClipboardIndicator(text: text, action: "cut")
                        }
                    }
                }
            }
        }
        
        // Nasłuch globalny (gdy inna aplikacja jest aktywna)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
        }
        
        // Nasłuch lokalny (gdy VisorPro jest aktywny/na wierzchu)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
            return event // Zwracamy event, by nie blokować jego przetwarzania
        }
        

        
        // === TAP 2: Active tap – media keys (głośność + jasność) ===
        // Tworzony dynamicznie – istnieje TYLKO gdy Volume lub Brightness jest włączone.
        // Gdy oba wyłączone, tap jest usuwany i macOS obsługuje klawisze w 100% natywnie.
        
        startHardwareKeyPolling()
        
        hasStarted = true
        setupMediaKeyTap()
    }
    
    private func startHardwareKeyPolling() {
        hardwareKeyPollingTimer?.invalidate()
        hardwareKeyPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.enableKeyboard else { return }
            
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
                
                // Dla wklejania wywołujemy OSD bezpośrednio, bo schowek może się nie zmienić (PasteboardObserver nie zadziała)
                if let last = self.lastPasteTrigger, Date().timeIntervalSince(last) < 1.0 { return }
                
                // Sprawdzamy czy okno pozwala na wklejanie, żeby uniknąć fałszywych alarmów (np. Finder bez aktywnej zmiany nazwy)
                if !self.canPasteInFrontmostApp() { return }
                
                self.lastPasteTrigger = Date()
                DispatchQueue.main.async {
                    let text = NSPasteboard.general.string(forType: .string) ?? "Wklejony plik"
                    self.triggerClipboardIndicator(text: text, action: "paste")
                }
            }
        }
    }
    
    private func enforceNotificationLimit() {
        let allNotifs = activeBluetoothNotifications + activePeripheralNotifications
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
        
        activeBluetoothNotifications = activeBluetoothNotifications.filter { allowed.contains($0) }
        activePeripheralNotifications = activePeripheralNotifications.filter { allowed.contains($0) }
    }
    
    /// Tworzy lub usuwa aktywny Event Tap dla klawiszy głośności/jasności.
    /// Wywoływane automatycznie przy zmianie enableVolume, enableBrightness lub useSystemOSD.
    func setupMediaKeyTap() {
        guard hasStarted else { return }
        
        // Usuń istniejący tap
        if let tap = mediaKeyTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = mediaKeyRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        mediaKeyTap = nil
        mediaKeyRunLoopSource = nil
        
        // Twórz aktywny tap TYLKO gdy co najmniej jeden moduł media jest włączony
        // i nie korzystamy z systemowego OSD
        guard (enableVolume || enableBrightness || enableMediaNotification) && !useSystemOSD else {
            return
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let mediaEventMask = 1 << CGEventType(rawValue: UInt32(NX_SYSDEFINED))!.rawValue
        
        let mediaCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            let manager = Unmanaged<MediaKeyManager>.fromOpaque(refcon!).takeUnretainedValue()
            
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.mediaKeyTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
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
                
                // Jeśli moduł jest wyłączony – przepuść zdarzenie do systemu
                if keyCode == NX_KEYTYPE_SOUND_UP || keyCode == NX_KEYTYPE_SOUND_DOWN || keyCode == NX_KEYTYPE_MUTE {
                    if !manager.enableVolume {
                        return Unmanaged.passRetained(event)
                    }
                }
                
                if keyCode == NX_KEYTYPE_BRIGHTNESS_UP || keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN {
                    if !manager.enableBrightness {
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
                                manager.lastAction = "Zwiększanie głośności"
                                VolumeManager.shared.increaseVolume { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.triggerVolumeIndicator(playSound: true)
                                }
                            } else if keyCode == NX_KEYTYPE_SOUND_DOWN {
                                manager.lastAction = "Zmniejszanie głośności"
                                VolumeManager.shared.decreaseVolume { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.triggerVolumeIndicator(playSound: true)
                                }
                            } else if keyCode == NX_KEYTYPE_MUTE {
                                VolumeManager.shared.toggleMute { vol, muted in
                                    manager.currentVolume = vol
                                    manager.isMuted = muted
                                    manager.lastAction = muted ? "Wyciszono dźwięk" : "Włączono dźwięk"
                                    manager.triggerVolumeIndicator(playSound: true)
                                }
                            } else if keyCode == NX_KEYTYPE_BRIGHTNESS_UP {
                                let hasModifier = (manager.keyboardBrightnessModifier == "command" && isCommand) ||
                                                  (manager.keyboardBrightnessModifier == "option" && isOption) ||
                                                  (manager.keyboardBrightnessModifier == "control" && isControl)
                                                  
                                if manager.enableKeyboardBrightness && hasModifier {
                                    manager.lastAction = "Zwiększanie jasności klawiatury"
                                    KeyboardBrightnessManager.shared.increaseBrightness { newBright in
                                        manager.currentKeyboardBrightness = newBright
                                        manager.triggerKeyboardBrightnessIndicator(playSound: true)
                                    }
                                } else {
                                    manager.lastAction = "Zwiększanie jasności"
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
                                    manager.lastAction = "Zmniejszanie jasności klawiatury"
                                    KeyboardBrightnessManager.shared.decreaseBrightness { newBright in
                                        manager.currentKeyboardBrightness = newBright
                                        manager.triggerKeyboardBrightnessIndicator(playSound: true)
                                    }
                                } else {
                                    manager.lastAction = "Zmniejszanie jasności"
                                    BrightnessManager.shared.decreaseBrightness { newBright in
                                        manager.currentBrightness = newBright
                                        manager.triggerBrightnessIndicator(playSound: true)
                                    }
                                }
                            }
                        }
                    }
                    // Blokuj zdarzenie – VisorPro obsługuje głośność/jasność samodzielnie
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        mediaKeyTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
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
                
                for subItem in items {
                    var subTitle: CFTypeRef?
                    if AXUIElementCopyAttributeValue(subItem, kAXTitleAttribute as CFString, &subTitle) != .success { continue }
                    if let subStr = subTitle as? String, (subStr.contains("Paste") || subStr.contains("Wklej")) {
                        var enabled: CFTypeRef?
                        if AXUIElementCopyAttributeValue(subItem, kAXEnabledAttribute as CFString, &enabled) == .success {
                            if let isEnabled = enabled as? Bool {
                                return isEnabled
                            }
                        }
                        return true // Fallback
                    }
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
        guard let manager = manager, manager.enableKeyboard else { return }
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // Jeśli właśnie nacisnęliśmy skrót klawiszowy (Cmd+C/X/V), OSD zostało już wyświetlone bezpośrednio.
            // Ignorujemy tę zmianę schowka, żeby nie nadpisać OSD domyślnym "Skopiowano".
            if let timestamp = manager.pendingClipboardActionTimestamp,
               Date().timeIntervalSince(timestamp) < 1.5 {
                return
            }
            
            // W przeciwnym razie (np. kopiowanie myszką) domyślnie zakładamy kopiowanie
            var action = "copy" 
            
            if let hwAction = manager.detectedHardwareAction,
               let hwTimestamp = manager.detectedHardwareActionTimestamp,
               Date().timeIntervalSince(hwTimestamp) < 1.5 {
                action = hwAction
            }
            
            // Sprawdzamy czy w schowku jest tekst
            if let copiedText = NSPasteboard.general.string(forType: .string) {
                DispatchQueue.main.async {
                    manager.triggerClipboardIndicator(text: copiedText, action: action)
                }
            } else {
                // Skopiowano coś innego, np. plik lub obrazek
                DispatchQueue.main.async {
                    manager.triggerClipboardIndicator(text: "Plik / Obraz", action: action)
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

class ThemeObserver {
    private weak var manager: MediaKeyManager?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
    }
    
    private func startObserving() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(themeChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    @objc private func themeChanged() {
        // Evaluate the new theme
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        manager?.triggerThemeIndicator(isDark: isDark)
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}

class PeripheralObserver {
    private weak var manager: MediaKeyManager?
    private var notifyPort: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        startObserving()
    }
    
    private func startObserving() {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else { return }
        runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        let matchDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        let matchDictRemove = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        // Match Add
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchDict,
            { context, iterator in
                let mySelf = Unmanaged<PeripheralObserver>.fromOpaque(context!).takeUnretainedValue()
                mySelf.deviceAdded(iterator: iterator)
            },
            selfPtr,
            &addedIterator
        )
        deviceAdded(iterator: addedIterator, initial: true)
        
        // Match Remove
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchDictRemove,
            { context, iterator in
                let mySelf = Unmanaged<PeripheralObserver>.fromOpaque(context!).takeUnretainedValue()
                mySelf.deviceRemoved(iterator: iterator)
            },
            selfPtr,
            &removedIterator
        )
        deviceRemoved(iterator: removedIterator, initial: true)
    }
    
    private func deviceAdded(iterator: io_iterator_t, initial: Bool = false) {
        while case let device = IOIteratorNext(iterator), device != 0 {
            if !initial {
                handleDevice(device: device, isConnected: true)
            }
            IOObjectRelease(device)
        }
    }
    
    private func deviceRemoved(iterator: io_iterator_t, initial: Bool = false) {
        while case let device = IOIteratorNext(iterator), device != 0 {
            if !initial {
                handleDevice(device: device, isConnected: false)
            }
            IOObjectRelease(device)
        }
    }
    
    private func handleDevice(device: io_object_t, isConnected: Bool) {
        var nameCString = [CChar](repeating: 0, count: 256)
        let result = IORegistryEntryGetName(device, &nameCString)
        if result == KERN_SUCCESS {
            let name = String(cString: nameCString)
            
            // Ignore generic host controllers or roots
            if name.lowercased().contains("root hub") { return }
            
            var type = "USB Device"
            var typeIcon = "cable.connector"
            
            if let cfClass = IORegistryEntryCreateCFProperty(device, "bDeviceClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                let devClass = cfClass.intValue
                if devClass == 9 {
                    type = "USB Hub"
                    typeIcon = "point.3.connected.trianglepath.dotted"
                } else if devClass == 8 {
                    type = "USB Drive"
                    typeIcon = "externaldrive"
                } else if devClass == 3 {
                    type = "HID Device"
                    typeIcon = "keyboard"
                }
            }
            
            let lowerName = name.lowercased()
            if lowerName.contains("keyboard") || lowerName.contains("keychron") {
                type = "Keyboard"
                typeIcon = "keyboard"
            } else if lowerName.contains("mouse") || lowerName.contains("receiver") || lowerName.contains("logi") {
                type = "Mouse"
                typeIcon = "magicmouse"
            } else if lowerName.contains("hub") {
                type = "USB Hub"
                typeIcon = "point.3.connected.trianglepath.dotted"
            } else if lowerName.contains("drive") || lowerName.contains("sandisk") || lowerName.contains("ssd") {
                type = "USB Drive"
                typeIcon = "externaldrive"
            } else if lowerName.contains("audio") || lowerName.contains("mic") {
                type = "Audio Device"
                typeIcon = "headphones"
            }
            
            // If the name is something generic like "USB2.0 Hub", we rely on the type.
            let displayName = name.count > 0 ? name : type
            
            manager?.triggerPeripheralIndicator(deviceName: displayName, type: type, typeIcon: typeIcon, isConnected: isConnected)
        }
    }
    
    deinit {
        if let notifyPort = notifyPort {
            IONotificationPortDestroy(notifyPort)
        }
        if addedIterator != 0 { IOObjectRelease(addedIterator) }
        if removedIterator != 0 { IOObjectRelease(removedIterator) }
    }
}
