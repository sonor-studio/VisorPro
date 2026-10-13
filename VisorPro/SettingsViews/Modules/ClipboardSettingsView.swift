import SwiftUI

struct ClipboardSettingsView: View {
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("copyAllowExpansion") private var copyAllowExpansion: Bool = true
    @AppStorage("clipboardEnableHistory") private var clipboardEnableHistory: Bool = true
    @AppStorage("clipboardEnablePreview") private var clipboardEnablePreview: Bool = true
    @AppStorage("clipboardKeepExpandedOnPaste") private var clipboardKeepExpandedOnPaste: Bool = false
    @AppStorage("clipboardHistoryLimit") private var clipboardHistoryLimit: Int = 30
    @AppStorage("clipboardHistoryRetention") private var clipboardHistoryRetention: String = "24h"
    @AppStorage("clipboardShowPasswordToggle") private var clipboardShowPasswordToggle: Bool = true
            
    var body: some View {
        ModuleSettingsLayout(
            title: "Clipboard",
            isEnabled: $mediaKeyManager.enableClipboard,
            isPremium: true,
            preview: {
                HStack(spacing: 20) {
                    CopyOverlayView(isPreview: true, previewAction: "copy")
                        .applyTheme(mediaKeyManager.overlayTheme)
                        
                    CopyOverlayView(isPreview: true, previewAction: "paste")
                        .applyTheme(mediaKeyManager.overlayTheme)
                }
                    .fixedSize(horizontal: true, vertical: false)
            },
            popovers: [
                ModulePopover(
                    icon: "doc.on.clipboard.fill",
                    title: "Overlay Triggers",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "doc.on.clipboard.fill", iconColor: .blue, title: "Copy", subtitle: "Show an overlay when you copy an item") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnCopy { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCopy) 
                                        if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnCopy) } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCopy).labelsHidden() 
                                }
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "scissors", iconColor: .blue, title: "Cut", subtitle: "Show an overlay when you cut an item") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnCut { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCut) 
                                        if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnCut) } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnCut).labelsHidden() 
                                }
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "list.clipboard.fill", iconColor: .blue, title: "Paste", subtitle: "Show an overlay when you paste an item") {
                                HStack(spacing: 8) { 
                                    if mediaKeyManager.notifyOnPaste { 
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPaste) 
                                        if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnPaste) } 
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnPaste).labelsHidden() 
                                }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Preview & Expansion",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Allow Expansion", subtitle: "Allow overlay to expand and show clipboard preview") {
                                Toggle("", isOn: $copyAllowExpansion).labelsHidden()
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "eye", iconColor: .blue, title: "Enable Preview", subtitle: "Show preview button for items in history") {
                                Toggle("", isOn: $clipboardEnablePreview).labelsHidden()
                                    .disabled(clipboardEnablePreview && !clipboardEnableHistory)
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "asterisk", iconColor: .blue, title: "Password Mask Toggle", subtitle: "Show a toggle in the overlay to mask copied text") {
                                Toggle("", isOn: $clipboardShowPasswordToggle).labelsHidden()
                                    .onChange(of: clipboardShowPasswordToggle) { _, newValue in
                                        if !newValue {
                                            var modifiedHistory = mediaKeyManager.clipboardHistory
                                            var changed = false
                                            for i in 0..<modifiedHistory.count {
                                                if modifiedHistory[i].isMasked == true {
                                                    modifiedHistory[i].isMasked = false
                                                    changed = true
                                                }
                                            }
                                            if changed {
                                                mediaKeyManager.clipboardHistory = modifiedHistory
                                            }
                                        }
                                    }
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "clock.arrow.circlepath",
                    title: "Clipboard History",
                    content: AnyView(
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "clock.arrow.circlepath", iconColor: .blue, title: "Enable History", subtitle: "Save copied items to history list") {
                                Toggle("", isOn: $clipboardEnableHistory).labelsHidden()
                                    .disabled(clipboardEnableHistory && !clipboardEnablePreview)
                            }
                            
                            if clipboardEnableHistory {
                                Divider().padding(.leading, 40)
                                
                                CustomSettingsRow(icon: "timer", iconColor: .blue, title: "History Retention", subtitle: "How long to keep copied items") {
                                    Picker("", selection: $clipboardHistoryRetention) {
                                        Text("Clear on Restart").tag("restart")
                                        Text("24 Hours").tag("24h")
                                        Text("7 Days").tag("7d")
                                        Text("Unlimited").tag("unlimited")
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 140)
                                    .labelsHidden()
                                    .onChange(of: clipboardHistoryRetention) { _, _ in
                                        mediaKeyManager.cleanupClipboardHistory()
                                    }
                                }
                                
                                Divider().padding(.leading, 40)
                                
                                CustomSettingsRow(icon: "list.number", iconColor: .blue, title: "History Limit", subtitle: "Maximum number of items to keep") {
                                    Picker("", selection: $clipboardHistoryLimit) {
                                        Text("10 items").tag(10)
                                        Text("30 items").tag(30)
                                        Text("50 items").tag(50)
                                        Text("100 items").tag(100)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 140)
                                    .labelsHidden()
                                    .onChange(of: clipboardHistoryLimit) { _, _ in
                                        mediaKeyManager.cleanupClipboardHistory()
                                    }
                                }
                            }
                            
                            Divider().padding(.leading, 40)
                            
                            CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Don't Collapse on Paste", subtitle: "Keep history expanded after pasting an item") {
                                Toggle("", isOn: $clipboardKeepExpandedOnPaste).labelsHidden()
                            }
                        }
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Overlay Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if overlayPositionMode == "custom" {
                                PositionPickerGroup(selection: $copyOverlayPosition)
                                    .padding(.vertical, 8)
                            } else {
                                CustomSettingsRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Custom Positioning Disabled", subtitle: "Enable Custom Positioning in General Settings to modify overlay placement.") {
                                    EmptyView()
                                }
                            }
                        }
                    )
                )
            ]
        )
        .navigationTitle("Clipboard")
    }
}
