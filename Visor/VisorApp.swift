//
//  VisorApp.swift
//  Visor
//
//  Created by MacBook on 18/07/2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayPanel: NSPanel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Inicjalizacja panelu z odpowiednimi stylami dla nakładki
        let panel = NSPanel(
            contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 2. Panel nie może być widoczny i musi przepuszczać zdarzenia
        panel.isOpaque = false
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true // Nakładka statyczna, tylko do odczytu
        
        // 3. Kluczowe: pozwala na wyświetlenie na innych pełnoekranowych aplikacjach i Spaces
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        
        // 4. Poziom okna nad innymi aplikacjami
        panel.level = .screenSaver
        
        // Ustawienie SwiftUI view jako content
        let contentView = ContentView()
            .environmentObject(MediaKeyManager.shared)
        
        panel.contentView = NSHostingView(rootView: contentView)
        
        // Wyświetlamy bez aktywacji
        panel.makeKeyAndOrderFront(nil)
        self.overlayPanel = panel
        
        // Uruchamiamy przechwytywanie klawiszy
        MediaKeyManager.shared.start()
        
        // Wyłączamy systemowy dźwięk ładowarki (aby Visor mógł go obsłużyć)
        PowerChimeManager.disableChargingSound()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MediaKeyManager.shared.stopEventTaps()
    }
}

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

