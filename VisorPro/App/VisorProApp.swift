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

import SwiftUI
import Combine

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
            SettingsView()
                .environmentObject(mediaKeyManager)
        }
        .windowResizability(.contentSize)
        
        MenuBarExtra("VisorPro", image: "MenuBarIcon", isInserted: $showMenuBarIcon) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Dashboard...")
                }
            } else {
                Button("Dashboard...") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Ensure we have a main menu so showSettingsWindow: can find a responder even if MenuBarExtra is hidden
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
        
        MediaKeyManager.shared.start()
        PowerChimeManager.disableChargingSound()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MediaKeyManager.shared.stopEventTaps()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let hasVisibleSettings = NSApp.windows.contains { $0.isVisible && ($0.title == "General" || $0.title == "Settings" || $0.title == "VisorPro") }
            if !hasVisibleSettings {
                let settingsWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                    backing: .buffered, defer: false)
                settingsWindow.title = "Settings"
                settingsWindow.center()
                settingsWindow.contentView = NSHostingView(rootView: SettingsView().environmentObject(MediaKeyManager.shared))
                settingsWindow.minSize = NSSize(width: 700, height: 500)
                settingsWindow.makeKeyAndOrderFront(nil)
            }
        }
        
        return true
    }
}

// Custom String and Data extensions
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
