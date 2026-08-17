import SwiftUI

struct PreviewBackgroundView: View {
    @AppStorage("previewBackgroundStyle") private var previewBackgroundStyle = "gradient"
    @State private var wallpaperImage: NSImage?
    @State private var wallpaperColor: NSColor?
    
    var body: some View {
        Group {
            if previewBackgroundStyle.starts(with: "builtin:") {
                let path = String(previewBackgroundStyle.dropFirst(8))
                if let img = NSImage(contentsOfFile: path) {
                    Color.clear.frame(minHeight: 180).overlay(
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    ).clipped().cornerRadius(16)
                } else {
                    Color.black.frame(minHeight: 180).cornerRadius(16)
                }
            } else if previewBackgroundStyle == "wallpaper" {
                if let img = wallpaperImage {
                    Color.clear
                        .frame(minHeight: 180)
                        .overlay(
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipped()
                        .cornerRadius(16)
                } else if let color = wallpaperColor {
                    Color(nsColor: color)
                        .frame(minHeight: 180)
                        .cornerRadius(16)
                } else {
                    Color.black
                        .frame(minHeight: 180)
                        .cornerRadius(16)
                }
            } else {
                Color.clear
                    .glassEffect(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .frame(minHeight: 180)
            }
        }
        .onAppear {
            Task { @MainActor in
                if let wallpaperURL = WallpaperHelper.getActiveDynamicWallpaperURL() {
                    if wallpaperURL.pathExtension.lowercased() == "mov" {
                        if let image = await WallpaperHelper.generateImageFromVideoWallpaper(videoURL: wallpaperURL) {
                            self.wallpaperImage = image
                        }
                    } else if let image = NSImage(contentsOf: wallpaperURL) {
                        self.wallpaperImage = image
                    }
                } else if let screen = NSScreen.screens.first, let url = NSWorkspace.shared.desktopImageURL(for: screen), let image = NSImage(contentsOf: url) {
                    self.wallpaperImage = image
                } else if let screen = NSScreen.screens.first, let color = NSWorkspace.shared.desktopImageOptions(for: screen)?[.fillColor] as? NSColor {
                    self.wallpaperColor = color
                }
            }
        }
    }
}
