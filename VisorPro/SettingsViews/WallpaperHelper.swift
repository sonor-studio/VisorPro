import SwiftUI
import AVFoundation

@MainActor
struct WallpaperHelper {
    static func getActiveDynamicWallpaperURL() -> URL? {
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
                        for case let file as String in enumerator {
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
    }
    
    static func generateImageFromVideoWallpaper(videoURL: URL) async -> NSImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: time)
            let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            print("Błąd generowania obrazu z wideo: \(error)")
            return nil
        }
    }
}
