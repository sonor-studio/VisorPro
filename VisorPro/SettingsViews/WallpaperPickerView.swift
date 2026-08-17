import SwiftUI

struct WallpaperPickerView: View {
    @Binding var previewBackgroundStyle: String
    @State private var builtInWallpapers: [String] = []
    @State private var desktopImage: NSImage?
    @State private var desktopColor: NSColor?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                BackgroundOptionButton(
                    title: "Puste tło",
                    isSelected: previewBackgroundStyle == "gradient",
                    image: nil,
                    path: nil,
                    color: nil,
                    isGradient: false
                ) {
                    previewBackgroundStyle = "gradient"
                }
                
                BackgroundOptionButton(
                    title: "Tapeta Systemowa",
                    isSelected: previewBackgroundStyle == "wallpaper",
                    image: desktopImage,
                    path: nil,
                    color: desktopColor,
                    isGradient: false
                ) {
                    previewBackgroundStyle = "wallpaper"
                }
                
                ForEach(builtInWallpapers, id: \.self) { path in
                    let url = URL(fileURLWithPath: path)
                    let name = url.deletingPathExtension().lastPathComponent
                    BackgroundOptionButton(
                        title: name,
                        isSelected: previewBackgroundStyle == "builtin:\(path)",
                        image: nil,
                        path: path,
                        color: nil,
                        isGradient: false
                    ) {
                        previewBackgroundStyle = "builtin:\(path)"
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .onAppear {
            loadCurrentDesktop()
            loadBuiltInWallpapers()
        }
    }
    
    private func loadCurrentDesktop() {
        Task { @MainActor in
            if let wallpaperURL = WallpaperHelper.getActiveDynamicWallpaperURL() {
                if wallpaperURL.pathExtension.lowercased() == "mov" {
                    if let image = await WallpaperHelper.generateImageFromVideoWallpaper(videoURL: wallpaperURL) {
                        self.desktopImage = image
                    }
                } else if let image = NSImage(contentsOf: wallpaperURL) {
                    self.desktopImage = image
                }
            } else if let screen = NSScreen.screens.first, let url = NSWorkspace.shared.desktopImageURL(for: screen), let image = NSImage(contentsOf: url) {
                self.desktopImage = image
            } else if let screen = NSScreen.screens.first, let color = NSWorkspace.shared.desktopImageOptions(for: screen)?[.fillColor] as? NSColor {
                self.desktopColor = color
            }
        }
    }
    
    private func loadBuiltInWallpapers() {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: "/System/Library/Desktop Pictures")
            if let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                let validExtensions = ["heic", "jpg", "png", "jpeg"]
                var categoriesSeen: Set<String> = []
                let filtered = files.compactMap { file -> String? in
                    let ext = file.pathExtension.lowercased()
                    let name = file.lastPathComponent
                    guard validExtensions.contains(ext) else { return nil }
                    if name.starts(with: "Solid ") { return nil }
                    let category: String
                    if name.starts(with: "Mac ") { category = "Mac" }
                    else if name.starts(with: "iMac ") { category = "iMac" }
                    else if name.starts(with: "Radial Sky ") { category = "Radial" }
                    else if name.starts(with: "Sonoma") { category = "Sonoma" }
                    else { category = name }
                    
                    if categoriesSeen.contains(category) { return nil }
                    categoriesSeen.insert(category)
                    return file.path
                }
                .sorted()
                .prefix(20)
                
                DispatchQueue.main.async {
                    self.builtInWallpapers = Array(filtered)
                }
            }
        }
    }
}
