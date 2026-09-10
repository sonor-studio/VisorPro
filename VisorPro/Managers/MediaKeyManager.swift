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











extension Notification.Name {
    /// Posted when overlay visibility changes (show/hide). Used by VisorProWindowManager
    /// instead of subscribing to MediaKeyManager.objectWillChange (which fires too broadly).
    static let visorProOverlayStateChanged = Notification.Name("VisorProOverlayStateChanged")
}

class MediaKeyManager: ObservableObject {
    @AppStorage("overlayColorMode") var overlayColorMode: String = "preset_default"
    @AppStorage("globalOverlayColor") var globalOverlayColor: String = "Default"
    @AppStorage("colorOnVolume") var colorOnVolume: String = "Default"
    @AppStorage("colorOnBrightness") var colorOnBrightness: String = "Default"
    @AppStorage("colorOnKeyboardBrightness") var colorOnKeyboardBrightness: String = "Default"
    @AppStorage("colorOnCopy") var colorOnCopy: String = "Default"
    @AppStorage("colorOnCut") var colorOnCut: String = "Default"
    @AppStorage("colorOnPaste") var colorOnPaste: String = "Default"
    @AppStorage("colorOnCapsLock") var colorOnCapsLock: String = "Default"
    @AppStorage("colorOnLanguageChange") var colorOnLanguageChange: String = "Default"
    @AppStorage("colorOnThemeDark") var colorOnThemeDark: String = "Default"
    @AppStorage("colorOnThemeLight") var colorOnThemeLight: String = "Default"
    @AppStorage("colorMediaStart") var colorMediaStart: String = "Default"
    @AppStorage("colorMediaPause") var colorMediaPause: String = "Default"
    @AppStorage("colorMediaResume") var colorMediaResume: String = "Default"
    @AppStorage("colorMediaEnd") var colorMediaEnd: String = "Default"
    @AppStorage("colorOnHighRam") var colorOnHighRam: String = "Default"
    @AppStorage("colorOnWiFiConnect") var colorOnWiFiConnect: String = "Default"
    @AppStorage("colorOnBluetoothConnect") var colorOnBluetoothConnect: String = "Default"
    @AppStorage("colorOnPeripheralConnect") var colorOnPeripheralConnect: String = "Default"
    @AppStorage("colorOnMicOn") var colorOnMicOn: String = "Default"
    @AppStorage("colorOnCameraOn") var colorOnCameraOn: String = "Default"
    @AppStorage("colorOnLocationOn") var colorOnLocationOn: String = "Default"
    @AppStorage("colorOnDisplayConnect") var colorOnDisplayConnect: String = "Default"
    @AppStorage("colorOnDisplayModeChange") var colorOnDisplayModeChange: String = "Default"
    
    func resetColorsToDefault() {
        overlayColorMode = "preset_default"
        globalOverlayColor = "Default"
        colorOnVolume = "Default"
        colorOnBrightness = "Default"
        colorOnKeyboardBrightness = "Default"
        colorOnCopy = "Default"
        colorOnCut = "Default"
        colorOnPaste = "Default"
        colorOnCapsLock = "Default"
        colorOnLanguageChange = "Default"
        colorOnThemeDark = "Default"
        colorOnThemeLight = "Default"
        colorMediaStart = "Default"
        colorMediaPause = "Default"
        colorMediaResume = "Default"
        colorMediaEnd = "Default"
        colorOnHighRam = "Default"
        colorOnWiFiConnect = "Default"
        colorOnBluetoothConnect = "Default"
        colorOnPeripheralConnect = "Default"
        colorOnMicOn = "Default"
        colorOnCameraOn = "Default"
        colorOnLocationOn = "Default"
        colorOnDisplayConnect = "Default"
        colorOnDisplayModeChange = "Default"
    }
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
    
    var lastAction: String {
        get { OverlayStateRelay.shared.lastAction }
        set { OverlayStateRelay.shared.lastAction = newValue }
    }
    @Published var isTrusted: Bool = false {
        didSet {
            if oldValue != isTrusted {
                DispatchQueue.main.async {
                    self.setupMediaKeyTap()
                }
            }
        }
    }
    var activeBluetoothNotifications: [DeviceNotification] {
        get { OverlayStateRelay.shared.activeBluetoothNotifications }
        set { OverlayStateRelay.shared.activeBluetoothNotifications = newValue }
    }
    var activePeripheralNotifications: [DeviceNotification] {
        get { OverlayStateRelay.shared.activePeripheralNotifications }
        set { OverlayStateRelay.shared.activePeripheralNotifications = newValue }
    }
    var activeDisplayNotifications: [DeviceNotification] {
        get { OverlayStateRelay.shared.activeDisplayNotifications }
        set { OverlayStateRelay.shared.activeDisplayNotifications = newValue }
    }    // MARK: - Bridge properties → OverlayStateRelay (no longer @Published here)
    // These delegate to OverlayStateRelay so changes don't fire MediaKeyManager.objectWillChange,
    // preventing dashboard re-renders on every swipe/hover event.
    var swipeOffsets: [String: CGFloat] {
        get { OverlayStateRelay.shared.swipeOffsets }
        set { OverlayStateRelay.shared.swipeOffsets = newValue }
    }
    var isHoveringScrollView: Bool {
        get { OverlayStateRelay.shared.isHoveringScrollView }
        set { OverlayStateRelay.shared.isHoveringScrollView = newValue }
    }
    var activeSwipeIds: Set<String> {
        get { OverlayStateRelay.shared.activeSwipeIds }
        set { OverlayStateRelay.shared.activeSwipeIds = newValue }
    }
    var notificationTimers: [String: Timer] = [:]
    private var overlayHideTimers: [String: Timer] = [:]
    
