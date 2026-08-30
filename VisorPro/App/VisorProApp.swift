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

@main
struct VisorProApp: App {
    @StateObject private var mediaKeyManager = MediaKeyManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        NSSetUncaughtExceptionHandler { exception in
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
        
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Settings...", action: Selector(("showSettingsWindow:")), keyEquivalent: ",")
        NSApp.mainMenu = mainMenu
        
        let _ = MediaKeyManager.shared
        let _ = VisorProWindowManager.shared
        let _ = FanObserver.shared
        let _ = RamObserver.shared
        
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
        MediaKeyManager.shared.stopEventTaps()
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
