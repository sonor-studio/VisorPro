import SwiftUI
import AppKit
import CoreGraphics
//
//  OverlayStateRelay.swift
//  VisorPro
//
//  Isolated ObservableObject for ALL high-frequency overlay/runtime state.
//  This object is ONLY subscribed by overlay views and VisorProWindowManager,
//  NOT by the dashboard/settings views.
//  This prevents dashboard re-renders from affecting overlay performance and vice versa.
//
//  Config/settings properties (enable*, notifyOn*, soundOn*, blocklists, etc.)
//  remain @Published in MediaKeyManager and are only changed when the user
//  edits settings in the dashboard — which is infrequent.
//

import Foundation
import Combine
import IOKit

@MainActor
class OverlayStateRelay: ObservableObject {
    static let shared = OverlayStateRelay()
    
    /// A separate instance injected into the Settings window as @EnvironmentObject.
    /// It is NEVER updated, so its objectWillChange never fires, preventing
    /// the entire Settings view tree from being invalidated on overlay state changes.
    /// Preview overlay views in settings use isPreview: true and show static mock data,
    /// so they don't need live values from the relay.
    static let settingsProxy = OverlayStateRelay()
    
    // MARK: - Swipe state (moved from MediaKeyManager earlier)
    
    /// Current swipe offset per overlay, used by VisorProWindowManager to position panels
    /// and by ScrollSwipeModifier to track gesture progress.
    
    /// Set of overlay IDs currently being swiped, prevents timer-based dismissal during active gesture.
    
    /// Whether the user is hovering a scrollable sub-view (e.g. clipboard history list in CopyOverlayView),
    /// which should prevent swipe-to-dismiss from intercepting scroll events.
    @Published var isHoveringScrollView: Bool = false
    
    // MARK: - Background Luminance & Adaptive Opacity
    
    /// Normalized luminance of the background directly behind the overlay (0.0 = pure dark, 1.0 = pure bright).
    @Published var backgroundLuminance: Double = 0.5
    
    /// Normalized color saturation of the background directly behind the overlay (0.0 = pure grayscale/neutral, 1.0 = vivid color).
    @Published var backgroundSaturation: Double = 0.0
    
    /// Dynamically adapted backing opacity for Dark Mode.
    /// Smoothly scales between ~0.06 (dark background) and ~0.24 (bright/white background).
    @Published var adaptiveBackingOpacityDark: Double = 0.12
    
    /// Dynamically adapted backing opacity for Light Mode.
    /// Smoothly scales between ~0.04 (dark background) and ~0.16 (bright/white background).
    @Published var adaptiveBackingOpacityLight: Double = 0.06
    
    func updateLuminance(_ luminance: Double, saturation: Double = 0.0) {
        let clampedL = max(0.0, min(1.0, luminance))
        let clampedS = max(0.0, min(1.0, saturation))
        self.backgroundLuminance = clampedL
        self.backgroundSaturation = clampedS
        
        let minDark: Double = 0.06
        let maxDark: Double = 0.24
        let newDark = minDark + (maxDark - minDark) * clampedL
        
        let minLight: Double = 0.04
        let maxLight: Double = 0.16
        let newLight = minLight + (maxLight - minLight) * clampedL
        
        withAnimation(.easeInOut(duration: 0.22)) {
            self.adaptiveBackingOpacityDark = newDark
            self.adaptiveBackingOpacityLight = newLight
        }
    }
    
