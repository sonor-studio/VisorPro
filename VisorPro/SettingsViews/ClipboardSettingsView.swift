import SwiftUI

struct ClipboardSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("copyOverlayPosition") private var copyOverlayPosition: String = "top"
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
            @AppStorage("copyAllowExpansion") private var copyAllowExpansion: Bool = true
    @AppStorage("clipboardEnableHistory") private var clipboardEnableHistory: Bool = true
    @AppStorage("clipboardEnablePreview") private var clipboardEnablePreview: Bool = true
    @AppStorage("clipboardKeepExpandedOnPaste") private var clipboardKeepExpandedOnPaste: Bool = false
    @AppStorage("clipboardHistoryLimit") private var clipboardHistoryLimit: Int = 30
    @AppStorage("clipboardHistoryRetention") private var clipboardHistoryRetention: String = "24h"
            
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Clipboard Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "power", iconColor: .blue, title: "Enable Clipboard Module", subtitle: "When disabled, VisorPro completely ignores Clipboard shortcuts") {
                            Toggle("", isOn: $mediaKeyManager.enableClipboard).labelsHidden()
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

                if mediaKeyManager.enableClipboard {
                
                    if mediaKeyManager.enableClipboard {
                        VStack(alignment: .center) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        
                            ZStack {
                                PreviewBackgroundView()
                            
                                HStack(spacing: 20) {
                                CopyOverlayView(isPreview: true, previewAction: "copy").applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                                    
                                CopyOverlayView(isPreview: true, previewAction: "paste").applyTheme(mediaKeyManager.overlayTheme)
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
                                Text("Clipboard")
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
                                    CustomSettingsRow(icon: "doc.on.clipboard.fill", iconColor: .blue, title: "Notify on Copy", subtitle: "Show an overlay when you copy an item") {
                                        HStack(spacing: 8) { if mediaKeyManager.notifyOnCopy { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCopy) 
 if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnCopy) } }
    Toggle("", isOn: $mediaKeyManager.notifyOnCopy).labelsHidden() }
                               
                                }
                                
                                    Divider().padding(.leading, 40)
                                
                                    CustomSettingsRow(icon: "scissors", iconColor: .blue, title: "Notify on Cut", subtitle: "Show an overlay when you cut an item") {
                                        HStack(spacing: 8) { if mediaKeyManager.notifyOnCut { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnCut) 
 if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnCut) } }
    Toggle("", isOn: $mediaKeyManager.notifyOnCut).labelsHidden() }
                               
                                }
                                
                                    Divider().padding(.leading, 40)
                                
                                    CustomSettingsRow(icon: "list.clipboard.fill", iconColor: .blue, title: "Notify on Paste", subtitle: "Show an overlay when you paste an item") {
                                        HStack(spacing: 8) { if mediaKeyManager.notifyOnPaste { SoundPickerControl(selectedSound: $mediaKeyManager.soundOnPaste) 
 if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnPaste) } }
    Toggle("", isOn: $mediaKeyManager.notifyOnPaste).labelsHidden() }
                               
                                }
                                }
                                .toggleStyle(.switch)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                                )
                                
                                Text("Preview & Expansion")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                            
                                VStack(spacing: 0) {
                                    CustomSettingsRow(icon: "arrow.up.left.and.arrow.down.right", iconColor: .blue, title: "Allow Expansion", subtitle: "Allow overlay to expand and show clipboard preview") {
                                        Toggle("", isOn: $copyAllowExpansion).labelsHidden()
                                    }
                                    
                                    Divider().padding(.leading, 40)
                                    
                                    CustomSettingsRow(icon: "eye", iconColor: .blue, title: "Enable Preview", subtitle: "Show preview button for items in history") {
                                        Toggle("", isOn: $clipboardEnablePreview).labelsHidden()
                                            .disabled(clipboardEnablePreview && !clipboardEnableHistory)
                                    }
                                }
                                .toggleStyle(.switch)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                                )
                                
                                Text("Clipboard History")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 4)
                            
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
                                
                                    PositionPickerGroup(selection: $copyOverlayPosition)
                                    }
                                }
                                    .padding(.bottom, 12)
                            }
                            .padding(.horizontal)

                        }
                    }
                
                    Spacer()
            
                } else {
                    DisabledModuleView(icon: "power", title: "Clipboard Module is Disabled", description: "Turn on the module to configure clipboard overlays.")
                }
}
            .padding(.vertical, 20)
        }
        .navigationTitle("Clipboard")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
