import Foundation
import TelemetryClient

/// Manages TelemetryDeck initialization and signal dispatching, ensuring
/// development and testing builds do not transmit analytics or consume API quotas.
final class TelemetryHelper {
    
    /// Identifies whether the current app runtime is a development or testing build.
    /// Returns true for Xcode Debug builds, test executions, or builds running from DerivedData/local build directories.
    static var isDevelopmentEnvironment: Bool {
        #if DEBUG
        return true
        #else
        let environment = ProcessInfo.processInfo.environment
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.contains("/DerivedData/") || bundlePath.contains("/Build/Products/") {
            return true
        }
        return false
        #endif
    }
    
    /// Initializes the TelemetryDeck SDK.
    /// In development builds, analytics, session tracking, and network requests are completely disabled.
    static func setup() {
        let configuration = TelemetryManagerConfiguration(appID: "F983579F-8CAB-4235-B6FE-B6CE1CE3119A")
        
        if isDevelopmentEnvironment {
            configuration.analyticsDisabled = true
            configuration.sendNewSessionBeganSignal = false
            configuration.sessionStatsEnabled = false
            configuration.logHandler = nil
        }
        
        TelemetryDeck.initialize(config: configuration)
        
        if !isDevelopmentEnvironment {
            sendAppLaunchedSignal()
        }
    }
    
    /// Collects launch parameters and sends the "appLaunched" signal for production releases.
    private static func sendAppLaunchedSignal() {
        let defaults = UserDefaults.standard
        
        let isPremium = !(defaults.string(forKey: "PremiumLicenseKey") ?? "").isEmpty ? "true" : "false"
        let displayTarget = defaults.string(forKey: "overlayDisplayTarget") ?? "all"
        let overlayPosition = defaults.string(forKey: "globalOverlayPosition") ?? "top"
        let overlayTheme = defaults.string(forKey: "overlayTheme") ?? "system"
        let launchAtLogin = defaults.bool(forKey: "launchAtLogin") ? "true" : "false"
        
        let enableInnerGlow = defaults.bool(forKey: "enableGlowEffect") ? "true" : "false"
        let cornerRoundingMultiplier = defaults.object(forKey: "cornerRoundingMultiplier") as? Double ?? 0.85
        let notificationDuration = defaults.object(forKey: "notificationDuration") as? Double ?? 3.0
        let maxSimultaneousNotifications = defaults.object(forKey: "maxSimultaneousNotifications") as? Int ?? 5
        let overlayColorMode = defaults.string(forKey: "overlayColorMode") ?? "preset_default"
        
        let enableFocus = defaults.object(forKey: "enableFocus") as? Bool ?? true
        let focusDetailMode = defaults.bool(forKey: "focusDetailMode")
        let focusModeStyle = enableFocus ? (focusDetailMode ? "detailed" : "standard") : "disabled"
        
        let overlayStyle = defaults.string(forKey: "overlayStyle") ?? "default"
        let effectiveOverlayStyle = OverlayStyle.effectiveStyle(for: overlayStyle)
        let overlayAnimationType = defaults.string(forKey: "overlayAnimationType") ?? "fluid_bounce"
        let enableMinimalMode = defaults.bool(forKey: "enableMinimalMode")
        let overlaySizeMode = (overlayStyle == "default" || overlayStyle == "capsule") ? (enableMinimalMode ? "mini" : "full") : "not_applicable"
        
        // Additional Design Studio preferences
        let bouncyExpansion = defaults.object(forKey: "enableBouncyExpansion") as? Bool ?? true ? "true" : "false"
        let swipeToDismiss = defaults.object(forKey: "enableSwipeToDismiss") as? Bool ?? true ? "true" : "false"
        let reverseSwipe = defaults.bool(forKey: "reverseSwipeDirection") ? "true" : "false"
        let threeFingerClick = defaults.object(forKey: "enableThreeFingerClickToDismiss") as? Bool ?? true ? "true" : "false"
        let closeButton = defaults.object(forKey: "enableCloseButton") as? Bool ?? true ? "true" : "false"
        let closeButtonRight = defaults.bool(forKey: "closeButtonOnRight") ? "true" : "false"
        
        // Clipboard History & Cycle Paste
        let clipboardEnableHistory = defaults.object(forKey: "clipboardEnableHistory") as? Bool ?? true
        let clipboardCyclePasteEnabled = defaults.object(forKey: "clipboardCyclePasteEnabled") as? Bool ?? true
        let cyclePasteActive = clipboardEnableHistory && clipboardCyclePasteEnabled
        
        // AirPods settings
        let airPodsSettings = MediaKeyManager.shared.airPodsSettings()
        let airPodsCaseStyle = airPodsSettings.caseOpenStyle // "iosCard" or "glass"
        let airPodsCaseBehavior = airPodsSettings.caseOpenBehavior // "autoHide" or "persistent"
        
        TelemetryDeck.signal("appLaunched", parameters: [
            "is_premium": isPremium,
            "display_target": displayTarget,
            "overlay_position": overlayPosition,
            "overlay_theme": overlayTheme,
            "launch_at_login": launchAtLogin,
            "enable_inner_glow": enableInnerGlow,
            "rounding_radius": String(format: "%.2f", cornerRoundingMultiplier),
            "display_duration": String(format: "%.1f", notificationDuration),
            "overlay_limit": String(maxSimultaneousNotifications),
            "overlay_color_mode": overlayColorMode,
            "focus_enabled": enableFocus ? "true" : "false",
            "focus_detailed_mode": enableFocus ? (focusDetailMode ? "true" : "false") : "disabled",
            "focus_mode_style": focusModeStyle,
            "design_studio_style": overlayStyle,
            "design_studio_effective_style": effectiveOverlayStyle,
            "design_studio_animation": overlayAnimationType,
            "design_studio_size_mode": overlaySizeMode,
            "design_studio_bouncy_expansion": bouncyExpansion,
            "design_studio_swipe_to_dismiss": swipeToDismiss,
            "design_studio_reverse_swipe": reverseSwipe,
            "design_studio_three_finger_click": threeFingerClick,
            "design_studio_close_button": closeButton,
            "design_studio_close_button_right": closeButtonRight,
            "clipboard_enable_history": clipboardEnableHistory ? "true" : "false",
            "clipboard_cycle_paste_enabled": clipboardCyclePasteEnabled ? "true" : "false",
            "clipboard_cycle_paste_active": cyclePasteActive ? "true" : "false",
            "airpods_case_overlay_style": airPodsCaseStyle,
            "airpods_case_overlay_duration": airPodsCaseBehavior
        ])
    }
    
    /// Dispatches a signal to TelemetryDeck only in production environments.
    static func signal(_ signalName: String, parameters: [String: String] = [:]) {
        guard !isDevelopmentEnvironment else { return }
        TelemetryDeck.signal(signalName, parameters: parameters)
    }
}
