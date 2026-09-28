import SwiftUI

struct TrashSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "automatic"
    @AppStorage("trashOverlayPosition") private var trashOverlayPosition: String = "bottomRight"
    @AppStorage("fileDeletedOverlayPosition") private var fileDeletedOverlayPosition: String = "bottomRight"
    @AppStorage("showTrashModule") private var showTrashModule: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trash Module")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Module Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
.padding(.leading, 12)
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "trash", iconColor: .orange, title: "Enable Trash Module", subtitle: "When disabled, VisorPro will not show trash overlays") {
                            Toggle("", isOn: $showTrashModule).labelsHidden()
                        }
                    }
                    .toggleStyle(.switch)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                if showTrashModule {
                    VStack(alignment: .center) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            PreviewBackgroundView()
                            
                            HStack(spacing: 20) {
                                TrashOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                                    .frame(width: 260)
                                
                                FileDeletedOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                                    .scaleEffect(0.85)
                                    .frame(width: 260)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overlay Triggers")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .padding(.leading, 12)
.padding(.leading, 12)
                        
                        VStack(spacing: 0) {
                            CustomSettingsRow(icon: "trash.fill", iconColor: .orange, title: "Trash Full", subtitle: "Show overlay when Trash size exceeds limit") {
                                HStack(spacing: 8) {
                                    if mediaKeyManager.notifyOnTrashFull {
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnTrashFull)
                                        if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnTrashFull) }
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnTrashFull).labelsHidden()
                                }
                            }
                            
                            if mediaKeyManager.notifyOnTrashFull {
                                Divider().padding(.leading, 48)
                                HStack {
                                    Text("Threshold")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Slider(value: $mediaKeyManager.trashSizeThresholdGB, in: 1.0...50.0, step: 1.0)
                                        .frame(width: 150)
                                    Text("\(Int(mediaKeyManager.trashSizeThresholdGB)) GB")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .trailing)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                Divider().padding(.leading, 48)
                                
                                CustomSettingsRow(icon: "sparkles", iconColor: .orange, title: "Auto Empty", subtitle: "Automatically empty the trash when full") {
                                    Toggle("", isOn: $mediaKeyManager.trashAutoEmpty).labelsHidden()
                                }
                            }
                            
                            Divider().padding(.leading, 48)
                            
                            CustomSettingsRow(icon: "doc.badge.arrow.up", iconColor: .orange, title: "File Deleted", subtitle: "Show overlay when a file is moved to Trash") {
                                HStack(spacing: 8) {
                                    if mediaKeyManager.notifyOnFileDeleted {
                                        SoundPickerControl(selectedSound: $mediaKeyManager.soundOnFileDeleted)
                                        if mediaKeyManager.overlayColorMode == "custom" { ColorPickerControl(selectedColor: $mediaKeyManager.colorOnFileDeleted) }
                                    }
                                    Toggle("", isOn: $mediaKeyManager.notifyOnFileDeleted).labelsHidden()
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
                        .padding(.horizontal)
                        
                        Group {
                            if overlayPositionMode == "custom" {
                                Text("Trash Full Overlay Position")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 12)
                                
                                PositionPickerGroup(selection: $trashOverlayPosition)
                                    .padding(.horizontal)
                                
                                Text("File Deleted Overlay Position")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 12)
                                
                                PositionPickerGroup(selection: $fileDeletedOverlayPosition)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 24)
        }
    }
}
