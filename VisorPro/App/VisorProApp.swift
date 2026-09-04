//
//  VisorProApp.swift
//  VisorPro
//
//  Created by MacBook on 18/07/2026.
//

import SwiftUI
import Combine
import ApplicationServices
import Carbon
import TelemetryClient

let trustedAtLaunchGlobal = checkAXIsProcessTrustedReliably()

func checkAXIsProcessTrustedReliably() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

@main
struct VisorProApp: App {
    @StateObject private var mediaKeyManager = MediaKeyManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        UserDefaultsMigrator.migrate()
        NSSetUncaughtExceptionHandler { exception in
            LogManager.shared.log("Uncaught Exception: \(exception.name.rawValue) - \(exception.reason ?? "No reason")", level: "FATAL")
            fflush(stdout)
        }
    }
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    
    var body: some Scene {
        let _ = { appDelegate.openSettingsAction = { openSettings() } }()
        
        Settings {
            RootView()
                .environmentObject(mediaKeyManager)
        }
        // Removed .windowResizability(.contentSize) from Settings so it remembers size
        

        
        MenuBarExtra("VisorPro", image: "MenuBarIcon", isInserted: $showMenuBarIcon) {
            Button("Dashboard") {
                appDelegate.openDashboard()
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @AppStorage("_forceDashboard") private var forceDashboardFlag = false
    @State private var isTrusted = checkAXIsProcessTrustedReliably()
    @State private var dashboardForced = false
    
    var showWelcome: Bool {
        if !trustedAtLaunchGlobal { return true }
        if !isTrusted { return true }
        if dashboardForced { return false }
        return !hasCompletedWelcome
    }
    
    var body: some View {
        Group {
            if showWelcome {
                WelcomeScreen()
            } else {
                SettingsView()
            }
        }
        .onAppear {
            consumeForceDashboardFlag()
        }
        .onChange(of: forceDashboardFlag) { _, newValue in
            if newValue {
                consumeForceDashboardFlag()
            }
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            let trusted = checkAXIsProcessTrustedReliably()
            if isTrusted != trusted {
                isTrusted = trusted
                mediaKeyManager.isTrusted = trusted
            }
            mediaKeyManager.syncPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetDashboardForced"))) { _ in
            dashboardForced = false
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.accessibility.api"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let trusted = checkAXIsProcessTrustedReliably()
                if isTrusted != trusted {
                    isTrusted = trusted
                    mediaKeyManager.isTrusted = trusted
                }
            }
        }
    }
    
    private func consumeForceDashboardFlag() {
        if forceDashboardFlag {
            dashboardForced = true
            forceDashboardFlag = false
            hasCompletedWelcome = true
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var openSettingsAction: (() -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        LogManager.shared.log("VisorPro initialization started", level: "INFO")
        
        let configuration = TelemetryManagerConfiguration(appID: "F983579F-8CAB-4235-B6FE-B6CE1CE3119A")
        TelemetryDeck.initialize(config: configuration)
        TelemetryDeck.signal("appLaunched")
        
        
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettingsWindowAction), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit VisorPro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = mainMenu
        
        let _ = MediaKeyManager.shared
        let _ = VisorProWindowManager.shared
        let _ = RamObserver.shared
        
        UpdateManager.shared.checkForUpdates()
        
        MediaKeyManager.shared.start()
        if MediaKeyManager.shared.enableBattery {
            PowerChimeManager.disableChargingSound()
        } else {
            PowerChimeManager.enableChargingSound()
        }
        
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        let isTrusted = checkAXIsProcessTrustedReliably()
        
        let savedLicenseKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        let hasSeenEarlyAdopterNotice = UserDefaults.standard.bool(forKey: "hasSeenEarlyAdopterNoticeV2")
        let needsEarlyAdopterNotice = hasCompletedWelcome && savedLicenseKey.isEmpty && !hasSeenEarlyAdopterNotice
        
        if !hasCompletedWelcome || !isTrusted || needsEarlyAdopterNotice {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let _ = self.handleReopen(forceDashboard: needsEarlyAdopterNotice)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LogManager.shared.log("VisorPro will terminate", level: "INFO")
        MediaKeyManager.shared.stopEventTaps()
        PowerChimeManager.enableChargingSound()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        let hasVisibleSettings = NSApp.windows.contains { ($0.isVisible || $0.isMiniaturized) && $0.styleMask.contains(.titled) }
        if !hasVisibleSettings {
            let _ = self.handleReopen(forceDashboard: true)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let existing = NSApp.windows.first(where: { ($0.isVisible || $0.isMiniaturized) && $0.styleMask.contains(.titled) }) {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
        }
        return self.handleReopen(forceDashboard: true)
    }
    
    func handleReopen(forceDashboard: Bool) -> Bool {
        if forceDashboard {
            UserDefaults.standard.set(true, forKey: "_forceDashboard")
        }
        
        NSApp.activate(ignoringOtherApps: true)
        openSettingsAction?()
        
        return true
    }
    
    @objc func showSettingsWindowAction() {
        openSettingsAction?()
    }
    
    // Helper to call from SwiftUI
    func openDashboard() {
        let _ = handleReopen(forceDashboard: true)
    }
}

extension String {
    func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL: fileURL)
    }
    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
}

extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: fileURL, options: .atomic)
        }
    }
}
