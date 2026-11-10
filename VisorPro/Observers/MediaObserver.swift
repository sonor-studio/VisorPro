import Cocoa
import Foundation
import CoreAudio

// MARK: - MediaRemote in-process client
// Loads MediaRemote.framework directly (private framework, no subprocess needed).
// All function pointers are resolved once at init time and reused on every notification.
private final class MediaRemoteClient {
    typealias InfoFunc     = @convention(c) (DispatchQueue, @escaping @convention(block) (NSDictionary?) -> Void) -> Void
    typealias IsPlayingFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (Bool) -> Void) -> Void
    typealias ClientFunc   = @convention(c) (DispatchQueue, @escaping @convention(block) (AnyObject?) -> Void) -> Void
    typealias RegisterFunc = @convention(c) (DispatchQueue) -> Void

    let getInfo: InfoFunc
    let getIsPlaying: IsPlayingFunc
    let getClient: ClientFunc
    let register: RegisterFunc

    init?() {
        guard let bundleURL = URL(string: "file:///System/Library/PrivateFrameworks/MediaRemote.framework"),
              let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) else { return nil }

        if !CFBundleIsExecutableLoaded(bundle) {
            _ = CFBundleLoadExecutable(bundle)
        }

        guard
            let infoPtr      = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString),
            let isPlayingPtr  = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString),
            let registerPtr   = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString),
            let clientPtr     = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingClient" as CFString)
        else { return nil }

        self.getInfo      = unsafeBitCast(infoPtr,      to: InfoFunc.self)
        self.getIsPlaying  = unsafeBitCast(isPlayingPtr,  to: IsPlayingFunc.self)
        self.register     = unsafeBitCast(registerPtr,   to: RegisterFunc.self)
        self.getClient    = unsafeBitCast(clientPtr,     to: ClientFunc.self)
    }

    /// Fetch current now-playing state and call `completion` on the main queue.
    func fetchState(completion: @escaping (_ title: String, _ artist: String, _ album: String,
                                            _ duration: Double, _ elapsedTime: Double,
                                            _ isPlaying: Bool, _ appName: String, _ bundleId: String) -> Void) {
        getClient(DispatchQueue.main) { clientObj in
            let nsObj    = clientObj as? NSObject
            let appName  = (nsObj?.value(forKey: "displayName") as? String) ?? ""
            let bundleId = (nsObj?.value(forKey: "parentApplicationBundleIdentifier") as? String)
                        ?? (nsObj?.value(forKey: "bundleIdentifier") as? String)
                        ?? ""

            self.getIsPlaying(DispatchQueue.main) { isPlaying in
                self.getInfo(DispatchQueue.main) { info in
                    let d        = (info as? [String: Any]) ?? [:]
                    let title    = d["kMRMediaRemoteNowPlayingInfoTitle"]  as? String ?? ""
                    let artist   = d["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                    let album    = d["kMRMediaRemoteNowPlayingInfoAlbum"]  as? String ?? ""
                    let durVal   = d["kMRMediaRemoteNowPlayingInfoDuration"]
                    let duration = (durVal as? Double) ?? (durVal as? NSNumber)?.doubleValue
                                ?? (durVal as? String).flatMap { Double($0) } ?? 0.0
                    let elVal    = d["kMRMediaRemoteNowPlayingInfoElapsedTime"]
                    let elapsed  = (elVal  as? Double) ?? (elVal  as? NSNumber)?.doubleValue
                                ?? (elVal  as? String).flatMap { Double($0) } ?? 0.0

                    completion(title, artist, album, duration, elapsed, isPlaying, appName, bundleId)
                }
            }
        }
    }
}

// MARK: - MediaObserver

class MediaObserver {
    private weak var manager: MediaKeyManager?

    // MediaRemote in-process client
    private var mrClient: MediaRemoteClient?

    // CoreAudio Output State
    private var outputDevice: AudioDeviceID = 0
    private var isAudioRunning = false
    private var audioPauseTimer: Timer?

    // Distributed Notification State (Spotify & Apple Music)
    private var spotifyTitle = ""
    private var spotifyArtist = ""
    private var spotifyAlbum = ""
    private var musicTitle = ""
    private var musicArtist = ""
    private var musicAlbum = ""

    // State
    private var lastTitle = ""
    private var lastArtist = ""
    private var lastAlbum = ""
    private var lastDuration = 0.0
    private var lastElapsedTime = 0.0
    private var lastIsPlaying = false
    private var lastBundleId = ""
    private var isFirstRun = true

    init(manager: MediaKeyManager) {
        self.manager = manager
    }

    func startObserving() {
        setupDistributedNotifications()
        setupAudioOutputObserver()
        startMediaRemoteObserver()
    }

    // MARK: - MediaRemote in-process observer

