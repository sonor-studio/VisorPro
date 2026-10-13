import SwiftUI

struct TrashSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("overlayPositionMode") private var overlayPositionMode: String = "custom"
    @AppStorage("trashOverlayPosition") private var trashOverlayPosition: String = "bottomRight"
    @AppStorage("fileDeletedOverlayPosition") private var fileDeletedOverlayPosition: String = "bottomRight"
    @AppStorage("trashAllowExpansion") private var trashAllowExpansion: Bool = true
    @AppStorage("showTrashModule") private var showTrashModule: Bool = true
    
    var body: some View {
        ModuleSettingsLayout(
            title: "Trash",
            isEnabled: $showTrashModule,
            isPremium: true,
            preview: {
                ZStack {
                    HStack(alignment: .center, spacing: 20) {
                        TrashOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                            .frame(width: 260)
                            .frame(height: 56, alignment: .center)
                        
                        FileDeletedOverlayView(isPreview: true).applyTheme(mediaKeyManager.overlayTheme)
                            .frame(width: 260)
                            .frame(height: 56, alignment: .center)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 56, alignment: .center)
                }
            },
            popovers: [
                ModulePopover(
                    icon: "trash",
                    title: "Overlay Triggers",
                    content: AnyView(
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
                    )
                ),
                ModulePopover(
                    icon: "pip",
                    title: "Position",
                    show: overlayPositionMode == "custom",
                    content: AnyView(
                        Group {
                            if overlayPositionMode == "custom" {
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Trash Full Position")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                        PositionPickerGroup(selection: $trashOverlayPosition)
                                            .padding(.horizontal)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("File Deleted Position")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                        PositionPickerGroup(selection: $fileDeletedOverlayPosition)
                                            .padding(.horizontal)
                                    }
                                }
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
                AnyView(
                    InlineControlView(icon: "trash.slash.fill", title: "Auto Empty", control: AnyView(
                        Toggle("", isOn: $mediaKeyManager.trashAutoEmpty).labelsHidden().toggleStyle(.switch)
                    ))
                ),
                AnyView(
                    InlineControlView(icon: "arrow.up.left.and.arrow.down.right", title: "Allow Expansion", control: AnyView(
                        Toggle("", isOn: $trashAllowExpansion).labelsHidden().toggleStyle(.switch)
                    ))
                )
            ]
        )
        .navigationTitle("Trash")
    }
}
