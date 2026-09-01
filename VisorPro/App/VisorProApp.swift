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

@main
struct VisorProApp: App {
    @StateObject private var mediaKeyManager = MediaKeyManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        NSSetUncaughtExceptionHandler { exception in
            LogManager.shared.log("Uncaught Exception: \(exception.name.rawValue) - \(exception.reason ?? "No reason")", level: "FATAL")
            fflush(stdout)
        }
    }
    
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    
    var body: some Scene {
        Settings {
            RootView()
                .environmentObject(mediaKeyManager)
        }
        // Removed .windowResizability(.contentSize) from Settings so it remembers size
        

        
        MenuBarExtra("VisorPro", image: "MenuBarIcon", isInserted: $showMenuBarIcon) {
            Button("Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                let _ = appDelegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct RootView: View {
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @State private var showWelcome = false
    
    var body: some View {
        SettingsView()
            .sheet(isPresented: $showWelcome) {
                WelcomeScreen()
            }
            .onAppear {
                if !hasCompletedWelcome || !AXIsProcessTrusted() {
                    showWelcome = true
                }
            }
            .onChange(of: hasCompletedWelcome) { _, newValue in
                if !newValue {
                    showWelcome = true
                } else if AXIsProcessTrusted() {
                    showWelcome = false
                }
            }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var customDashboardWindow: NSWindow?
    
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
        appMenu.addItem(withTitle: "Settings...", action: Selector(("showSettingsWindow:")), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit VisorPro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = mainMenu
        
        let _ = MediaKeyManager.shared
        let _ = VisorProWindowManager.shared
        let _ = CpuObserver.shared
        let _ = RamObserver.shared
        let _ = LicenseManager.shared
        
        UpdateManager.shared.checkForUpdates()
        
        MediaKeyManager.shared.start()
        PowerChimeManager.disableChargingSound()
        
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        let isTrusted = AXIsProcessTrusted()
        if !hasCompletedWelcome || !isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let _ = self.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LogManager.shared.log("VisorPro will terminate", level: "INFO")
        MediaKeyManager.shared.stopEventTaps()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // When the user double-clicks the app in Finder/Spotlight while it's running, it becomes active.
        // If there are no visible windows, we should open the dashboard.
        let hasVisibleSettings = NSApp.windows.contains { $0.isVisible && ($0.title == "General" || $0.title == "Settings" || $0.title == "VisorPro") }
        if !hasVisibleSettings {
            let _ = self.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let actionString = "showSettings" + "Window:"
        NSApp.sendAction(Selector(actionString), to: nil, from: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let hasVisibleSettings = NSApp.windows.contains { $0.isVisible && ($0.title == "General" || $0.title == "Settings" || $0.title == "VisorPro") }
            if !hasVisibleSettings {
                if let existingWindow = self.customDashboardWindow {
                    existingWindow.makeKeyAndOrderFront(nil)
                    return
                }
                
                let initialWidth: CGFloat = 850
                let initialHeight: CGFloat = 500
                
                let settingsWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                    backing: .buffered, defer: false)
                settingsWindow.title = "VisorPro"
                settingsWindow.contentView = NSHostingView(rootView: RootView().environmentObject(MediaKeyManager.shared))
                settingsWindow.minSize = NSSize(width: initialWidth, height: initialHeight)
                settingsWindow.setFrameAutosaveName("VisorProDashboardWindow_v7")
                if !settingsWindow.setFrameUsingName("VisorProDashboardWindow_v7") {
                    settingsWindow.center()
                }
                settingsWindow.isReleasedWhenClosed = false
                self.customDashboardWindow = settingsWindow
                settingsWindow.makeKeyAndOrderFront(nil)
            }
        }
        
        return true
    }
    
    // Helper to call from SwiftUI
    func openDashboard() {
        let _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
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
