import Cocoa
import Foundation

class MediaObserver {
    private weak var manager: MediaKeyManager?
    
    // Function pointers dynamically loaded from MediaRemote.framework
    private typealias MRGetInfoFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (NSDictionary?) -> Void) -> Void
    private typealias MRIsPlayingFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (Bool) -> Void) -> Void
    private typealias MRGetClientFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (AnyObject?) -> Void) -> Void
    private typealias MRRegisterFunc = @convention(c) (DispatchQueue) -> Void
    
    private var getInfoFunc: MRGetInfoFunc?
    private var isPlayingFunc: MRIsPlayingFunc?
    private var getClientFunc: MRGetClientFunc?
    private var registerFunc: MRRegisterFunc?
    
    // State
    private var lastTitle = ""
    private var lastArtist = ""
    private var lastAlbum = ""
    private var lastDuration = 0.0
    private var lastElapsedTime = 0.0
    private var lastIsPlaying = false
    private var isFirstRun = true
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        setupMediaRemote()
    }
    
    private func setupMediaRemote() {
        let bundleURL = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL) else { return }
        
        if let infoPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            getInfoFunc = unsafeBitCast(infoPtr, to: MRGetInfoFunc.self)
        }
        if let isPlayingPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) {
            isPlayingFunc = unsafeBitCast(isPlayingPtr, to: MRIsPlayingFunc.self)
        }
        if let registerPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            registerFunc = unsafeBitCast(registerPtr, to: MRRegisterFunc.self)
        }
        if let clientPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingClient" as CFString) {
            getClientFunc = unsafeBitCast(clientPtr, to: MRGetClientFunc.self)
        }
    }
    
    func startObserving() {
        // 1. MediaRemote notifications (if permitted by system)
        if let register = registerFunc {
            register(DispatchQueue.main)
            NotificationCenter.default.addObserver(self, selector: #selector(mediaRemoteStateChanged), name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(mediaRemoteStateChanged), name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(mediaRemoteStateChanged), name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification"), object: nil)
        }
        
        // 2. Distributed Notifications for Apple Music & Spotify (public, reliable, zero private entitlements)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAppleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
        
        // 3. Frontmost app activation notification to keep media app context fresh
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        fetchCurrentState()
    }
    
    @objc private func mediaRemoteStateChanged() {
        fetchCurrentState()
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        // When user switches to a browser or player, update state if appropriate
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.inspectFrontmostOrRunningMediaApp(triggerNotification: false)
        }
    }
    
    @objc private func handleAppleMusicNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let state = userInfo["Player State"] as? String ?? ""
        let isPlaying = (state.lowercased() == "playing")
        let title = userInfo["Name"] as? String ?? ""
        let artist = userInfo["Artist"] as? String ?? ""
        let album = userInfo["Album"] as? String ?? ""
        let durationMs = (userInfo["Total Time"] as? NSNumber)?.doubleValue ?? 0.0
        let duration = durationMs > 0 ? durationMs / 1000.0 : 0.0
        let elapsed = (userInfo["Player Position"] as? NSNumber)?.doubleValue ?? 0.0
        
        processMediaState(
            title: title,
            artistRaw: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlaying,
            appName: "Music",
            bundleId: "com.apple.Music",
            triggerNotification: true
        )
    }
    
    @objc private func handleSpotifyNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let state = userInfo["Player State"] as? String ?? ""
        let isPlaying = (state.lowercased() == "playing")
        let title = userInfo["Name"] as? String ?? ""
        let artist = userInfo["Artist"] as? String ?? ""
        let album = userInfo["Album"] as? String ?? ""
        let durationVal = (userInfo["Duration"] as? NSNumber)?.doubleValue ?? 0.0
        let duration = durationVal > 1000 ? durationVal / 1000.0 : durationVal
        let elapsed = (userInfo["Playback Position"] as? NSNumber)?.doubleValue ?? 0.0
        
        processMediaState(
            title: title,
            artistRaw: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlaying,
            appName: "Spotify",
            bundleId: "com.spotify.client",
            triggerNotification: true
        )
    }
    
    func fetchCurrentState(triggerNotification: Bool = false) {
        guard let getClient = getClientFunc,
              let getIsPlaying = isPlayingFunc,
              let getInfo = getInfoFunc else {
            inspectFrontmostOrRunningMediaApp(triggerNotification: triggerNotification)
            return
        }
        
        var completed = false
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self, !completed else { return }
            completed = true
            self.inspectFrontmostOrRunningMediaApp(triggerNotification: triggerNotification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: timeoutWork)
        
        getClient(DispatchQueue.main) { [weak self] client in
            guard let self = self, !completed else { return }
            let clientObj = client as? NSObject
            let appName = (clientObj?.value(forKey: "displayName") as? String) ?? ""
            let bundleId = (clientObj?.value(forKey: "parentApplicationBundleIdentifier") as? String) ?? (clientObj?.value(forKey: "bundleIdentifier") as? String) ?? ""
            
            getIsPlaying(DispatchQueue.main) { [weak self] isPlaying in
                guard let self = self, !completed else { return }
                getInfo(DispatchQueue.main) { [weak self] info in
                    guard let self = self, !completed else { return }
                    completed = true
                    timeoutWork.cancel()
                    
                    let infoDict = (info as? [String: Any]) ?? [:]
                    let title = infoDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
                    let artist = infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                    let album = infoDict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
                    let durVal = infoDict["kMRMediaRemoteNowPlayingInfoDuration"]
                    let duration = (durVal as? Double) ?? (durVal as? NSNumber)?.doubleValue ?? (durVal as? String).flatMap { Double($0) } ?? 0.0
                    let elapsedVal = infoDict["kMRMediaRemoteNowPlayingInfoElapsedTime"]
                    let elapsedTime = (elapsedVal as? Double) ?? (elapsedVal as? NSNumber)?.doubleValue ?? (elapsedVal as? String).flatMap { Double($0) } ?? 0.0
                    
                    if title.isEmpty {
                        // MediaRemote returned no title (daemon rejected read or no session active); fallback to active app inspection
                        self.inspectFrontmostOrRunningMediaApp(triggerNotification: triggerNotification)
                    } else {
                        self.processMediaState(
                            title: title,
                            artistRaw: artist,
                            album: album,
                            duration: duration,
                            elapsedTime: elapsedTime,
                            isPlaying: isPlaying,
                            appName: appName,
                            bundleId: bundleId,
                            triggerNotification: triggerNotification
                        )
                    }
                }
            }
        }
    }
    
    func inspectFrontmostOrRunningMediaApp(triggerNotification: Bool = false) {
        // Run on background queue to avoid blocking main thread with AX calls
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check frontmost app first
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               let bundleId = frontApp.bundleIdentifier {
                if let details = self.inspectApp(frontApp, bundleId: bundleId) {
                    self.processMediaState(
                        title: details.title,
                        artistRaw: details.artist,
                        album: "",
                        duration: 0,
                        elapsedTime: 0,
                        isPlaying: true,
                        appName: frontApp.localizedName ?? "Media Player",
                        bundleId: bundleId,
                        triggerNotification: triggerNotification
                    )
                    return
                }
            }
            
            // Check running media players
            let candidateBundles = [
                "com.apple.quicktimeplayerx",
                "org.videolan.vlc",
                "com.colliderli.iina",
                "io.mpv",
                "com.google.chrome",
                "com.apple.safari",
                "com.brave.browser",
                "company.thebrowser.browser",
                "com.microsoft.edgemac"
            ]
            
            for app in NSWorkspace.shared.runningApplications {
                guard let bId = app.bundleIdentifier?.lowercased(),
                      candidateBundles.contains(where: { bId.contains($0) }) else { continue }
                
                if let details = self.inspectApp(app, bundleId: bId) {
                    self.processMediaState(
                        title: details.title,
                        artistRaw: details.artist,
                        album: "",
                        duration: 0,
                        elapsedTime: 0,
                        isPlaying: true,
                        appName: app.localizedName ?? "Media Player",
                        bundleId: bId,
                        triggerNotification: triggerNotification
                    )
                    return
                }
            }
        }
    }
    
    private func inspectApp(_ app: NSRunningApplication, bundleId: String) -> (title: String, artist: String)? {
        let winTitles = getActiveWindowTitles(pid: app.processIdentifier)
        for winTitle in winTitles {
            if let details = extractMediaDetails(from: winTitle, bundleId: bundleId, appName: app.localizedName ?? "") {
                return details
            }
        }
        return nil
    }
    
    private func extractMediaDetails(from rawTitle: String, bundleId: String, appName: String) -> (title: String, artist: String)? {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        
        let ignoreList = ["New Tab", "Nowa karta", "Start Page", "Strona startowa", "Settings", "Ustawienia", "Downloads", "Pobrane", "History", "Historia"]
        if ignoreList.contains(where: { title.caseInsensitiveCompare($0) == .orderedSame }) {
            return nil
        }
        
        let lowerBundle = bundleId.lowercased()
        
        // QuickTime Player
        if lowerBundle.contains("quicktime") {
            title = title.replacingOccurrences(of: " — QuickTime Player", with: "")
                         .replacingOccurrences(of: " - QuickTime Player", with: "")
            return (title, "QuickTime Player")
        }
        
        // VLC media player
        if lowerBundle.contains("videolan.vlc") {
            title = title.replacingOccurrences(of: " - VLC media player", with: "")
                         .replacingOccurrences(of: " - VLC", with: "")
            return (title, "VLC media player")
        }
        
        // IINA
        if lowerBundle.contains("iina") {
            title = title.replacingOccurrences(of: " - IINA", with: "")
            return (title, "IINA")
        }
        
        // MPV
        if lowerBundle.contains("mpv") {
            title = title.replacingOccurrences(of: " - mpv", with: "")
            return (title, "mpv")
        }
        
        // Browsers: Chrome, Safari, Brave, Arc, Edge, Opera, Firefox
        let browserBundles = ["com.google.chrome", "com.apple.safari", "com.brave.browser", "company.thebrowser.browser", "com.microsoft.edgemac", "org.mozilla.firefox", "com.operasoftware.opera"]
        if browserBundles.contains(where: { lowerBundle.contains($0) }) {
            let suffixesToStrip = [
                " - Google Chrome",
                " - Brave",
                " - Microsoft Edge",
                " - Arc",
                " - Opera",
                " — Safari"
            ]
            for suffix in suffixesToStrip {
                if title.hasSuffix(suffix) {
                    title = String(title.dropLast(suffix.count))
                }
            }
            
            if title.contains(" - YouTube") {
                title = title.replacingOccurrences(of: " - YouTube", with: "")
                return (title, "YouTube")
            } else if title.hasSuffix(" | YouTube") {
                title = title.replacingOccurrences(of: " | YouTube", with: "")
                return (title, "YouTube")
            } else if title.contains(" - Netflix") {
                title = title.replacingOccurrences(of: " - Netflix", with: "")
                return (title, "Netflix")
            } else if title.contains(" - SoundCloud") {
                title = title.replacingOccurrences(of: " - SoundCloud", with: "")
                return (title, "SoundCloud")
            } else if title.contains(" - Twitch") {
                title = title.replacingOccurrences(of: " - Twitch", with: "")
                return (title, "Twitch")
            }
            return nil
        }
        
        return (title, appName.isEmpty ? "Media Player" : appName)
    }
    
    private func processMediaState(
        title: String,
        artistRaw: String,
        album: String,
        duration: Double,
        elapsedTime: Double,
        isPlaying: Bool,
        appName: String,
        bundleId: String,
        triggerNotification: Bool
    ) {
        var finalTitle = title
        
        // QuickLook / Finder previews filter
        let qlBundle = bundleId.lowercased()
        let qlApp = appName.lowercased()
        if qlBundle.contains("quicklook") || qlBundle.contains("finder") || qlApp.contains("quick look") || qlApp == "finder" {
            return
        }
        
        var finalArtist = ""
        if !artistRaw.isEmpty && !appName.isEmpty {
            if artistRaw.lowercased() == appName.lowercased() {
                finalArtist = appName
            } else {
                finalArtist = "\(artistRaw) • \(appName)"
            }
        } else if !artistRaw.isEmpty {
            finalArtist = artistRaw
        } else if !appName.isEmpty {
            finalArtist = appName
        } else {
            finalArtist = "Unknown source"
        }
        
        var shouldTrigger = triggerNotification
        var mediaAction = "pause"
        
        if self.isFirstRun {
            self.isFirstRun = false
            mediaAction = isPlaying ? "resume" : "pause"
        } else {
            if self.lastTitle != finalTitle && !finalTitle.isEmpty {
                mediaAction = "start"
                shouldTrigger = true
            } else if self.lastIsPlaying != isPlaying {
                shouldTrigger = true
                mediaAction = isPlaying ? "resume" : "pause"
            } else {
                mediaAction = isPlaying ? "resume" : "pause"
            }
            
            if shouldTrigger {
                if mediaAction == "resume" && elapsedTime <= 0.1 {
                    mediaAction = "start"
                } else if mediaAction == "pause" && duration > 0 && elapsedTime >= (duration - 0.5) {
                    mediaAction = "end"
                }
            }
        }
        
        self.lastIsPlaying = isPlaying
        self.lastTitle = finalTitle
        self.lastArtist = finalArtist
        self.lastAlbum = album
        self.lastDuration = duration
        self.lastElapsedTime = elapsedTime
        
        DispatchQueue.main.async { [weak self] in
            self?.manager?.updateMediaInfo(
                title: finalTitle,
                artist: finalArtist,
                album: album,
                duration: duration,
                elapsedTime: elapsedTime,
                isPlaying: isPlaying,
                mediaAction: mediaAction,
                bundleId: bundleId,
                triggerNotification: shouldTrigger
            )
        }
    }
    
    private func getActiveWindowTitles(pid: pid_t) -> [String] {
        let axApp = AXUIElementCreateApplication(pid)
        var titles = [String]()
        
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
            if let window = focusedWindow, CFGetTypeID(window) == AXUIElementGetTypeID() {
                let axWindow = window as! AXUIElement
                var title: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &title) == .success, let t = title as? String {
                    titles.append(t)
                }
            }
        }
        
        var mainWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWindow) == .success {
            if let window = mainWindow, CFGetTypeID(window) == AXUIElementGetTypeID() {
                let axWindow = window as! AXUIElement
                var title: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &title) == .success, let t = title as? String {
                    titles.append(t)
                }
            }
        }
        
        return titles
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
