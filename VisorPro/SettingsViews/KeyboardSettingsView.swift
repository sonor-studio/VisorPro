import SwiftUI

struct KeyboardSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
        @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "top"
    @AppStorage("languageOverlayPosition") private var languageOverlayPosition: String = "top"
                    @AppStorage("capsLockAllowInteractivity") private var capsLockAllowInteractivity: Bool = true
    @AppStorage("languageAllowExpansion") private var languageAllowExpansion: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keyboard Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
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
                }
                .padding(.horizontal)

                if mediaKeyManager.enableKeyboard {
                
                    if mediaKeyManager.enableKeyboard {
                        VStack(alignment: .center) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        
                            ZStack {
                                PreviewBackgroundView()
                            
                                HStack(spacing: 20) {

                                CapsLockOverlayView(isPreview: true, previewIsOn: true).applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                                
                                LanguageOverlayView(isPreview: true, previewLanguage: "English (US)").applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                            }
                            }
                            .frame(minHeight: 180)
                            .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    
                        Divider()
                    
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Caps Lock")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                Text("Overlay Triggers")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                            
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "capslock.fill", iconColor: .orange, title: "Notify on Caps Lock On", subtitle: "Show an overlay when Caps Lock is enabled") {
                                        HStack(spacing: 8) {
                                            if mediaKeyManager.notifyOnCapsLockOn {
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCapsLock)
                                                if mediaKeyManager.overlayColorMode == "custom" {
                                                    ColorPickerControl(selectedColor: $mediaKeyManager.colorOnCapsLock)
                                                }
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnCapsLockOn).labelsHidden()
                                        }
                                    }
                                    
                                    Divider().padding(.leading, 40)
                                    
                                    CustomSettingsRow(icon: "capslock", iconColor: .orange, title: "Notify on Caps Lock Off", subtitle: "Show an overlay when Caps Lock is disabled") {
                                        HStack(spacing: 8) {
                                            if mediaKeyManager.notifyOnCapsLockOff {
                                                SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCapsLockOff)
                                            }
                                            Toggle("", isOn: $mediaKeyManager.notifyOnCapsLockOff).labelsHidden()
                                        }
                                    }
                                
                                
                                    Divider().padding(.leading, 40)
                                
                                }
                                .toggleStyle(.switch)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                                )
                                
                                Text("Interactivity")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                                    
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "hand.tap.fill", iconColor: .orange, title: "Allow Interactivity", subtitle: "Allow tapping to toggle Caps Lock") {
                                        Toggle("", isOn: $capsLockAllowInteractivity).labelsHidden()
                                    }
                                }
                                .toggleStyle(.switch)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                                )
                            
                                Group {
                                    if overlayPositionMode == "custom" {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.leading, 4)
                                
                                    PositionPickerGroup(selection: $capsLockOverlayPosition)
                                    }
                                }
                                    .padding(.bottom, 12)
                            }
                            .padding(.horizontal)
                        
                            Divider()
                        
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Language")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                Text("Overlay Triggers")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                            
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "globe", iconColor: .orange, title: "Notify on Language Change", subtitle: "Show an overlay when keyboard layout changes") {
                                        HStack(spacing: 8) { if mediaKeyManager.notifyOnLanguageChange { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnLanguageChange) 
 if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnLanguageChange) } }
    Toggle("", isOn: $mediaKeyManager.notifyOnLanguageChange).labelsHidden() }
                               
                                }
                                
                                    Divider().padding(.leading, 40)
                                
                                }
                                .toggleStyle(.switch)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                                )
                                
                                Text("Expansion & Behavior")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                                    
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .orange, title: "Allow Expansion", subtitle: "Allow overlay to expand and show layout details") {
                                        Toggle("", isOn: $languageAllowExpansion).labelsHidden()
                                    }
                                }
                                .toggleStyle(.switch)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                                )
                            
                                Group {
                                    if overlayPositionMode == "custom" {
                                    Text("Overlay Position")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 10)
                                        .padding(.leading, 4)
                                
                                    PositionPickerGroup(selection: $languageOverlayPosition)
                                    }
                                }
                                    .padding(.bottom, 12)
                            }
                            .padding(.horizontal)
                        }
                    }
                
                    Spacer()
            
                } else {
                    DisabledModuleView(icon: "power", title: "Keyboard Module is Disabled", description: "Turn on the module to configure keyboard overlays.")
                }
}
            .padding(.vertical, 20)
        }
        .navigationTitle("Keyboard")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