    func adaptiveBackingOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? adaptiveBackingOpacityDark : adaptiveBackingOpacityLight
    }
    
    // MARK: - General
    
    @Published var lastAction: String = "Waiting for actions..."
    @Published var globalHoveredTypes: Set<String> = []
    @Published var actualHoveredTypes: Set<String> = []
    
    // MARK: - Volume
    
    @Published var currentVolume: Int = 50
    @Published var isMuted: Bool = false
    @Published var showVolumeIndicator: Bool = false
    @Published var currentAudioDeviceName: String = "Volume"
    @Published var audioDevicesChanged: UUID = UUID()
    
    // MARK: - Display transition
    
    @Published var forceSingleScreenForDisplayTransition: Bool = false
    @Published var isDisplayTransitioning: Bool = false
    
    // MARK: - Brightness
    
    @Published var currentBrightness: Int = 50
    @Published var showBrightnessIndicator: Bool = false
    
    // MARK: - Keyboard Brightness
    
    @Published var currentKeyboardBrightness: Int = 50
    @Published var showKeyboardBrightnessIndicator: Bool = false
    
    // MARK: - Copy / Clipboard runtime
    
    @Published var showCopyIndicator: Bool = false
    @Published var copiedText: String = ""
    @Published var clipboardAction: String = "copy" // "copy", "cut", "paste"
    @Published var clipboardEventId: UUID = UUID()
    @Published var clipboardSourceApp: String = ""
    @Published var clipboardSourceFolder: String? = nil
    @Published var clipboardMetadataSize: String = ""
    
    // MARK: - Caps Lock runtime
    
    @Published var showCapsLockIndicator: Bool = false
    @Published var isCapsLockOn: Bool = false
    @Published var capsLockEventId: UUID = UUID()
    
    // MARK: - Language runtime
    
    @Published var showLanguageIndicator: Bool = false
    @Published var currentKeyboardLanguage: String = ""
    @Published var currentKeyboardLayoutId: String? = nil
    @Published var previousKeyboardLayoutId: String? = nil
    @Published var languageEventId: UUID = UUID()
    
    // MARK: - Battery runtime
    
    @Published var currentBatteryPercentage: Int = 15
    @Published var isPluggedIn: Bool = true
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
    @Published var isEffectivelyFullyCharged: Bool = false
    
    // MARK: - Bluetooth runtime
    
    @Published var activeBluetoothNotifications: [DeviceNotification] = []
    @Published var showBluetoothIndicator: Bool = false
    @Published var bluetoothIsConnected: Bool = false
    @Published var bluetoothDeviceName: String = ""
    @Published var bluetoothEventId: UUID = UUID()
    @Published var bluetoothDetails: [String: [String: String]] = [:]
    
    // MARK: - Smart Routing runtime
    
    @Published var showSmartRoutingIndicator: Bool = false
    @Published var smartRoutingText: String = ""
    @Published var smartRoutingEventId: UUID = UUID()
    @Published var isSmartRoutingUndoAvailable: Bool = true
    
    // MARK: - WiFi runtime
    
    @Published var showWiFiIndicator: Bool = false
    @Published var showDateIndicator: Bool = false
    @Published var wiFiSSID: String = ""
    @Published var wiFiIsConnected: Bool = false
    @Published var wiFiIsHotspot: Bool = false
    @Published var wiFiIPAddress: String?
    @Published var wiFiRouterIP: String?
    @Published var wiFiTxRate: Double?
    @Published var wiFiChannel: String?
    @Published var wiFiRSSI: Int?
    @Published var wiFiDetailsFetched: Bool = false
    @Published var wiFiEventId: UUID = UUID()
    @Published var dateEventId: UUID = UUID()
    
    // MARK: - Media runtime
    
    @Published var showMediaIndicator: Bool = false
    @Published var mediaTitle: String = ""
    @Published var mediaArtist: String = ""
    @Published var mediaDuration: Double = 0.0
    @Published var mediaElapsedTime: Double = 0.0
    @Published var mediaIsPlaying: Bool = false
    @Published var mediaAction: String = "pause"
    @Published var mediaBundleId: String = ""
    @Published var mediaAlbum: String = ""
    @Published var mediaEventId: UUID = UUID()
    
    // MARK: - Theme runtime
    
    @Published var showThemeIndicator: Bool = false
    @Published var isDarkMode: Bool = false
    @Published var themeEventId: UUID = UUID()
    
    // MARK: - Focus runtime
    
    @Published var showFocusIndicator: Bool = false
    @Published var isFocusModeActive: Bool = false
    @Published var focusModeName: String = "Focus"
    @Published var focusColorName: String = "systemIndigoColor"
    @Published var focusSymbol: String = "moon.fill"
    @Published var lastActiveFocusModeName: String = ""
    @Published var lastActiveFocusSymbol: String = ""
    @Published var isFocusReminder: Bool = false
    @Published var isFocusSwitched: Bool = false
    @Published var focusActiveDate: Date? = nil
    @Published var focusEventId: UUID = UUID()
    @Published var activeFocusDetails: MediaKeyManager.ActiveFocusDetails? = nil
    @Published var lastEndedFocusDetails: MediaKeyManager.ActiveFocusDetails? = nil
    
    // MARK: - Privacy runtime (Mic)
    
    @Published var showMicIndicator: Bool = false
    @Published var isMicExpanded: Bool = false
    @Published var isMicActive: Bool = false
    @Published var isMicMuteReminder: Bool = false
    @Published var micMutedDate: Date? = nil
    @Published var activeMicName: String = ""
    @Published var currentMicDeviceName: String = ""
    @Published var micEventId: UUID = UUID()
    @Published var isSwitchingMic: Bool = false
    @Published var activeMicClientName: String = ""
    @Published var activeMicClientBundleID: String = ""
    @Published var activeMicClientPID: Int? = nil
    
    // MARK: - Privacy runtime (Camera)
    
    @Published var showCameraIndicator: Bool = false
    @Published var isCameraExpanded: Bool = false
    @Published var isCameraActive: Bool = false
    @Published var activeCameraName: String = ""
    @Published var activeCameraClientName: String = ""
    @Published var activeCameraClientBundleID: String = ""
    @Published var activeCameraClientPID: Int32? = nil
    @Published var cameraEventId: UUID = UUID()
    
    // MARK: - Privacy runtime (Location)
    
    @Published var showLocationIndicator: Bool = false
    @Published var isLocationExpanded: Bool = false
    @Published var isLocationActive: Bool = false
    @Published var locationEventId = UUID()
    @Published var activeLocationAppName: String = ""
    
    // MARK: - RAM runtime
    
    @Published var showRamIndicator: Bool = false
    @Published var showCpuIndicator: Bool = false
    @Published var cpuEventId = UUID()

    @Published var ramEventId = UUID()
    
    // MARK: - Trash runtime
    
    @Published var showTrashIndicator: Bool = false
    @Published var showFileDeletedIndicator: Bool = false
    @Published var trashSizeGB: Double = 0.0
    @Published var trashFileCount: Int = 0
    @Published var trashFolderCount: Int = 0
    @Published var trashLargestItemMB: Double = 0.0
    @Published var trashAutoEmptied: Bool = false
    @Published var trashFreedSizeGB: Double = 0.0
    @Published var lastDeletedFileName: String = ""
    @Published var lastDeletedFileSizeMB: Double = 0.0
    @Published var lastDeletedFileIcon: NSImage? = nil
    @Published var lastDeletedFileURL: URL? = nil
    @Published var overlayTriggerTimes: [String: Date] = [:]
    
    // MARK: - Survey State
    @Published var showSurveyIndicator: Bool = false
    @Published var activeSurveyQuestionId: String = ""
    @Published var surveyEventId: UUID = UUID()
    @Published var surveyShowThankYou: Bool = false
    @Published var surveyThankYouEventId: UUID = UUID()
    @Published var trashEventId = UUID()
    @Published var fileDeletedEventId = UUID()
    @Published var fanEventId = UUID()
    
    // MARK: - Peripheral runtime
    
    @Published var activePeripheralNotifications: [DeviceNotification] = []
    @Published var notificationHistory: [String: DeviceNotification] = [:]

    @Published var showPeripheralIndicator: Bool = false
    @Published var peripheralDeviceName: String = ""
    @Published var peripheralDeviceType: String = ""
    @Published var peripheralDeviceIcon: String = "cable.connector"
    @Published var peripheralIsConnected: Bool = false
    @Published var peripheralEventId: UUID = UUID()
    
    // MARK: - Display runtime
    
    @Published var activeDisplayNotifications: [DeviceNotification] = []
    
    // MARK: - Accessory Battery runtime
    
    @Published var showAccessoryBatteryIndicator: Bool = false
    @Published var accessoryBatteryDeviceName: String = ""
    @Published var accessoryBatteryPercentage: Int = 100
    @Published var accessoryBatteryIsPluggedIn: Bool = false
    @Published var accessoryBatteryIsWarning: Bool = false
    @Published var accessoryBatteryIsIncreasing: Bool = false
    @Published var accessoryBatteryEventId: UUID = UUID()
    @Published var airpodsGroupBatteryEventId: UUID = UUID()
    @Published var airpodsGroupBatteryTimerId: UUID = UUID()
    @Published var showAirpodsGroupBatteryIndicator: Bool = false
    @Published var airpodsDeviceName: String = UserDefaults.standard.string(forKey: "airpodsDeviceName") ?? "AirPods" {
        didSet { UserDefaults.standard.set(airpodsDeviceName, forKey: "airpodsDeviceName") }
    }
    @Published var airpodsLeftBattery: Int = UserDefaults.standard.integer(forKey: "airpodsLeftBattery") {
        didSet { UserDefaults.standard.set(airpodsLeftBattery, forKey: "airpodsLeftBattery") }
    }
    @Published var airpodsLeftCharging: Bool = UserDefaults.standard.bool(forKey: "airpodsLeftCharging") {
        didSet { UserDefaults.standard.set(airpodsLeftCharging, forKey: "airpodsLeftCharging") }
    }
    @Published var airpodsRightBattery: Int = UserDefaults.standard.integer(forKey: "airpodsRightBattery") {
        didSet { UserDefaults.standard.set(airpodsRightBattery, forKey: "airpodsRightBattery") }
    }
    @Published var airpodsRightCharging: Bool = UserDefaults.standard.bool(forKey: "airpodsRightCharging") {
        didSet { UserDefaults.standard.set(airpodsRightCharging, forKey: "airpodsRightCharging") }
    }
    @Published var airpodsCaseBattery: Int = UserDefaults.standard.integer(forKey: "airpodsCaseBattery") {
        didSet { UserDefaults.standard.set(airpodsCaseBattery, forKey: "airpodsCaseBattery") }
    }
    @Published var airpodsCaseCharging: Bool = UserDefaults.standard.bool(forKey: "airpodsCaseCharging") {
        didSet { UserDefaults.standard.set(airpodsCaseCharging, forKey: "airpodsCaseCharging") }
    }
    @Published var airpodsCurrentBattery: Int = UserDefaults.standard.integer(forKey: "airpodsCurrentBattery") {
        didSet { UserDefaults.standard.set(airpodsCurrentBattery, forKey: "airpodsCurrentBattery") }
    }

    @Published var accessoryBatteryLevels: [String: Int] = [:]
    @Published var accessoryBatteryCharging: [String: Bool] = [:]
    @Published var accessoryConnectionIsConnected: Bool = true
    @Published var accessoryIsConnectionEvent: Bool = false
    
    // MARK: - AirPods Mode runtime
    
    @Published var showAirPodsModeIndicator: Bool = false
    @Published var airPodsModeValue: Int = 1
    @Published var previousAirPodsModeValue: Int? = nil
    @Published var airPodsModeEventId: UUID = UUID()
    @Published var isChangingAirPodsMode: Bool = false
    
    // MARK: - Last overlay state (moved from MediaKeyManager to avoid dashboard re-renders)
    @Published var canShowLastOverlay: Bool = false
    
    // MARK: - Window closing state (for exit animations)
    @Published var closingPanels: Set<String> = []
}

