import SwiftUI

struct KeyboardSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("capsLockOverlayPosition") private var capsLockOverlayPosition: String = "top"
    @AppStorage("languageOverlayPosition") private var languageOverlayPosition: String = "top"
    @AppStorage("capsLockAllowInteractivity") private var capsLockAllowInteractivity: Bool = true
    @AppStorage("languageAllowExpansion") private var languageAllowExpansion: Bool = true
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Keyboard",
            isEnabled: $mediaKeyManager.enableKeyboard,
            preview: {
                HStack(alignment: .center, spacing: 20) {
                    CapsLockOverlayView(isPreview: true, previewIsOn: true)
                        .applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                    
                    LanguageOverlayView(isPreview: true, previewLanguage: "English (US)")
                        .applyTheme(mediaKeyManager.overlayTheme)
                        .frame(height: 56, alignment: .center)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 56, alignment: .center)
            },
            popovers: [
                ModulePopover(
                    icon: "capslock.fill",
                    title: "Caps Lock Triggers",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "capslock.fill", iconColor: .orange, title: "Caps Lock On", subtitle: "Show an overlay when Caps Lock is enabled") {
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
                            
                            CustomSettingsRow(icon: "capslock", iconColor: .orange, title: "Caps Lock Off", subtitle: "Show an overlay when Caps Lock is disabled") {
                                HStack(spacing: 8) {
                                    if mediaKeyManager.notifyOnCapsLockOff {
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCapsLockOff)
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCapsLockOff).labelsHidden()
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Caps Lock Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if overlayPositionMode == "custom" {
                                PositionPickerGroup(selection: $capsLockOverlayPosition)
                                    .padding(.vertical, 8)
                            } else {
                                CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                    EmptyView()
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "globe",
                    title: "Language Triggers",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "globe", iconColor: .orange, title: "Language Change", subtitle: "Show an overlay when keyboard layout changes") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnLanguageChange { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnLanguageChange) 
                                        if mediaKeyManager.overlayColorMode == "custom" { 
                                            ColorPickerControl(selectedColor: $mediaKeyManager.colorOnLanguageChange) 
                                        } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnLanguageChange).labelsHidden() 
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Language Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if overlayPositionMode == "custom" {
                                PositionPickerGroup(selection: $languageOverlayPosition)
                                    .padding(.vertical, 8)
                            } else {
                                CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                    EmptyView()
                                }
                            }
                        }
                    )
                )
            ],
            inlineControls: [
                AnyView(InlineControlView(icon: "hand.tap.fill", title: "Caps Lock Interactivity", control: 
                    Toggle("", isOn: $capsLockAllowInteractivity)
                        .labelsHidden()
                        .toggleStyle(.switch)
                )),
                AnyView(InlineControlView(icon: "arrow.up.left.and.arrow.down.right", title: "Allow Expansion", control: 
                    Toggle("", isOn: $languageAllowExpansion)
                        .labelsHidden()
                        .toggleStyle(.switch)
                ))
            ]
        )
        .navigationTitle("Keyboard")
    }
}
