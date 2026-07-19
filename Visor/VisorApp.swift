//
//  VisorApp.swift
//  Visor
//
//  Created by MacBook on 18/07/2026.
//

import SwiftUI

@main
struct VisorApp: App {
    @StateObject private var mediaKeyManager = MediaKeyManager()
    
    init() {
        NSSetUncaughtExceptionHandler { exception in
            print("CRASH EXCEPTION: \(exception.name.rawValue)")
            print("REASON: \(exception.reason ?? "No reason")")
            print("USER INFO: \(exception.userInfo ?? [:])")
            print("CALL STACK: \(exception.callStackSymbols.joined(separator: "\n"))")
            fflush(stdout)
        }
    }
    
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mediaKeyManager)
                .onAppear {
                    mediaKeyManager.start()
                    
                    // NSWindow configurations to make it a floating, transparent overlay
                    DispatchQueue.main.async {
                        if let window = NSApplication.shared.windows.first {
                            window.isOpaque = false
                            window.backgroundColor = .clear
                            window.titlebarAppearsTransparent = true
                            window.titleVisibility = .hidden
                            window.styleMask.remove(.titled)
                            window.hasShadow = false // Cień dodamy bezpośrednio w SwiftUI
                            window.level = .screenSaver // Gwarantuje widoczność nad aplikacjami pełnoekranowymi i paskiem menu
                            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                            window.isMovableByWindowBackground = false // Nakładka na stałe przypięta do wybranej pozycji
                            window.ignoresMouseEvents = true
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        
        Window("Symulator", id: "simulator") {
            SimulatorView(mediaKeyManager: mediaKeyManager)
        }
        .restorationBehavior(.disabled)
        
        Settings {
            SettingsView()
                .environmentObject(mediaKeyManager)
        }
        
        MenuBarExtra("Visor", systemImage: "sparkles", isInserted: $showMenuBarIcon) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Settings...")
                }
                .keyboardShortcut(",", modifiers: .command)
            } else {
                Button("Settings...") {
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
