import SwiftUI

struct AsyncWallpaperImage: View {
    let path: String
    @State private var image: NSImage?
    static var cache: [String: NSImage] = [:]
    
    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
                    .overlay(ProgressView().scaleEffect(0.5))
            }
        }
        .onAppear {
            load()
        }
        .onDisappear {
            image = nil
        }
    }
    
    private func load() {
        if let cached = AsyncWallpaperImage.cache[path] { self.image = cached; return }
        Task.detached(priority: .background) {
            let fileURL = URL(fileURLWithPath: path)
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceThumbnailMaxPixelSize: 320,
                kCGImageSourceShouldCacheImmediately: true
            ]
            
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return
            }
            
            let newImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            await MainActor.run {
                self.image = newImage
                AsyncWallpaperImage.cache[self.path] = newImage
            }
        }
    }
}
