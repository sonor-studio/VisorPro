import SwiftUI
import AVFoundation

@MainActor
struct WallpaperHelper {
    static var cachedWallpaper: NSImage?
    static var cachedColor: NSColor?
    
    static func clearCache() {
        cachedWallpaper = nil
        cachedColor = nil
    }

    static func calculateLuminanceAndSaturation(from image: NSImage) -> (luminance: Double, saturation: Double) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return (0.5, 0.0) }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return (0.5, 0.0) }
        
        // Sample specifically the top-center 40% width and top 20% height where the HUD sits on screen,
        // falling back to full image if cropping fails.
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let hudRect = CGRect(x: w * 0.30, y: h * 0.75, width: w * 0.40, height: h * 0.25)
        let sampledImage = cgImage.cropping(to: hudRect) ?? cgImage
        
        context.interpolationQuality = .medium
        context.draw(sampledImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let sat = maxC > 0 ? (maxC - minC) / maxC : 0.0
        
        return (lum, sat)
    }

    static func calculateLuminance(from image: NSImage) -> Double {
        return calculateLuminanceAndSaturation(from: image).luminance
    }

    static func getActiveDynamicWallpaperURL() async -> URL? {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
            
            let indexPlistURL = appSupport.appendingPathComponent("com.apple.wallpaper/Store/Index.plist")
            
            if let data = try? Data(contentsOf: indexPlistURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let allSpaces = plist["AllSpacesAndDisplays"] as? [String: Any] ?? plist["SystemDefault"] as? [String: Any],
               let linked = allSpaces["Linked"] as? [String: Any],
               let content = linked["Content"] as? [String: Any],
               let choices = content["Choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let configData = firstChoice["Configuration"] as? Data {
                
                if let innerPlist = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String: Any],
                   let assetID = innerPlist["assetID"] as? String {
                    
                    // Search for the assetID in known wallpaper directories
                    let searchDirs = [
                        appSupport.appendingPathComponent("com.apple.wallpaper/aerials/videos").path,
                        "/Library/Application Support/com.apple.idleassetsd/Customer/4K-SDR-240FPS",
                        "/Library/Application Support/com.apple.idleassetsd/Customer/4K-SDR-120FPS",
                        "/Library/Application Support/com.apple.idleassetsd/Customer/4K-SDR-60FPS",
                        "/System/Library/Desktop Pictures",
                        "/Library/Desktop Pictures"
                    ]
                    
                    let isAerial = (firstChoice["Provider"] as? String)?.localizedCaseInsensitiveContains("aerials") == true
                    var foundFiles: [String] = []
                    
                    for dir in searchDirs {
                        if let enumerator = fileManager.enumerator(atPath: dir) {
                            while let file = enumerator.nextObject() as? String {
                                let lowercased = file.lowercased()
                                if file.contains(assetID) && (lowercased.hasSuffix(".mov") || lowercased.hasSuffix(".heic") || lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".png")) {
                                    foundFiles.append((dir as NSString).appendingPathComponent(file))
                                }
                            }
                        }
                    }
                    
                    if let bestMatch = isAerial ? foundFiles.first(where: { $0.lowercased().hasSuffix(".mov") }) : foundFiles.first(where: { $0.lowercased().hasSuffix(".heic") || $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".png") }) {
                        return URL(fileURLWithPath: bestMatch)
                    } else if let fallback = foundFiles.first {
                        return URL(fileURLWithPath: fallback)
                    }
                } 
                
                if let provider = firstChoice["Provider"] as? String {
                    if provider == "default" {
                        return URL(fileURLWithPath: "/System/Library/CoreServices/DefaultDesktop.heic")
                    } else if provider.localizedCaseInsensitiveContains("NeptuneOne") {
                        return URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/NeptuneOneWallpaper.appex/Contents/Resources/thumbnail.heic")
                    } else if provider.localizedCaseInsensitiveContains("Sequoia") {
                        return URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/WallpaperSequoiaExtension.appex/Contents/Resources/thumbnail.heic")
                    } else if provider.localizedCaseInsensitiveContains("Sonoma") {
                        return URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/WallpaperSonomaExtension.appex/Contents/Resources/thumbnail.heic")
                    } else if provider.localizedCaseInsensitiveContains("Macintosh") {
                        return URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/WallpaperMacintoshExtension.appex/Contents/Resources/thumbnail.heic")
                    } else if provider.localizedCaseInsensitiveContains("Monterey") {
                        return URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/WallpaperMontereyExtension.appex/Contents/Resources/thumbnail.heic")
                    } else if provider.localizedCaseInsensitiveContains("Ventura") {
                        return URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/WallpaperVenturaExtension.appex/Contents/Resources/thumbnail.heic")
                    }
                }
            }
            return nil
        }.value
    }
    
    static func loadThumbnail(from url: URL, targetSize: CGFloat = 800) async -> NSImage? {
        return await Task.detached(priority: .background) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: targetSize
            ]
            
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            
            let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            return NSImage(cgImage: cgImage, size: size)
        }.value
    }
    
    static func generateImageFromVideoWallpaper(videoURL: URL, targetSize: CGFloat = 800) async -> NSImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.maximumSize = CGSize(width: targetSize, height: targetSize)
        
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: time)
            let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            return nil
        }
    }
}
