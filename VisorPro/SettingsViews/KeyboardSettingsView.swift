import SwiftUI

struct KeyboardSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "bottom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "bottom"
    @AppStorage("languageOverlayPosition") private var languageOverlayPosition: String = "bottom"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    CustomSettingsRow(icon: "power", iconColor: .orange, title: "Enable Keyboard Module", subtitle: "When disabled, VisorPro completely ignores Caps Lock, Clipboard, and Layout shortcuts") {
                        Toggle("", isOn: $mediaKeyManager.enableKeyboard).labelsHidden()
                    }
                }
                .toggleStyle(.switch)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                
                if mediaKeyManager.enableKeyboard {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            HStack(spacing: -10) {
                            CopyOverlayView(isPreview: true, previewAction: "copy")
                                .scaleEffect(0.85)
                            
                            CapsLockOverlayView(isPreview: true, previewIsOn: true)
                                .scaleEffect(0.85)
                        }
                        }
                        .frame(minHeight: 180)
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Clipboard Category Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Clipboard")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "doc.on.clipboard.fill", iconColor: .orange, title: "Notify on Copy", subtitle: "Show an overlay when you copy an item") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCopy).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCopy {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCopy)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "scissors", iconColor: .orange, title: "Notify on Cut", subtitle: "Show an overlay when you cut an item") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCut).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCut {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCut)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "list.clipboard.fill", iconColor: .orange, title: "Notify on Paste", subtitle: "Show an overlay when you paste an item") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnPaste).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnPaste {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnPaste)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    PositionPickerGroup(selection: $copyOverlayPosition)
                                        .padding(.bottom, 12)
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Caps Lock & Language Category Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Caps Lock & Language")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                CustomSettingsRow(icon: "capslock.fill", iconColor: .orange, title: "Notify on Caps Lock", subtitle: "Show an overlay when Caps Lock is toggled") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCapsLock).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnCapsLock {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnCapsLock)
                        }
                                Divider().padding(.leading, 40)
                                CustomSettingsRow(icon: "globe", iconColor: .orange, title: "Notify on Language Change", subtitle: "Show an overlay when keyboard layout changes") {
                                    Toggle("", isOn: $mediaKeyManager.notifyOnLanguageChange).labelsHidden()
                                }
                        if mediaKeyManager.notifyOnLanguageChange {
                            SoundPickerRow(selectedSound: $mediaKeyManager.soundOnLanguageChange)
                        }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.horizontal)
                                    
                                    PositionPickerGroup(selection: $capsLockOverlayPosition)
                                        .padding(.bottom, 12)
                                        .onChange(of: capsLockOverlayPosition) { _, new in
                                            languageOverlayPosition = new
                                        }
                                }
                            }
                            .toggleStyle(.switch)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Keyboard")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