    private func startMediaRemoteObserver() {
        guard let client = MediaRemoteClient() else {
            NSLog("[MediaObserver] Failed to load MediaRemote.framework — media overlay disabled.")
            return
        }
        self.mrClient = client

        // Register for system now-playing notifications (must be called from main queue)
        client.register(DispatchQueue.main)

        // Observe now-playing changes
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(handleMediaRemoteNotification(_:)),
                       name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(handleMediaRemoteNotification(_:)),
                       name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(handleMediaRemoteNotification(_:)),
                       name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification"),
                       object: nil)

        // Fetch initial state (silent — just populate internal state, do not show overlay)
        fetchMediaRemoteState(triggerNotification: false)
    }

    @objc private func handleMediaRemoteNotification(_ notification: Notification) {
        fetchMediaRemoteState(triggerNotification: true)
    }

    private func fetchMediaRemoteState(triggerNotification: Bool) {
        guard let client = mrClient else { return }

        client.fetchState { [weak self] title, artist, album, duration, elapsed, isPlaying, appName, bundleId in
            guard let self = self else { return }

            // Filter out Quick Look / Finder noise
            let lowerBundle = bundleId.lowercased()
            let lowerApp    = appName.lowercased()
            if lowerBundle.contains("quicklook") || lowerBundle.contains("finder") ||
               lowerApp.contains("quick look")   || lowerApp == "finder" {
                return
            }

            // Build cleaned title
            var cleanTitle = title
            if cleanTitle.isEmpty || cleanTitle == "Unknown Media" {
                let browserBundles = ["com.apple.quicktimeplayerx", "com.apple.iina", "org.videolan.vlc",
                                      "io.mpv", "com.apple.safari", "com.google.chrome"]
                if browserBundles.contains(where: { lowerBundle.contains($0) }),
                   let app = NSWorkspace.shared.runningApplications.first(where: {
                       $0.bundleIdentifier?.lowercased() == lowerBundle
                   }) {
                    let winTitles = self.getActiveWindowTitles(pid: app.processIdentifier)
                    if let first = winTitles.first(where: { !$0.isEmpty }) {
                        cleanTitle = self.cleanMediaTitle(first)
                    }
                }
                if cleanTitle.isEmpty {
                    cleanTitle = self.lastTitle
                }
            }

            // Build artist label
            let finalArtist: String
            if !artist.isEmpty && !appName.isEmpty {
                finalArtist = artist.lowercased() == appName.lowercased() ? appName : "\(artist) • \(appName)"
            } else if !artist.isEmpty {
                finalArtist = artist
            } else if !appName.isEmpty {
                finalArtist = appName
            } else {
                finalArtist = "Unknown source"
            }

            // Determine action
            var shouldTrigger = triggerNotification
            var mediaAction = "pause"

            if self.isFirstRun {
                self.isFirstRun = false
                mediaAction = isPlaying ? "resume" : "pause"
                shouldTrigger = false
            } else {
                if self.lastTitle != cleanTitle && !cleanTitle.isEmpty {
                    mediaAction = "start"
                    shouldTrigger = true
                } else if self.lastIsPlaying != isPlaying {
                    shouldTrigger = true
                    mediaAction = isPlaying ? "resume" : "pause"
                } else {
                    mediaAction = isPlaying ? "resume" : "pause"
                }

                if shouldTrigger {
                    if mediaAction == "resume" && elapsed <= 0.1 {
                        mediaAction = "start"
                    } else if mediaAction == "pause" && duration > 0 && elapsed >= (duration - 0.5) {
                        mediaAction = "end"
                    }
                }
            }

            self.lastIsPlaying   = isPlaying
            self.lastTitle       = cleanTitle
            self.lastArtist      = finalArtist
            self.lastAlbum       = album
            self.lastDuration    = duration
            self.lastElapsedTime = elapsed
            self.lastBundleId    = bundleId

            self.manager?.updateMediaInfo(
                title:               cleanTitle,
                artist:              finalArtist,
                album:               album,
                duration:            duration,
                elapsedTime:         elapsed,
                isPlaying:           isPlaying,
                mediaAction:         mediaAction,
                bundleId:            bundleId,
                triggerNotification: shouldTrigger
            )
        }
    }

    // MARK: - Distributed Notifications (Spotify & Apple Music)

    private func setupDistributedNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
    }

    @objc private func handleSpotifyNotification(_ notif: Notification) {
        guard let userInfo = notif.userInfo else { return }
        let state = (userInfo["Player State"] as? String) ?? ""
        let isPlaying = (state.lowercased() == "playing" || state.lowercased() == "kplaybackstateplaying")
        let name   = (userInfo["Name"]   as? String) ?? ""
        let artist = (userInfo["Artist"] as? String) ?? ""
        let album  = (userInfo["Album"]  as? String) ?? ""

        self.spotifyTitle  = name
        self.spotifyArtist = artist
        self.spotifyAlbum  = album
        self.lastTitle     = name
        self.lastArtist    = artist.isEmpty ? "Spotify" : "\(artist) • Spotify"
        self.lastAlbum     = album
        self.lastBundleId  = "com.spotify.client"
        self.lastIsPlaying = isPlaying

        let action = isPlaying ? "resume" : "pause"

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manager?.updateMediaInfo(
                title:               self.lastTitle,
                artist:              self.lastArtist,
                album:               self.lastAlbum,
                duration:            self.lastDuration,
                elapsedTime:         self.lastElapsedTime,
                isPlaying:           isPlaying,
                mediaAction:         action,
                bundleId:            self.lastBundleId,
                triggerNotification: true
            )
        }
    }

    @objc private func handleMusicNotification(_ notif: Notification) {
        guard let userInfo = notif.userInfo else { return }
        let state = (userInfo["Player State"] as? String) ?? ""
        let isPlaying = (state.lowercased() == "playing")
        let name   = (userInfo["Name"]   as? String) ?? ""
        let artist = (userInfo["Artist"] as? String) ?? ""
        let album  = (userInfo["Album"]  as? String) ?? ""

        self.musicTitle  = name
        self.musicArtist = artist
        self.musicAlbum  = album
        self.lastTitle   = name
        self.lastArtist  = artist.isEmpty ? "Music" : "\(artist) • Music"
        self.lastAlbum   = album
        self.lastBundleId  = "com.apple.Music"
        self.lastIsPlaying = isPlaying

        let action = isPlaying ? "resume" : "pause"

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manager?.updateMediaInfo(
                title:               self.lastTitle,
                artist:              self.lastArtist,
                album:               self.lastAlbum,
                duration:            self.lastDuration,
                elapsedTime:         self.lastElapsedTime,
                isPlaying:           isPlaying,
                mediaAction:         action,
                bundleId:            self.lastBundleId,
                triggerNotification: true
            )
        }
    }

    // MARK: - CoreAudio Output Device Monitoring

    private func setupAudioOutputObserver() {
        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.rebuildOutputDevice()
        }

        rebuildOutputDevice()
    }

    private func rebuildOutputDevice() {
        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dev: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, 0, nil, &size, &dev)
        if err == 0 && dev != 0 {
            self.outputDevice = dev
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectAddPropertyListenerBlock(dev, &runningAddress, DispatchQueue.main) { [weak self] _, _ in
                self?.checkOutputAudioState()
            }
            checkOutputAudioState()
        }
    }

    private func checkOutputAudioState() {
        guard outputDevice != 0 else { return }
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let err = AudioObjectGetPropertyData(outputDevice, &runningAddress, 0, nil, &size, &isRunning)
        guard err == 0 else { return }
        let currentlyRunning = (isRunning > 0)

        if currentlyRunning {
            audioPauseTimer?.invalidate()
            audioPauseTimer = nil
            if !self.isAudioRunning {
                self.isAudioRunning = true
                self.handlePlaybackStateChange(isPlaying: true)
            }
        } else {
            // Debounce pause by 300ms so seeking / track changes don't cause false pauses
            audioPauseTimer?.invalidate()
            audioPauseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.isAudioRunning {
                    self.isAudioRunning = false
                    self.handlePlaybackStateChange(isPlaying: false)
                }
            }
        }
    }

    // MARK: - Helpers

    private func cleanMediaTitle(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " — QuickTime Player", with: "")
            .replacingOccurrences(of: " - VLC media player", with: "")
            .replacingOccurrences(of: " - Safari", with: "")
            .replacingOccurrences(of: " - Google Chrome", with: "")
            .replacingOccurrences(of: " - Brave", with: "")
            .replacingOccurrences(of: " - Arc", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectCurrentMediaInfo() -> (title: String, artist: String, bundleId: String) {
        // 1. Check running Spotify or Apple Music
        let runningApps = NSWorkspace.shared.runningApplications
        if let _ = runningApps.first(where: { $0.bundleIdentifier == "com.spotify.client" }), !self.spotifyTitle.isEmpty {
            return (self.spotifyTitle, self.spotifyArtist.isEmpty ? "Spotify" : self.spotifyArtist, "com.spotify.client")
        }
        if let _ = runningApps.first(where: { $0.bundleIdentifier == "com.apple.Music" }), !self.musicTitle.isEmpty {
            return (self.musicTitle, self.musicArtist.isEmpty ? "Music" : self.musicArtist, "com.apple.Music")
        }

        // 2. Check frontmost application
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let winTitles = getActiveWindowTitles(pid: frontApp.processIdentifier)
            for t in winTitles where !t.isEmpty {
                let clean = cleanMediaTitle(t)
                if !clean.isEmpty && (t.contains("YouTube") || t.contains("VLC") || t.contains("QuickTime") ||
                                      t.contains("Netflix") || t.contains("Spotify")) {
                    return (clean, frontApp.localizedName ?? "Media", frontApp.bundleIdentifier ?? "")
                }
            }
        }

        // 3. Check any running media / browser application
        let targetBundles = [
            "com.apple.safari", "com.google.chrome", "com.brave.browser", "company.thebrowser.browser",
            "com.microsoft.edgemac", "org.mozilla.firefox", "org.videolan.vlc",
            "com.apple.quicktimeplayerx", "com.apple.iina"
        ]
        for app in runningApps {
            if let bId = app.bundleIdentifier?.lowercased(), targetBundles.contains(where: { bId.contains($0) }) {
                let winTitles = getActiveWindowTitles(pid: app.processIdentifier)
                for t in winTitles where !t.isEmpty {
                    let clean = cleanMediaTitle(t)
                    if !clean.isEmpty && (t.contains("YouTube") || t.contains("VLC") || t.contains("QuickTime") || t.contains("Netflix")) {
                        return (clean, app.localizedName ?? "Browser", app.bundleIdentifier ?? "")
                    }
                }
            }
        }

        // 4. Fallback: frontmost app first window
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let winTitles = getActiveWindowTitles(pid: frontApp.processIdentifier)
            if let first = winTitles.first(where: { !$0.isEmpty }) {
                let clean = cleanMediaTitle(first)
                if !clean.isEmpty {
                    return (clean, frontApp.localizedName ?? "Media", frontApp.bundleIdentifier ?? "")
                }
            }
        }

        return (self.lastTitle, self.lastArtist, self.lastBundleId)
    }

    private func handlePlaybackStateChange(isPlaying: Bool) {
        if self.isFirstRun {
            self.isFirstRun = false
            self.lastIsPlaying = isPlaying
            return
        }

        let info = detectCurrentMediaInfo()
        if !info.title.isEmpty {
            self.lastTitle    = info.title
            self.lastArtist   = info.artist
            self.lastBundleId = info.bundleId
        }

        guard !self.lastTitle.isEmpty else { return }
        self.lastIsPlaying = isPlaying
        let action = isPlaying ? "resume" : "pause"

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manager?.updateMediaInfo(
                title:               self.lastTitle,
                artist:              self.lastArtist,
                album:               self.lastAlbum,
                duration:            self.lastDuration,
                elapsedTime:         self.lastElapsedTime,
                isPlaying:           isPlaying,
                mediaAction:         action,
                bundleId:            self.lastBundleId,
                triggerNotification: true
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
                if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &title) == .success,
                   let t = title as? String {
                    titles.append(t)
                }
            }
        }

        var mainWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWindow) == .success {
            if let window = mainWindow, CFGetTypeID(window) == AXUIElementGetTypeID() {
                let axWindow = window as! AXUIElement
                var title: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &title) == .success,
                   let t = title as? String {
                    titles.append(t)
                }
            }
        }

        return titles
    }

    // MARK: - Public API (called from MediaKeyManager)

    func toggleOrFetchCurrentState(triggerNotification: Bool = true) {
        let info = detectCurrentMediaInfo()
        if !info.title.isEmpty {
            self.lastTitle    = info.title
            self.lastArtist   = info.artist
            self.lastBundleId = info.bundleId
        }

        self.lastIsPlaying = !self.lastIsPlaying
        let action = self.lastIsPlaying ? "resume" : "pause"

        guard !self.lastTitle.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manager?.updateMediaInfo(
                title:               self.lastTitle,
                artist:              self.lastArtist,
                album:               self.lastAlbum,
                duration:            self.lastDuration,
                elapsedTime:         self.lastElapsedTime,
                isPlaying:           self.lastIsPlaying,
                mediaAction:         action,
                bundleId:            self.lastBundleId,
                triggerNotification: triggerNotification
            )
        }
    }

    func fetchCurrentState(triggerNotification: Bool = false) {
        let info = detectCurrentMediaInfo()
        if !info.title.isEmpty {
            self.lastTitle    = info.title
            self.lastArtist   = info.artist
            self.lastBundleId = info.bundleId
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.lastTitle.isEmpty else { return }
            self.manager?.updateMediaInfo(
                title:               self.lastTitle,
                artist:              self.lastArtist,
                album:               self.lastAlbum,
                duration:            self.lastDuration,
                elapsedTime:         self.lastElapsedTime,
                isPlaying:           self.lastIsPlaying,
                mediaAction:         self.lastIsPlaying ? "resume" : "pause",
                bundleId:            self.lastBundleId,
                triggerNotification: triggerNotification
            )
        }
    }

    deinit {
        audioPauseTimer?.invalidate()
        audioPauseTimer = nil
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