    var overlayTriggerTimes: [String: Date] = [:]
    
    var lastDisplayConnectionTime: Date? = nil
    
    @AppStorage("maxSimultaneousNotifications") var maxSimultaneousNotifications: Int = 5
    @AppStorage("clipboardEnableHistory") var clipboardEnableHistory: Bool = true
    @AppStorage("clipboardKeepExpandedOnPaste") var clipboardKeepExpandedOnPaste: Bool = false
    @Published var mediaSkipDuration: Double = {
        let val = UserDefaults.standard.object(forKey: "mediaSkipDuration")
        return (val as? NSNumber)?.doubleValue ?? 10.0
    }() {
        didSet {
            UserDefaults.standard.set(mediaSkipDuration, forKey: "mediaSkipDuration")
        }
    }
    @AppStorage("overlayTheme") var overlayTheme: String = "system"
    var globalHoveredTypes: Set<String> {
        get { OverlayStateRelay.shared.globalHoveredTypes }
        set { OverlayStateRelay.shared.globalHoveredTypes = newValue }
    }
    var actualHoveredTypes: Set<String> {
        get { OverlayStateRelay.shared.actualHoveredTypes }
        set { OverlayStateRelay.shared.actualHoveredTypes = newValue }
    }    
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
    @Published var notifyOnCapsLockOn: Bool = UserDefaults.standard.object(forKey: "notifyOnCapsLockOn") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCapsLockOn, forKey: "notifyOnCapsLockOn") }
    }
    @Published var notifyOnCapsLockOff: Bool = UserDefaults.standard.object(forKey: "notifyOnCapsLockOff") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnCapsLockOff, forKey: "notifyOnCapsLockOff") }
    }
    @Published var soundOnCapsLockOff: String = UserDefaults.standard.string(forKey: "soundOnCapsLockOff") ?? "Default" {
        didSet { UserDefaults.standard.set(soundOnCapsLockOff, forKey: "soundOnCapsLockOff") }
    }


    @Published var soundOnCapsLock: String = UserDefaults.standard.string(forKey: "soundOnCapsLock") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnCapsLock, forKey: "soundOnCapsLock") }
    }

    var currentBatteryPercentage: Int {
        get { OverlayStateRelay.shared.currentBatteryPercentage }
        set { 
            let oldValue = OverlayStateRelay.shared.currentBatteryPercentage
            OverlayStateRelay.shared.currentBatteryPercentage = newValue
            
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
    
    var isPluggedIn: Bool {
        get { OverlayStateRelay.shared.isPluggedIn }
        set { 
            let oldValue = OverlayStateRelay.shared.isPluggedIn
            OverlayStateRelay.shared.isPluggedIn = newValue
            
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
    
    var isBatteryInitialized: Bool {
        get { OverlayStateRelay.shared.isBatteryInitialized }
        set { OverlayStateRelay.shared.isBatteryInitialized = newValue }
    }    
    var isSimulated: Bool {
        get { OverlayStateRelay.shared.isSimulated }
        set { OverlayStateRelay.shared.isSimulated = newValue }
    }
    var showLowBatteryWarning: Bool {
        get { OverlayStateRelay.shared.showLowBatteryWarning }
        set { OverlayStateRelay.shared.showLowBatteryWarning = newValue }
    }
    var showChargingStatus: Bool {
        get { OverlayStateRelay.shared.showChargingStatus }
        set { OverlayStateRelay.shared.showChargingStatus = newValue }
    }
    var showUnpluggedStatus: Bool {
        get { OverlayStateRelay.shared.showUnpluggedStatus }
        set { OverlayStateRelay.shared.showUnpluggedStatus = newValue }
    }
    var batteryTimeRemaining: String {
        get { OverlayStateRelay.shared.batteryTimeRemaining }
        set { OverlayStateRelay.shared.batteryTimeRemaining = newValue }
    }
    var batteryCycleCount: Int {
        get { OverlayStateRelay.shared.batteryCycleCount }
        set { OverlayStateRelay.shared.batteryCycleCount = newValue }
    }
    var batteryHealthPercentage: Int {
        get { OverlayStateRelay.shared.batteryHealthPercentage }
        set { OverlayStateRelay.shared.batteryHealthPercentage = newValue }
    }
    var batteryCondition: String {
        get { OverlayStateRelay.shared.batteryCondition }
        set { OverlayStateRelay.shared.batteryCondition = newValue }
    }
    var batteryPowerDraw: String {
        get { OverlayStateRelay.shared.batteryPowerDraw }
        set { OverlayStateRelay.shared.batteryPowerDraw = newValue }
    }
    var chargeLimit: Int {
        get { OverlayStateRelay.shared.chargeLimit }
        set { OverlayStateRelay.shared.chargeLimit = newValue }
    }
    @Published var topBatteryConsumers: [(name: String, power: String, icon: NSImage?)] = []
    var isEffectivelyFullyCharged: Bool {
        get { OverlayStateRelay.shared.isEffectivelyFullyCharged }
        set { 
            let oldValue = OverlayStateRelay.shared.isEffectivelyFullyCharged
            OverlayStateRelay.shared.isEffectivelyFullyCharged = newValue
            
            if !isBatteryInitialized { return }
            if isEffectivelyFullyCharged && !oldValue && notifyOn100Percent {
                triggerChargingStatus()
            }
        
        }
    }
    
    var currentVolume: Int {
        get { OverlayStateRelay.shared.currentVolume }
        set { OverlayStateRelay.shared.currentVolume = newValue }
    }
    var isMuted: Bool {
        get { OverlayStateRelay.shared.isMuted }
        set { OverlayStateRelay.shared.isMuted = newValue }
    }
    var showVolumeIndicator: Bool {
        get { OverlayStateRelay.shared.showVolumeIndicator }
        set { OverlayStateRelay.shared.showVolumeIndicator = newValue }
    }
    var currentAudioDeviceName: String {
        get { OverlayStateRelay.shared.currentAudioDeviceName }
        set { OverlayStateRelay.shared.currentAudioDeviceName = newValue }
    }
    var audioDevicesChanged: UUID {
        get { OverlayStateRelay.shared.audioDevicesChanged }
        set { OverlayStateRelay.shared.audioDevicesChanged = newValue }
    }
    var forceSingleScreenForDisplayTransition: Bool {
        get { OverlayStateRelay.shared.forceSingleScreenForDisplayTransition }
        set { OverlayStateRelay.shared.forceSingleScreenForDisplayTransition = newValue }
    }
    var isDisplayTransitioning: Bool {
        get { OverlayStateRelay.shared.isDisplayTransitioning }
        set { OverlayStateRelay.shared.isDisplayTransitioning = newValue }
    }
    var volumeTimer: Timer?
    
    var currentBrightness: Int {
        get { OverlayStateRelay.shared.currentBrightness }
        set { OverlayStateRelay.shared.currentBrightness = newValue }
    }
    var showBrightnessIndicator: Bool {
        get { OverlayStateRelay.shared.showBrightnessIndicator }
        set { OverlayStateRelay.shared.showBrightnessIndicator = newValue }
    }
    var brightnessTimer: Timer?
    
    var currentKeyboardBrightness: Int {
        get { OverlayStateRelay.shared.currentKeyboardBrightness }
        set { OverlayStateRelay.shared.currentKeyboardBrightness = newValue }
    }
    var showKeyboardBrightnessIndicator: Bool {
        get { OverlayStateRelay.shared.showKeyboardBrightnessIndicator }
        set { OverlayStateRelay.shared.showKeyboardBrightnessIndicator = newValue }
    }
    var keyboardBrightnessTimer: Timer?
    var chargingTimer: Timer?
    
    var hardwareKeyPollingTimer: Timer?
    var detectedHardwareAction: String?
    var detectedHardwareActionTimestamp: Date?
    var lastPasteTrigger: Date?
    
    public var lastChangeCount: Int = 0
    var showCopyIndicator: Bool {
        get { OverlayStateRelay.shared.showCopyIndicator }
        set { OverlayStateRelay.shared.showCopyIndicator = newValue }
    }    
    
    // RAM Monitoring
    


    var showRamIndicator: Bool {
        get { OverlayStateRelay.shared.showRamIndicator }
        set { OverlayStateRelay.shared.showRamIndicator = newValue }
    }
    @Published var ramEventId = UUID()
    var hideRamIndicatorTask: DispatchWorkItem?
    var ramUsagePercent: Double {
        get { OverlayStateRelay.shared.ramUsagePercent }
        set { OverlayStateRelay.shared.ramUsagePercent = newValue }
    }
    var totalRamGB: Double {
        get { OverlayStateRelay.shared.totalRamGB }
        set { OverlayStateRelay.shared.totalRamGB = newValue }
    }
    var usedRamGB: Double {
        get { OverlayStateRelay.shared.usedRamGB }
        set { OverlayStateRelay.shared.usedRamGB = newValue }
    }
    var ramUsageHistory: [Double] {
        get { OverlayStateRelay.shared.ramUsageHistory }
        set { OverlayStateRelay.shared.ramUsageHistory = newValue }
    }
    @Published var ramTopProcesses: [(name: String, ramGB: Double, icon: NSImage?)] = []

    var copiedText: String {
        get { OverlayStateRelay.shared.copiedText }
        set { OverlayStateRelay.shared.copiedText = newValue }
    }
    var clipboardAction: String {
        get { OverlayStateRelay.shared.clipboardAction }
        set { OverlayStateRelay.shared.clipboardAction = newValue }
    }
    var clipboardEventId: UUID {
        get { OverlayStateRelay.shared.clipboardEventId }
        set { OverlayStateRelay.shared.clipboardEventId = newValue }
    }
    var clipboardSourceApp: String {
        get { OverlayStateRelay.shared.clipboardSourceApp }
        set { OverlayStateRelay.shared.clipboardSourceApp = newValue }
    }
    var clipboardSourceFolder: String? {
        get { OverlayStateRelay.shared.clipboardSourceFolder }
        set { OverlayStateRelay.shared.clipboardSourceFolder = newValue }
    }
    var clipboardMetadataSize: String {
        get { OverlayStateRelay.shared.clipboardMetadataSize }
        set { OverlayStateRelay.shared.clipboardMetadataSize = newValue }
    }    
    @Published var clipboardHistory: [ClipboardItem] = {
        if let data = UserDefaults.standard.data(forKey: "clipboardHistoryData"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            
            let retention = UserDefaults.standard.string(forKey: "clipboardHistoryRetention") ?? "24h"
            if retention == "restart" {
                return []
            }
            
            var history = decoded
            if retention == "24h" {
                let threshold = Date().addingTimeInterval(-24 * 60 * 60)
                history.removeAll(where: { $0.timestamp < threshold })
            } else if retention == "7d" {
                let threshold = Date().addingTimeInterval(-7 * 24 * 60 * 60)
                history.removeAll(where: { $0.timestamp < threshold })
            }
            
            let limit = UserDefaults.standard.integer(forKey: "clipboardHistoryLimit")
            let actualLimit = limit > 0 ? limit : 30
            if history.count > actualLimit {
                history.removeLast(history.count - actualLimit)
            }
            return history
        }
        return []
    }() {
        didSet {
            if let encoded = try? JSONEncoder().encode(clipboardHistory) {
                UserDefaults.standard.set(encoded, forKey: "clipboardHistoryData")
            }
        }
    }
    @AppStorage("clipboardHistoryLimit") var clipboardHistoryLimit: Int = 30

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

    
    var pendingClipboardAction: String?
    var isProgrammaticPasteboardChange: Bool = false
    var pendingClipboardActionTimestamp: Date?
    var copyTimer: Timer?
    var pendingClipboardShowTask: DispatchWorkItem?
    private var pasteboardObserver: PasteboardObserver?
    
    var showCapsLockIndicator: Bool {
        get { OverlayStateRelay.shared.showCapsLockIndicator }
        set { OverlayStateRelay.shared.showCapsLockIndicator = newValue }
    }
    var isCapsLockOn: Bool {
        get { OverlayStateRelay.shared.isCapsLockOn }
        set { OverlayStateRelay.shared.isCapsLockOn = newValue }
    }
    var capsLockEventId: UUID {
        get { OverlayStateRelay.shared.capsLockEventId }
        set { OverlayStateRelay.shared.capsLockEventId = newValue }
    }
    var capsLockTimer: Timer?
    
    @Published var notifyOnLanguageChange: Bool = UserDefaults.standard.object(forKey: "notifyOnLanguageChange") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnLanguageChange, forKey: "notifyOnLanguageChange") }
    }

    @Published var soundOnLanguageChange: String = UserDefaults.standard.string(forKey: "soundOnLanguageChange") ?? "None" {
        didSet { UserDefaults.standard.set(soundOnLanguageChange, forKey: "soundOnLanguageChange") }
    }
    var showLanguageIndicator: Bool {
        get { OverlayStateRelay.shared.showLanguageIndicator }
        set { OverlayStateRelay.shared.showLanguageIndicator = newValue }
    }
    var currentKeyboardLanguage: String {
        get { OverlayStateRelay.shared.currentKeyboardLanguage }
        set { OverlayStateRelay.shared.currentKeyboardLanguage = newValue }
    }
    var languageEventId: UUID {
        get { OverlayStateRelay.shared.languageEventId }
        set { OverlayStateRelay.shared.languageEventId = newValue }
    }
    var languageTimer: Timer?
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
    var showBluetoothIndicator: Bool {
        get { OverlayStateRelay.shared.showBluetoothIndicator }
        set { OverlayStateRelay.shared.showBluetoothIndicator = newValue }
    }
    var bluetoothIsConnected: Bool {
        get { OverlayStateRelay.shared.bluetoothIsConnected }
        set { OverlayStateRelay.shared.bluetoothIsConnected = newValue }
    }
    var bluetoothDeviceName: String {
        get { OverlayStateRelay.shared.bluetoothDeviceName }
        set { OverlayStateRelay.shared.bluetoothDeviceName = newValue }
    }    
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
    var showWiFiIndicator: Bool {
        get { OverlayStateRelay.shared.showWiFiIndicator }
        set { OverlayStateRelay.shared.showWiFiIndicator = newValue }
    }
    var wiFiSSID: String {
        get { OverlayStateRelay.shared.wiFiSSID }
        set { OverlayStateRelay.shared.wiFiSSID = newValue }
    }
    var wiFiIsConnected: Bool {
        get { OverlayStateRelay.shared.wiFiIsConnected }
        set { OverlayStateRelay.shared.wiFiIsConnected = newValue }
    }
    var wiFiIsHotspot: Bool {
        get { OverlayStateRelay.shared.wiFiIsHotspot }
        set { OverlayStateRelay.shared.wiFiIsHotspot = newValue }
    }    
    @Published var wiFiIPAddress: String?
    @Published var wiFiRouterIP: String?
    @Published var wiFiTxRate: Double?
    @Published var wiFiChannel: String?
    @Published var wiFiRSSI: Int?
    var wiFiDetailsFetched: Bool {
        get { OverlayStateRelay.shared.wiFiDetailsFetched }
        set { OverlayStateRelay.shared.wiFiDetailsFetched = newValue }
    }
    var bluetoothEventId: UUID {
        get { OverlayStateRelay.shared.bluetoothEventId }
        set { OverlayStateRelay.shared.bluetoothEventId = newValue }
    }
    var bluetoothTimer: Timer?
    private var bluetoothObserver: BluetoothObserver?
    private var lastBluetoothEventTime: Date = Date.distantPast
    
    // Multimedia
    @Published var enableMediaNotification: Bool = UserDefaults.standard.object(forKey: "enableMediaNotification") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableMediaNotification, forKey: "enableMediaNotification") }
    }
    var showMediaIndicator: Bool {
        get { OverlayStateRelay.shared.showMediaIndicator }
        set { OverlayStateRelay.shared.showMediaIndicator = newValue }
    }
    var mediaTitle: String {
        get { OverlayStateRelay.shared.mediaTitle }
        set { OverlayStateRelay.shared.mediaTitle = newValue }
    }
    var mediaArtist: String {
        get { OverlayStateRelay.shared.mediaArtist }
        set { OverlayStateRelay.shared.mediaArtist = newValue }
    }
    var mediaDuration: Double {
        get { OverlayStateRelay.shared.mediaDuration }
        set { OverlayStateRelay.shared.mediaDuration = newValue }
    }
    var mediaElapsedTime: Double {
        get { OverlayStateRelay.shared.mediaElapsedTime }
        set { OverlayStateRelay.shared.mediaElapsedTime = newValue }
    }
    var mediaIsPlaying: Bool {
        get { OverlayStateRelay.shared.mediaIsPlaying }
        set { OverlayStateRelay.shared.mediaIsPlaying = newValue }
    }
    var mediaAction: String {
        get { OverlayStateRelay.shared.mediaAction }
        set { OverlayStateRelay.shared.mediaAction = newValue }
    }
    var mediaBundleId: String {
        get { OverlayStateRelay.shared.mediaBundleId }
        set { OverlayStateRelay.shared.mediaBundleId = newValue }
    }
    var mediaAlbum: String {
        get { OverlayStateRelay.shared.mediaAlbum }
        set { OverlayStateRelay.shared.mediaAlbum = newValue }
    }    
    @AppStorage("notifyMediaStart") var notifyMediaStart: Bool = true

    @AppStorage("soundMediaStart") var soundMediaStart: String = "None"
    @AppStorage("notifyMediaPause") var notifyMediaPause: Bool = true

    @AppStorage("soundMediaPause") var soundMediaPause: String = "None"
    @AppStorage("notifyMediaResume") var notifyMediaResume: Bool = true

    @AppStorage("soundMediaResume") var soundMediaResume: String = "None"
    @AppStorage("notifyMediaEnd") var notifyMediaEnd: Bool = true

    @AppStorage("soundMediaEnd") var soundMediaEnd: String = "None"
    
    var mediaEventId: UUID {
        get { OverlayStateRelay.shared.mediaEventId }
        set { OverlayStateRelay.shared.mediaEventId = newValue }
    }
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
    var showThemeIndicator: Bool {
        get { OverlayStateRelay.shared.showThemeIndicator }
        set { OverlayStateRelay.shared.showThemeIndicator = newValue }
    }
    var isDarkMode: Bool {
        get { OverlayStateRelay.shared.isDarkMode }
        set { OverlayStateRelay.shared.isDarkMode = newValue }
    }
    var themeEventId: UUID {
        get { OverlayStateRelay.shared.themeEventId }
        set { OverlayStateRelay.shared.themeEventId = newValue }
    }
    var themeTimer: Timer?
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
    
    var focusReminderTimer: Timer?
    var showFocusIndicator: Bool {
        get { OverlayStateRelay.shared.showFocusIndicator }
        set { OverlayStateRelay.shared.showFocusIndicator = newValue }
    }
    var isFocusModeActive: Bool {
        get { OverlayStateRelay.shared.isFocusModeActive }
        set { OverlayStateRelay.shared.isFocusModeActive = newValue }
    }
    var focusModeName: String {
        get { OverlayStateRelay.shared.focusModeName }
        set { OverlayStateRelay.shared.focusModeName = newValue }
    }
    var focusColorName: String {
        get { OverlayStateRelay.shared.focusColorName }
        set { OverlayStateRelay.shared.focusColorName = newValue }
    }
    var focusSymbol: String {
        get { OverlayStateRelay.shared.focusSymbol }
        set { OverlayStateRelay.shared.focusSymbol = newValue }
    }
    var isFocusReminder: Bool {
        get { OverlayStateRelay.shared.isFocusReminder }
        set { OverlayStateRelay.shared.isFocusReminder = newValue }
    }
    var isFocusSwitched: Bool {
        get { OverlayStateRelay.shared.isFocusSwitched }
        set { OverlayStateRelay.shared.isFocusSwitched = newValue }
    }
    struct ActiveFocusDetails: Equatable {
        var startDate: Date?
        var endDate: Date?
        var source: String?
        var device: String?
        var untilLocationLeft: Bool = false
        var endedAt: Date?
        var endedReason: String?
    }
    var focusEventId: UUID {
        get { OverlayStateRelay.shared.focusEventId }
        set { OverlayStateRelay.shared.focusEventId = newValue }
    }
    var activeFocusDetails: MediaKeyManager.ActiveFocusDetails? {
        get { OverlayStateRelay.shared.activeFocusDetails }
        set { OverlayStateRelay.shared.activeFocusDetails = newValue }
    }
    var lastEndedFocusDetails: MediaKeyManager.ActiveFocusDetails? {
        get { OverlayStateRelay.shared.lastEndedFocusDetails }
        set { OverlayStateRelay.shared.lastEndedFocusDetails = newValue }
    }
    var focusTimer: Timer?
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
    
    var showMicIndicator: Bool {
        get { OverlayStateRelay.shared.showMicIndicator }
        set { OverlayStateRelay.shared.showMicIndicator = newValue }
    }
    var isMicExpanded: Bool {
        get { OverlayStateRelay.shared.isMicExpanded }
        set { OverlayStateRelay.shared.isMicExpanded = newValue }
    }
    var isMicActive: Bool {
        get { OverlayStateRelay.shared.isMicActive }
        set { OverlayStateRelay.shared.isMicActive = newValue }
    }
    var activeMicName: String {
        get { OverlayStateRelay.shared.activeMicName }
        set { OverlayStateRelay.shared.activeMicName = newValue }
    }    
    var showLocationIndicator: Bool {
        get { OverlayStateRelay.shared.showLocationIndicator }
        set { OverlayStateRelay.shared.showLocationIndicator = newValue }
    }
    var isLocationExpanded: Bool {
        get { OverlayStateRelay.shared.isLocationExpanded }
        set { OverlayStateRelay.shared.isLocationExpanded = newValue }
    }
    var isLocationActive: Bool {
        get { OverlayStateRelay.shared.isLocationActive }
        set { OverlayStateRelay.shared.isLocationActive = newValue }
    }
    @Published var locationEventId = UUID()
    var activeLocationAppName: String {
        get { OverlayStateRelay.shared.activeLocationAppName }
        set { OverlayStateRelay.shared.activeLocationAppName = newValue }
    }
    var locationTimer: Timer?
    var currentMicDeviceName: String {
        get { OverlayStateRelay.shared.currentMicDeviceName }
        set { OverlayStateRelay.shared.currentMicDeviceName = newValue }
    }
    var micEventId: UUID {
        get { OverlayStateRelay.shared.micEventId }
        set { OverlayStateRelay.shared.micEventId = newValue }
    }
    var isSwitchingMic: Bool {
        get { OverlayStateRelay.shared.isSwitchingMic }
        set { OverlayStateRelay.shared.isSwitchingMic = newValue }
    }
    var micTimer: Timer?
    var isMicTimerScheduledInstantly = false
    var lastMicEventTime: Date = Date.distantPast
    
    var showCameraIndicator: Bool {
        get { OverlayStateRelay.shared.showCameraIndicator }
        set { OverlayStateRelay.shared.showCameraIndicator = newValue }
    }
    var isCameraExpanded: Bool {
        get { OverlayStateRelay.shared.isCameraExpanded }
        set { OverlayStateRelay.shared.isCameraExpanded = newValue }
    }
    var isCameraActive: Bool {
        get { OverlayStateRelay.shared.isCameraActive }
        set { OverlayStateRelay.shared.isCameraActive = newValue }
    }
    var activeCameraName: String {
        get { OverlayStateRelay.shared.activeCameraName }
        set { OverlayStateRelay.shared.activeCameraName = newValue }
    }
    var activeCameraClientName: String {
        get { OverlayStateRelay.shared.activeCameraClientName }
        set { OverlayStateRelay.shared.activeCameraClientName = newValue }
    }
    var activeCameraClientBundleID: String {
        get { OverlayStateRelay.shared.activeCameraClientBundleID }
        set { OverlayStateRelay.shared.activeCameraClientBundleID = newValue }
    }
    var activeCameraClientPID: Int32? {
        get { OverlayStateRelay.shared.activeCameraClientPID }
        set { OverlayStateRelay.shared.activeCameraClientPID = newValue }
    }
    var cameraEventId: UUID {
        get { OverlayStateRelay.shared.cameraEventId }
        set { OverlayStateRelay.shared.cameraEventId = newValue }
    }
    var cameraTimer: Timer?
    var isCameraTimerScheduledInstantly = false
    
    var activeMicClientName: String {
        get { OverlayStateRelay.shared.activeMicClientName }
        set { OverlayStateRelay.shared.activeMicClientName = newValue }
    }
    var activeMicClientBundleID: String {
        get { OverlayStateRelay.shared.activeMicClientBundleID }
        set { OverlayStateRelay.shared.activeMicClientBundleID = newValue }
    }
    var activeMicClientPID: Int? {
        get { OverlayStateRelay.shared.activeMicClientPID }
        set { OverlayStateRelay.shared.activeMicClientPID = newValue }
    }
    private var avObserver: AVObserver?
    private var locationObserver: LocationObserver?
    var cameraClientObserver: CameraClientObserver?
    
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
    
    var showAccessoryBatteryIndicator: Bool {
        get { OverlayStateRelay.shared.showAccessoryBatteryIndicator }
        set { OverlayStateRelay.shared.showAccessoryBatteryIndicator = newValue }
    }
    var accessoryBatteryDeviceName: String {
        get { OverlayStateRelay.shared.accessoryBatteryDeviceName }
        set { OverlayStateRelay.shared.accessoryBatteryDeviceName = newValue }
    }
    var accessoryBatteryPercentage: Int {
        get { OverlayStateRelay.shared.accessoryBatteryPercentage }
        set { OverlayStateRelay.shared.accessoryBatteryPercentage = newValue }
    }
    var accessoryBatteryIsPluggedIn: Bool {
        get { OverlayStateRelay.shared.accessoryBatteryIsPluggedIn }
        set { OverlayStateRelay.shared.accessoryBatteryIsPluggedIn = newValue }
    }
    var accessoryBatteryIsWarning: Bool {
        get { OverlayStateRelay.shared.accessoryBatteryIsWarning }
        set { OverlayStateRelay.shared.accessoryBatteryIsWarning = newValue }
    }
    var accessoryBatteryEventId: UUID {
        get { OverlayStateRelay.shared.accessoryBatteryEventId }
        set { OverlayStateRelay.shared.accessoryBatteryEventId = newValue }
    }
    var accessoryBatteryLevels: [String: Int] {
        get { OverlayStateRelay.shared.accessoryBatteryLevels }
        set { OverlayStateRelay.shared.accessoryBatteryLevels = newValue }
    }
    var accessoryBatteryCharging: [String: Bool] {
        get { OverlayStateRelay.shared.accessoryBatteryCharging }
        set { OverlayStateRelay.shared.accessoryBatteryCharging = newValue }
    }
    var bluetoothDetails: [String: [String: String]] {
        get { OverlayStateRelay.shared.bluetoothDetails }
        set { OverlayStateRelay.shared.bluetoothDetails = newValue }
    }
    var accessoryBatteryTimer: Timer?
    var btPoller: BluetoothBatteryPoller?
    
    var showPeripheralIndicator: Bool {
        get { OverlayStateRelay.shared.showPeripheralIndicator }
        set { OverlayStateRelay.shared.showPeripheralIndicator = newValue }
    }
    var peripheralDeviceName: String {
        get { OverlayStateRelay.shared.peripheralDeviceName }
        set { OverlayStateRelay.shared.peripheralDeviceName = newValue }
    }
    var peripheralDeviceType: String {
        get { OverlayStateRelay.shared.peripheralDeviceType }
        set { OverlayStateRelay.shared.peripheralDeviceType = newValue }
    }
    var peripheralDeviceIcon: String {
        get { OverlayStateRelay.shared.peripheralDeviceIcon }
        set { OverlayStateRelay.shared.peripheralDeviceIcon = newValue }
    }
    var peripheralIsConnected: Bool {
        get { OverlayStateRelay.shared.peripheralIsConnected }
        set { OverlayStateRelay.shared.peripheralIsConnected = newValue }
    }
    var peripheralEventId: UUID {
        get { OverlayStateRelay.shared.peripheralEventId }
        set { OverlayStateRelay.shared.peripheralEventId = newValue }
    }    
    var lastBluetoothEventTimeByDevice: [String: Date] = [:]
    
    var peripheralTimer: Timer?
    private var peripheralObserver: PeripheralObserver?
    private var displayObserver: DisplayObserver?
    var currentPlayingSound: NSSound?
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
            self.notifyOverlayStateChanged()
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
            self.notifyOverlayStateChanged()
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
    

    

    
    var batteryTimer: Timer?
    private var isTestingBattery = false
    private var testOriginalPercentage = 0
    private var testOriginalPluggedIn = false
    
    /// Posts a targeted notification that only VisorProWindowManager listens to.
    /// This replaces the overly-broad objectWillChange.sink pattern.
    func notifyOverlayStateChanged() {
        NotificationCenter.default.post(name: .visorProOverlayStateChanged, object: nil)
    }
    
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
        notifyOverlayStateChanged()
    }
    
    func hideBatteryOverlay() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showChargingStatus = false
                self.showLowBatteryWarning = false
                self.showUnpluggedStatus = false
                self.notifyOverlayStateChanged()
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
                    self.notifyOverlayStateChanged()
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showUnpluggedStatus = true; self.overlayTriggerTimes["battery_charging"] = Date()
                self.notifyOverlayStateChanged()
            }
        }
        
        chargingTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
            self?.hideBatteryOverlay()
        }
    }

    
    func showPeripheralOverlay(id: String? = nil, deviceName: String, type: String, typeIcon: String, isConnected: Bool, details: [String: String]? = nil) {
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
                self.notifyOverlayStateChanged()
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
                isModeChange: isModeChange,
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
                    self.notifyOverlayStateChanged()
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

    
    func disconnectBluetoothDevice(macAddress: String) {
        guard let device = IOBluetoothDevice(addressString: macAddress) else { return }
        if device.isConnected() {
            device.closeConnection()
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

    private func keyCode(for character: String) -> CGKeyCode {
        switch character.lowercased() {
        case "a": return 0; case "s": return 1; case "d": return 2; case "f": return 3
        case "h": return 4; case "g": return 5; case "z": return 6; case "x": return 7
        case "c": return 8; case "v": return 9; case "b": return 11; case "q": return 12
        case "w": return 13; case "e": return 14; case "r": return 15; case "y": return 16
        case "t": return 17; case "1": return 18; case "2": return 19; case "3": return 20
        case "4": return 21; case "6": return 22; case "5": return 23; case "=": return 24
        case "9": return 25; case "7": return 26; case "-": return 27; case "8": return 28
        case "0": return 29; case "]": return 30; case "o": return 31; case "u": return 32
        case "[": return 33; case "i": return 34; case "p": return 35; case "l": return 37
        case "j": return 38; case "'": return 39; case "k": return 40; case ";": return 41
        case "\\": return 42; case ",": return 43; case "/": return 44; case "n": return 45
        case "m": return 46; case ".": return 47
        default: return 9
        }
    }
    
    private func cgFlags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
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

    
    var wiFiTimer: Timer?
    var wiFiEventId: UUID {
        get { OverlayStateRelay.shared.wiFiEventId }
        set { OverlayStateRelay.shared.wiFiEventId = newValue }
    }    
    func disconnectWiFi() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let interface = CWWiFiClient.shared().interface() {
                interface.disassociate()
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
                self.notifyOverlayStateChanged()
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
            if !globalHoveredTypes.contains(type) {
                globalHoveredTypes.insert(type)
            }
        } else {
            if globalHoveredTypes.contains(type) {
                globalHoveredTypes.remove(type)
            }
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
            if !actualHoveredTypes.contains(type) {
                actualHoveredTypes.insert(type)
            }
        } else {
            if actualHoveredTypes.contains(type) {
                actualHoveredTypes.remove(type)
            }
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
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
               let name = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? String {
                self.currentKeyboardLanguage = name
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isSwitchingLanguageInternally { return }
            if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
                if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                   let name = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? String {
                    self.triggerLanguageIndicator(language: name)
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

    
    func enforceNotificationLimit() {
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