class SwipeStateRelay: ObservableObject {
    static let shared = SwipeStateRelay()
    
    @Published var swipeOffsets: [String: CGFloat] = [:]
    @Published var activeSwipeIds: Set<String> = []
}

class SystemMetricsRelay: ObservableObject {
    static let shared = SystemMetricsRelay()
    
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTempHistory: [Double] = Array(repeating: 0.0, count: 16)
    @Published var cpuTopProcesses: [(name: String, cpuPercent: Double, icon: NSImage?)] = []
    
    @Published var ramUsagePercent: Double = 0.0
    @Published var totalRamGB: Double = 0.0
    @Published var usedRamGB: Double = 0.0
    @Published var ramUsageHistory: [Double] = []
    @Published var ramTopProcesses: [(name: String, ramGB: Double, icon: NSImage?)] = []
}

// MARK: - Background Luminance Detector
/// Asynchronously samples pixels beneath the overlay window using CoreGraphics
/// and computes the perceived relative luminance (ITU-R BT.709).
/// Dispatches adapted backing opacities to OverlayStateRelay without blocking the main UI thread.
final class BackgroundLuminanceDetector: @unchecked Sendable {
    static let shared = BackgroundLuminanceDetector()
    
    private let detectionQueue = DispatchQueue(label: "com.visorpro.luminanceDetection", qos: .userInitiated)
    private var lastDetectionTimestamp: TimeInterval = 0
    private let minimumInterval: TimeInterval = 0.20 // Throttle to max 5 queries/sec to respect CPU budget
    
