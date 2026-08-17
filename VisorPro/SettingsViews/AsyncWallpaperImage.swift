import SwiftUI

struct AsyncWallpaperImage: View {
    let path: String
    @State private var image: NSImage?
    
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
    }
    
    private func load() {
        Task.detached(priority: .userInitiated) {
            guard let rawImage = NSImage(contentsOfFile: path) else { return }
            let targetSize = NSSize(width: 160, height: 100)
            let newImage = NSImage(size: targetSize)
            newImage.lockFocus()
            rawImage.draw(in: NSRect(origin: .zero, size: targetSize))
            newImage.unlockFocus()
            await MainActor.run {
                self.image = newImage
            }
        }
    }
}
