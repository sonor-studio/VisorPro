import SwiftUI

struct PreviewBackgroundView: View {
    @AppStorage("previewBackgroundStyle") private var previewBackgroundStyle = "gradient"
    @State private var wallpaperImage: NSImage?
    @State private var wallpaperColor: NSColor?
    @Environment(\.colorScheme) var colorScheme
    
    var minHeight: CGFloat = 180
    var fullBleed: Bool = false
    
    var body: some View {
        Group {
            if previewBackgroundStyle.starts(with: "builtin:") {
                let path = String(previewBackgroundStyle.dropFirst(8))
                Color.clear.frame(minHeight: minHeight).overlay(
                    AsyncWallpaperImage(path: path)
                ).clipped()
                .modifier(OptionalCornerRadius(apply: !fullBleed, radius: 16))
            } else if previewBackgroundStyle == "wallpaper" {
                if let img = wallpaperImage {
                    Color.clear
                        .frame(minHeight: minHeight)
                        .overlay(
                            GeometryReader { geo in
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                        )
                        .clipped()
                        .modifier(OptionalCornerRadius(apply: !fullBleed, radius: 16))
                } else if let color = wallpaperColor {
                    Color(nsColor: color)
                        .frame(minHeight: minHeight)
                        .modifier(OptionalCornerRadius(apply: !fullBleed, radius: 16))
                } else {
                    Color.black
                        .frame(minHeight: minHeight)
                        .modifier(OptionalCornerRadius(apply: !fullBleed, radius: 16))
                }
            } else {
                Color.clear
                    .visorGlassEffect(.ultraThinMaterial)
                    .modifier(OptionalClipShape(apply: !fullBleed, shape: RoundedRectangle(cornerRadius: 16)))
                    .frame(minHeight: minHeight)
            }
        }
        .overlay(
            Group {
                if !fullBleed {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            (previewBackgroundStyle == "gradient" && colorScheme == .dark) 
                                ? Color.white.opacity(0.04) 
                                : Color.white.opacity(0.15), 
                            lineWidth: 1
                        )
                }
            }
        )
        .onAppear {
            Task { @MainActor in
                if let cached = WallpaperHelper.cachedWallpaper {
                    self.wallpaperImage = cached
                    return
                } else if let cachedCol = WallpaperHelper.cachedColor {
                    self.wallpaperColor = cachedCol
                    return
                }
                
                var loadedImage: NSImage? = nil
                var loadedColor: NSColor? = nil
                
                if let wallpaperURL = await WallpaperHelper.getActiveDynamicWallpaperURL() {
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
                    self.wallpaperImage = finalImage
                } else if let finalColor = loadedColor {
                    WallpaperHelper.cachedColor = finalColor
                    self.wallpaperColor = finalColor
                }
            }
        }
        .onDisappear {
            wallpaperImage = nil
            wallpaperColor = nil
        }
    }
}

struct OptionalCornerRadius: ViewModifier {
    var apply: Bool
    var radius: CGFloat
    
    func body(content: Content) -> some View {
        if apply {
            content.cornerRadius(radius)
        } else {
            content
        }
    }
}

struct OptionalClipShape<S: Shape>: ViewModifier {
    var apply: Bool
    var shape: S
    
    func body(content: Content) -> some View {
        if apply {
            content.clipShape(shape)
        } else {
            content
        }
    }
}