    private init() {}
    
    /// Samples the screen area immediately behind the specified window and updates `OverlayStateRelay`.
    func detectLuminance(behind window: NSWindow) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTimestamp >= minimumInterval else { return }
        lastDetectionTimestamp = now
        
        let windowNumber = window.windowNumber
        let frame = window.frame
        
        detectionQueue.async { [weak self] in
            guard let self = self else { return }
            self.performDetection(frame: frame, windowNumber: windowNumber)
        }
    }
    
    /// Core detection logic running on the background queue.
    private func performDetection(frame: NSRect, windowNumber: Int) {
        // AppKit screen coordinates (bottom-left origin) to Quartz (top-left origin)
        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height
        
        let safeY = max(0, min(primaryHeight - frame.size.height, primaryHeight - frame.origin.y - frame.size.height))
        let cgRect = CGRect(
            x: max(0, frame.origin.x),
            y: safeY,
            width: max(frame.size.width, 10),
            height: max(frame.size.height, 10)
        )
        
        // WindowServer screen capture behind the HUD
        if let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenBelowWindow,
            CGWindowID(windowNumber),
            .nominalResolution
        ) {
            // Draw image into a 1x1 bitmap to average the entire sampled region in hardware
            var pixel = [UInt8](repeating: 0, count: 4)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            
            if let context = CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) {
                context.interpolationQuality = .medium
                context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                
                // If the capture returned valid data with sufficient alpha
                if pixel[3] > 10 {
                    let r = Double(pixel[0]) / 255.0
                    let g = Double(pixel[1]) / 255.0
                    let b = Double(pixel[2]) / 255.0
                    
                    // ITU-R BT.709 perceived luminance
                    let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                    
                    let maxC = max(r, max(g, b))
                    let minC = min(r, min(g, b))
                    let saturation = maxC > 0 ? (maxC - minC) / maxC : 0.0
                    
                    Task { @MainActor in
                        OverlayStateRelay.shared.updateLuminance(luminance, saturation: saturation)
                    }
                    return
                }
            }
        }
        
        // Fallback: If screen capture is restricted or unavailable, use cached desktop wallpaper
        Task { @MainActor in
            if let img = WallpaperHelper.cachedWallpaper {
                let stats = WallpaperHelper.calculateLuminanceAndSaturation(from: img)
                OverlayStateRelay.shared.updateLuminance(stats.luminance, saturation: stats.saturation)
            } else if let color = WallpaperHelper.cachedColor?.usingColorSpace(.deviceRGB) {
                let r = Double(color.redComponent)
                let g = Double(color.greenComponent)
                let b = Double(color.blueComponent)
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0.0
                OverlayStateRelay.shared.updateLuminance(luminance, saturation: saturation)
            } else if let screen = NSScreen.screens.first, let url = NSWorkspace.shared.desktopImageURL(for: screen),
                      let img = NSImage(contentsOf: url) {
                WallpaperHelper.cachedWallpaper = img
                let stats = WallpaperHelper.calculateLuminanceAndSaturation(from: img)
                OverlayStateRelay.shared.updateLuminance(stats.luminance, saturation: stats.saturation)
            }
        }
    }
}
