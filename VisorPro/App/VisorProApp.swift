import SwiftUI
import AppKit
import Combine
import ApplicationServices
import Carbon
import CoreLocation
import TelemetryClient
//
//  VisorProApp.swift
//  VisorPro
//
//  Created by MacBook on 18/07/2026.
//

import Combine
let trustedAtLaunchGlobal = checkAXIsProcessTrustedReliably()

func checkAXIsProcessTrustedReliably() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

@main
struct VisorProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        
        NativeOverlayDismisser.shared.start()
        UserDefaultsMigrator.migrate()
        NSSetUncaughtExceptionHandler { exception in
            fflush(stdout)
        }
    }
    
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @AppStorage("showSystemModule") private var showSystemModule = true
    @AppStorage("showTrashModule") private var showTrashModule = true
    
    var body: some Scene {
        let _ = { appDelegate.openSettingsAction = { appDelegate.openDashboard(force: true) } }()
        
        Settings {
            EmptyView()
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
        .onReceive(Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()) { _ in
            DispatchQueue.global(qos: .utility).async {
                let trusted = checkAXIsProcessTrustedReliably()
                DispatchQueue.main.async {
                    if isTrusted != trusted {
                        isTrusted = trusted
                        MediaKeyManager.shared.isTrusted = trusted
                    }
                    MediaKeyManager.shared.syncPermissions()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetDashboardForced"))) { _ in
            dashboardForced = false
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.accessibility.api"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let trusted = checkAXIsProcessTrustedReliably()
                if isTrusted != trusted {
                    isTrusted = trusted
                    MediaKeyManager.shared.isTrusted = trusted
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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var openSettingsAction: (() -> Void)?
    var customDashboardWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        
        TelemetryHelper.setup()
        
        
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettingsWindowAction), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit VisorPro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit Menu (Required for standard shortcuts like Cmd+C, Cmd+V to work in TextFields)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApp.mainMenu = mainMenu
        
        let _ = MediaKeyManager.shared
        let _ = VisorProWindowManager.shared
        let _ = CpuObserver.shared
        let _ = RamObserver.shared
        let _ = TrashObserver.shared
        let _ = AirPodsBatteryManager.shared
        
        UpdateManager.shared.checkForUpdates()
        
        MenuBarManager.shared.setup(openDashboard: { [weak self] in
            self?.openDashboard()
        })
        
        MediaKeyManager.shared.start()
        if MediaKeyManager.shared.enableBattery {
            PowerChimeManager.disableChargingSound()
        } else {
            PowerChimeManager.enableChargingSound()
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name("LocationAuthorizationChanged"), object: nil, queue: .main) { _ in
            if PermissionHelper.isLocationDenied() {
                if MediaKeyManager.shared.enableWiFi {
                    MediaKeyManager.shared.enableWiFi = false
                }
                if MediaKeyManager.shared.notifyOnLocationOn {
                    MediaKeyManager.shared.notifyOnLocationOn = false
                }
            }
        }
        
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        let isTrusted = checkAXIsProcessTrustedReliably()
        
        if !hasCompletedWelcome || !isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let _ = self.handleReopen(forceDashboard: false)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MediaKeyManager.shared.stopEventTaps()
        PowerChimeManager.enableChargingSound()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // App is an accessory, so we don't force open the Dashboard here anymore.
        // It should open in the background on first launch.
        // Dashboard will be explicitly opened via applicationShouldHandleReopen
        // when the user clicks the app icon while it's already running.
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return self.handleReopen(forceDashboard: true)
    }
    
    func handleReopen(forceDashboard: Bool) -> Bool {
        openDashboard(force: forceDashboard)
        return true
    }
    
    @objc func showSettingsWindowAction() {
        openDashboard(force: true)
    }
    
    // Helper to call from SwiftUI and menus
    func openDashboard(force: Bool = true) {
        if force {
            UserDefaults.standard.set(true, forKey: "_forceDashboard")
        }
        
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        
        if let existing = customDashboardWindow {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let initialWidth: CGFloat = 850
        let initialHeight: CGFloat = 620
        
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "VisorPro"
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.isOpaque = false
        settingsWindow.backgroundColor = .clear
        settingsWindow.minSize = NSSize(width: initialWidth, height: initialHeight)
        
        let rootView = RootView()
            .environmentObject(MediaKeyManager.shared)
            .environmentObject(OverlayStateRelay.settingsProxy)
        
        settingsWindow.contentView = NSHostingView(rootView: rootView)
        settingsWindow.setFrameAutosaveName("VisorProDashboardWindow_v8")
        if !settingsWindow.setFrameUsingName("VisorProDashboardWindow_v8") {
            settingsWindow.center()
        }
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.delegate = self
        self.customDashboardWindow = settingsWindow
        
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow, closingWindow == customDashboardWindow {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
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
