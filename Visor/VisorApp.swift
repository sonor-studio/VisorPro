//
//  VisorApp.swift
//  Visor
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
struct VisorApp: App {
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
        
        MenuBarExtra("Visor", image: "MenuBarIcon", isInserted: $showMenuBarIcon) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Dashboard...")
                }
                .keyboardShortcut(",", modifiers: .command)
            } else {
                Button("Dashboard...") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Inicjalizacja menedżerów
        let _ = MediaKeyManager.shared
        let _ = VisorWindowManager.shared
        
        MediaKeyManager.shared.start()
        PowerChimeManager.disableChargingSound()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MediaKeyManager.shared.stopEventTaps()
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
