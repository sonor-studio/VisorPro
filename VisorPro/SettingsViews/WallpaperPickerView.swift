import SwiftUI

struct WallpaperPickerView: View {
    @Binding var previewBackgroundStyle: String
    @State private var builtInWallpapers: [String] = []
    @State private var desktopImage: NSImage?
    @State private var desktopColor: NSColor?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    BackgroundOptionButton(
                        title: "No Background",
                        isSelected: previewBackgroundStyle == "gradient",
                        image: nil,
                        path: nil,
                        color: nil,
                        isGradient: false
                    ) {
                        previewBackgroundStyle = "gradient"
                    }
                    
                    BackgroundOptionButton(
                        title: "System Wallpaper",
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
                .frame(minWidth: geometry.size.width)
            }
        }
        .frame(height: 90)
        .onAppear {
            loadCurrentDesktop()
            loadBuiltInWallpapers()
        }
        .onDisappear {
            builtInWallpapers.removeAll()
            desktopImage = nil
            desktopColor = nil
            WallpaperHelper.clearCache()
        }
    }
    
    private func loadCurrentDesktop() {
        Task { @MainActor in
            if let cached = WallpaperHelper.cachedWallpaper {
                self.desktopImage = cached
                return
            } else if let cachedCol = WallpaperHelper.cachedColor {
                self.desktopColor = cachedCol
                return
            }
            
            var loadedImage: NSImage? = nil
            var loadedColor: NSColor? = nil
            
            if let wallpaperURL = WallpaperHelper.getActiveDynamicWallpaperURL() {
                if wallpaperURL.pathExtension.lowercased() == "mov" {
                    if let image = await WallpaperHelper.generateImageFromVideoWallpaper(videoURL: wallpaperURL, targetSize: 800) {
                        loadedImage = image
                    }
                } else if let image = await WallpaperHelper.loadThumbnail(from: wallpaperURL, targetSize: 800) {
                    loadedImage = image
                }
            }
            
            if loadedImage == nil, let screen = NSScreen.screens.first, let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                if let image = await WallpaperHelper.loadThumbnail(from: url, targetSize: 800) {
                    loadedImage = image
                }
            }
            
            if loadedImage == nil, let screen = NSScreen.screens.first, let color = NSWorkspace.shared.desktopImageOptions(for: screen)?[.fillColor] as? NSColor {
                loadedColor = color
            }
            
            if let finalImage = loadedImage {
                WallpaperHelper.cachedWallpaper = finalImage
                self.desktopImage = finalImage
            } else if let finalColor = loadedColor {
                WallpaperHelper.cachedColor = finalColor
                self.desktopColor = finalColor
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
