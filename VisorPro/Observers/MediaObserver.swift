import Cocoa
import Foundation
import CoreAudio
import ApplicationServices

// MARK: - MediaObserver
// Recreates the proven background helper process architecture from commit 5cc693e,
// but uses macOS's pre-installed /usr/bin/osascript (JXA) instead of /usr/bin/swift.
//
// Key improvements:
//   1. ZERO Command Line Tools prompt: /usr/bin/osascript is an Apple-signed system binary
//      pre-installed on 100% of Macs since OS X 10.0. No developer tools dialog will ever appear.
//   2. Full Apple entitlements: unlike third-party binaries or user scripts, osascript has
//      system rights to query MediaRemote.framework on macOS Sonoma & Sequoia without permission denials.
//   3. Persistent background monitoring: runs a low-overhead (300ms sleep) JXA loop that emits
//      JSON lines over an anonymous Pipe whenever media starts, pauses, resumes, or changes track.
//   4. Accurate track minutes: duration and elapsed seconds are parsed and delivered directly
//      to UniversalOverlayView for exact "M:SS / M:SS" counters and progress bars.
//   5. Strict filtering: VisorPro, Antigravity, and non-media host apps are completely blocked.

class MediaObserver {
    private weak var manager: MediaKeyManager?
    private var helperProcess: Process?
    private var outputPipe: Pipe?

    // CoreAudio Output State
    private var outputDevice: AudioDeviceID = 0
    private var isAudioRunning = false
    private var audioPauseTimer: Timer?

    // Playback State Cache
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
        // 1. Direct distributed notifications for Spotify and Apple Music (zero-overhead secondary path)
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(handleSpotifyNotification(_:)),
                        name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil)
        dnc.addObserver(self, selector: #selector(handleAppleMusicNotification(_:)),
                        name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil)

        // 2. CoreAudio output device listener
        setupAudioOutputObserver()

        // 3. Start background JXA helper daemon
        startHelperProcess()
    }

    // MARK: - Background JXA Helper Daemon

    private func startHelperProcess() {
        helperProcess?.terminationHandler = nil
        if helperProcess?.isRunning == true {
            helperProcess?.terminate()
        }

        // JavaScript for Automation loop.
        // Uses Apple-signed system /usr/bin/osascript to query MRNowPlayingRequest.
        // Emits JSON lines directly to standard output without triggering any CLT dialogs.
        let jxaScript = """
        const b = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
        b.load;
        const req = $.NSClassFromString('MRNowPlayingRequest');
        const stdout = $.NSFileHandle.fileHandleWithStandardOutput;

        function emit(dict) {
            try {
                const str = JSON.stringify(dict) + "\\n";
                const data = $.NSString.alloc.initWithString(str).dataUsingEncoding($.NSUTF8StringEncoding);
                stdout.writeData(data);
            } catch(e) {}
        }

        let lastTitle = '';
        let lastPlaying = null;

        function snapshot(isInitial) {
            let title = '';
            let artist = '';
            let album = '';
            let duration = 0;
            let elapsed = 0;
            let isPlaying = false;
            let appName = '';
            let bundleId = '';

            const item = req ? req.localNowPlayingItem : null;
            const path = req ? req.localNowPlayingPlayerPath : null;

            if (item && item.nowPlayingInfo) {
                const d = item.nowPlayingInfo;
                try { const t = d.valueForKey('kMRMediaRemoteNowPlayingInfoTitle'); if (t) title = t.js; } catch(e){}
                try { const a = d.valueForKey('kMRMediaRemoteNowPlayingInfoArtist'); if (a) artist = a.js; } catch(e){}
                try { const al = d.valueForKey('kMRMediaRemoteNowPlayingInfoAlbum'); if (al) album = al.js; } catch(e){}
                try { const dur = d.valueForKey('kMRMediaRemoteNowPlayingInfoDuration'); if (dur) duration = dur.js; } catch(e){}
                try { const el = d.valueForKey('kMRMediaRemoteNowPlayingInfoElapsedTime'); if (el) elapsed = el.js; } catch(e){}
                try { const rate = d.valueForKey('kMRMediaRemoteNowPlayingInfoPlaybackRate'); if (rate && rate.js > 0) isPlaying = true; } catch(e){}
            }
            if (path && path.client) {
                try { appName = path.client.displayName.js || ''; } catch(e){}
                try { bundleId = path.client.parentApplicationBundleIdentifier.js || path.client.bundleIdentifier.js || ''; } catch(e){}
            }

            lastTitle = title;
            lastPlaying = isPlaying;

            emit({
                isInitial: isInitial,
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                elapsed: elapsed,
                isPlaying: isPlaying,
                appName: appName,
                bundleId: bundleId
            });
        }

        // 1. Immediate snapshot for cache warm-up
        snapshot(true);

        // 2. Real-time change observer loop
        while (true) {
            $.NSThread.sleepForTimeInterval(0.15);

            let title = '';
            let isPlaying = false;
            const item = req ? req.localNowPlayingItem : null;
            if (item && item.nowPlayingInfo) {
                const d = item.nowPlayingInfo;
                try { const t = d.valueForKey('kMRMediaRemoteNowPlayingInfoTitle'); if (t) title = t.js; } catch(e){}
                try { const rate = d.valueForKey('kMRMediaRemoteNowPlayingInfoPlaybackRate'); if (rate && rate.js > 0) isPlaying = true; } catch(e){}
            }

            if (title !== lastTitle || isPlaying !== lastPlaying) {
                snapshot(false);
            }
        }
        """

        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-l", "JavaScript", "-e", jxaScript]
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self,
                  let str = String(data: data, encoding: .utf8) else { return }

            let lines = str.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for line in lines {
                self.parseJSON(line)
            }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.startHelperProcess()
            }
        }

        do {
            try proc.run()
            self.helperProcess = proc
            self.outputPipe = pipe
        } catch {
            NSLog("[MediaObserver] Failed to run osascript helper: %@", error.localizedDescription)
        }
    }

    // MARK: - JSON Parser & Overlay Trigger

    private func parseJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let isInitial = json["isInitial"] as? Bool ?? false
        let rawTitle  = json["title"] as? String ?? ""
        let artistRaw = json["artist"] as? String ?? ""
        let album     = json["album"] as? String ?? ""
        let duration  = json["duration"] as? Double ?? 0.0
        let elapsed   = json["elapsed"] as? Double ?? 0.0
        let isPlaying = json["isPlaying"] as? Bool ?? false
        let appName   = json["appName"] as? String ?? ""
        let bundleId  = json["bundleId"] as? String ?? ""

        let cleanTitle = cleanMediaTitle(rawTitle)

        // Strict blacklist: prevent VisorPro, Antigravity, QuickLook, Finder from ever appearing
        let lowerBundle = bundleId.lowercased()
        let lowerApp = appName.lowercased()
        let ownBundle = Bundle.main.bundleIdentifier?.lowercased() ?? ""

        if (!ownBundle.isEmpty && lowerBundle == ownBundle) ||
           lowerBundle.contains("visorpro") || lowerApp.contains("visorpro") ||
           lowerBundle.contains("antigravity") || lowerApp.contains("antigravity") ||
           lowerBundle.contains("quicklook") || lowerApp.contains("quick look") ||
           lowerBundle.contains("finder") || lowerApp == "finder" {
            return
        }

        // Resolve application name if missing or generic
        var effectiveAppName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if effectiveAppName.isEmpty && !bundleId.isEmpty {
            if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
                effectiveAppName = runningApp.localizedName ?? ""
            }
            if effectiveAppName.isEmpty {
                let lowerB = bundleId.lowercased()
                if lowerB.contains("safari") { effectiveAppName = "Safari" }
                else if lowerB.contains("chrome") { effectiveAppName = "Google Chrome" }
                else if lowerB.contains("spotify") { effectiveAppName = "Spotify" }
                else if lowerB.contains("music") { effectiveAppName = "Music" }
                else if lowerB.contains("quicktime") { effectiveAppName = "QuickTime Player" }
                else if lowerB.contains("vlc") { effectiveAppName = "VLC" }
                else if lowerB.contains("arc") { effectiveAppName = "Arc" }
                else if lowerB.contains("brave") { effectiveAppName = "Brave" }
                else if lowerB.contains("edge") { effectiveAppName = "Microsoft Edge" }
                else if lowerB.contains("firefox") { effectiveAppName = "Firefox" }
                else if lowerB.contains("iina") { effectiveAppName = "IINA" }
            }
        }

        // Clean up artistRaw
        let effectiveArtist = artistRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Build clean finalArtist label
        var finalArtist = ""
        if !effectiveArtist.isEmpty && !effectiveAppName.isEmpty {
            if effectiveArtist.lowercased() == effectiveAppName.lowercased() {
                finalArtist = effectiveAppName
            } else {
                finalArtist = "\(effectiveArtist) • \(effectiveAppName)"
            }
        } else if !effectiveArtist.isEmpty {
            finalArtist = effectiveArtist
        } else if !effectiveAppName.isEmpty {
            finalArtist = effectiveAppName
        } else {
            finalArtist = "Media"
        }

        if isInitial {
            self.lastTitle       = cleanTitle
            self.lastArtist      = finalArtist
            self.lastAlbum       = album
            self.lastDuration    = duration
            self.lastElapsedTime = elapsed
            self.lastIsPlaying   = isPlaying
            self.lastBundleId    = bundleId
            self.isFirstRun      = false
            return
        }

        guard !cleanTitle.isEmpty else {
            if self.lastIsPlaying {
                self.lastIsPlaying = false
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.manager?.updateMediaInfo(
                        title:               self.lastTitle,
                        artist:              self.lastArtist,
                        album:               self.lastAlbum,
                        duration:            self.lastDuration,
                        elapsedTime:         self.lastElapsedTime,
                        isPlaying:           false,
                        mediaAction:         "end",
                        bundleId:            self.lastBundleId,
                        triggerNotification: true
                    )
                }
            }
            return
        }

        var shouldTrigger = false
        var mediaAction = "pause"

        if self.lastTitle != cleanTitle && !cleanTitle.isEmpty {
            mediaAction = "start"
            shouldTrigger = true
        } else if self.lastIsPlaying != isPlaying {
            mediaAction = isPlaying ? "resume" : "pause"
            shouldTrigger = true
        } else {
            mediaAction = isPlaying ? "resume" : "pause"
        }

        if shouldTrigger {
            if mediaAction == "resume" && elapsed <= 0.5 {
                mediaAction = "start"
            } else if mediaAction == "pause" && duration > 0 && elapsed >= (duration - 1.0) {
                mediaAction = "end"
            }

            // Suppress overlay if the user is already focused on the window/tab playing this media
            if isUserFocusedOnPlayingWindow(bundleId: bundleId, title: cleanTitle) {
                shouldTrigger = false
            }
        }

        self.lastIsPlaying   = isPlaying
        self.lastTitle       = cleanTitle
        self.lastArtist      = finalArtist
        self.lastAlbum       = album
        self.lastDuration    = duration
        self.lastElapsedTime = elapsed
        self.lastBundleId    = bundleId

        DispatchQueue.main.async { [weak self] in
            self?.manager?.updateMediaInfo(
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

    private func cleanMediaTitle(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: " - YouTube Music", with: "")
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " | YouTube", with: "")
            .replacingOccurrences(of: " — QuickTime Player", with: "")
            .replacingOccurrences(of: " - QuickTime Player", with: "")
            .replacingOccurrences(of: " - VLC media player", with: "")
            .replacingOccurrences(of: " - VLC", with: "")
            .replacingOccurrences(of: " - IINA", with: "")
            .replacingOccurrences(of: " - mpv", with: "")
            .replacingOccurrences(of: " — Safari", with: "")
            .replacingOccurrences(of: " - Google Chrome", with: "")
            .replacingOccurrences(of: " - Brave", with: "")
            .replacingOccurrences(of: " - Microsoft Edge", with: "")
            .replacingOccurrences(of: " - Arc", with: "")
            .replacingOccurrences(of: " - Opera", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Active Window Suppression Check

    /// Checks if the user is currently focused on the window/tab that is playing this media.
    /// When true, the overlay is suppressed because the user is already looking directly at the player.
    private func isUserFocusedOnPlayingWindow(bundleId: String, title: String) -> Bool {
        guard !bundleId.isEmpty,
              let frontApp = NSWorkspace.shared.frontmostApplication,
              let frontBundleId = frontApp.bundleIdentifier else {
            return false
        }

        let lowerFront = frontBundleId.lowercased()
        let lowerMedia = bundleId.lowercased()

        // If the frontmost application is completely different from the media player, user is not on this player
        guard lowerFront == lowerMedia || lowerFront.contains(lowerMedia) || lowerMedia.contains(lowerFront) else {
            return false
        }

        // Dedicated media players (Spotify, Music, TV, QuickTime, VLC, IINA, Podcasts):
        // Being focused on the dedicated player app means the user is looking directly at its interface.
        let browserBundles = [
            "com.apple.safari",
            "com.google.chrome",
            "com.brave.browser",
            "company.thebrowser.browser",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "com.operasoftware.opera"
        ]

        let isBrowser = browserBundles.contains { lowerFront.contains($0) || $0.contains(lowerFront) }
        if !isBrowser {
            return true
        }

        // Web browsers: check if the frontmost window/tab title matches media keywords or track title
        let winTitles = getActiveWindowTitles(pid: frontApp.processIdentifier)
        let cleanMedia = cleanMediaTitle(title).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for winTitle in winTitles {
            let cleanWin = winTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanWin.isEmpty { continue }

            if cleanWin.contains("youtube") || cleanWin.contains("tiktok") ||
               cleanWin.contains("instagram") || cleanWin.contains("shorts") ||
               cleanWin.contains("reels") || cleanWin.contains("netflix") ||
               cleanWin.contains("twitch") || cleanWin.contains("spotify") {
                return true
            }

            let strippedWin = cleanMediaTitle(cleanWin)
                .replacingOccurrences(of: " - google chrome", with: "")
                .replacingOccurrences(of: " — safari", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanMedia.isEmpty && !strippedWin.isEmpty {
                if strippedWin.contains(cleanMedia) || cleanMedia.contains(strippedWin) {
                    return true
                }
            }
        }

        return false
    }

    private func getActiveWindowTitles(pid: pid_t) -> [String] {
        var titles = [String]()

        // 1. Accessibility API
        let axApp = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow, CFGetTypeID(window) == AXUIElementGetTypeID() {
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success,
               let t = title as? String, !t.isEmpty {
                titles.append(t)
            }
        }

        var mainWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWindow) == .success,
           let window = mainWindow, CFGetTypeID(window) == AXUIElementGetTypeID() {
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success,
               let t = title as? String, !t.isEmpty, !titles.contains(t) {
                titles.append(t)
            }
        }

        // 2. CoreGraphics Window List (handles Chrome, Brave, Arc if AX title is unavailable)
        if titles.isEmpty {
            if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
                for win in windowList {
                    if let winPid = win[kCGWindowOwnerPID as String] as? pid_t, winPid == pid,
                       let layer = win[kCGWindowLayer as String] as? Int, layer == 0,
                       let name = win[kCGWindowName as String] as? String, !name.isEmpty {
                        titles.append(name)
                        break
                    }
                }
            }
        }

        return titles
    }

    // MARK: - Distributed Notifications (Spotify & Apple Music)

    @objc private func handleSpotifyNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let state = (userInfo["Player State"] as? String) ?? ""
        let isPlaying = (state.lowercased() == "playing" || state.lowercased() == "kplaybackstateplaying")
        let title  = (userInfo["Name"]   as? String) ?? ""
        let artist = (userInfo["Artist"] as? String) ?? ""
        let album  = (userInfo["Album"]  as? String) ?? ""

        let durationVal = (userInfo["Duration"] as? NSNumber)?.doubleValue ?? 0.0
        let duration = durationVal > 1000 ? durationVal / 1000.0 : durationVal
        let elapsed = (userInfo["Playback Position"] as? NSNumber)?.doubleValue ?? 0.0

        guard !title.isEmpty else { return }

        let action = isPlaying ? "resume" : "pause"
        self.lastTitle = title
        self.lastArtist = artist.isEmpty ? "Spotify" : "\(artist) • Spotify"
        self.lastAlbum = album
        self.lastDuration = duration
        self.lastElapsedTime = elapsed
        self.lastIsPlaying = isPlaying
        self.lastBundleId = "com.spotify.client"

        let shouldTrigger = !isUserFocusedOnPlayingWindow(bundleId: "com.spotify.client", title: title)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manager?.updateMediaInfo(
                title:               title,
                artist:              self.lastArtist,
                album:               album,
                duration:            duration,
                elapsedTime:         elapsed,
                isPlaying:           isPlaying,
                mediaAction:         action,
                bundleId:            "com.spotify.client",
                triggerNotification: shouldTrigger
            )
        }
    }

    @objc private func handleAppleMusicNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let state = (userInfo["Player State"] as? String) ?? ""
        let isPlaying = (state.lowercased() == "playing")
        let title  = (userInfo["Name"]   as? String) ?? ""
        let artist = (userInfo["Artist"] as? String) ?? ""
        let album  = (userInfo["Album"]  as? String) ?? ""

        let durationVal = (userInfo["Total Time"] as? NSNumber)?.doubleValue ?? 0.0
        let duration = durationVal > 1000 ? durationVal / 1000.0 : durationVal
        let elapsed = (userInfo["Player Position"] as? NSNumber)?.doubleValue ?? 0.0

        guard !title.isEmpty else { return }

        let action = isPlaying ? "resume" : "pause"
        self.lastTitle = title
        self.lastArtist = artist.isEmpty ? "Music" : "\(artist) • Music"
        self.lastAlbum = album
        self.lastDuration = duration
        self.lastElapsedTime = elapsed
        self.lastIsPlaying = isPlaying
        self.lastBundleId = "com.apple.Music"

        let shouldTrigger = !isUserFocusedOnPlayingWindow(bundleId: "com.apple.Music", title: title)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manager?.updateMediaInfo(
                title:               title,
                artist:              self.lastArtist,
                album:               album,
                duration:            duration,
                elapsedTime:         elapsed,
                isPlaying:           isPlaying,
                mediaAction:         action,
                bundleId:            "com.apple.Music",
                triggerNotification: shouldTrigger
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
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, 0, nil, &size, &dev) == 0,
              dev != 0 else { return }

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

    private func checkOutputAudioState() {
        guard outputDevice != 0 else { return }
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(outputDevice, &runningAddress, 0, nil, &size, &isRunning) == 0 else { return }
        let currentlyRunning = (isRunning > 0)

        if currentlyRunning {
            audioPauseTimer?.invalidate()
            audioPauseTimer = nil
            if !self.isAudioRunning {
                self.isAudioRunning = true
            }
        } else {
            audioPauseTimer?.invalidate()
            audioPauseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.isAudioRunning {
                    self.isAudioRunning = false
                }
            }
        }
    }

    // MARK: - Public API (called from MediaKeyManager)

    func toggleOrFetchCurrentState(triggerNotification: Bool = true) {
        // Query the true playback state from MediaRemote without guessing or speculative inverting
        fetchOneShotState(triggerNotification: triggerNotification)
    }

    func fetchCurrentState(triggerNotification: Bool = false) {
        if self.lastTitle.isEmpty {
            fetchOneShotState(triggerNotification: triggerNotification)
            return
        }
        let shouldTrigger = triggerNotification && !isUserFocusedOnPlayingWindow(bundleId: self.lastBundleId, title: self.lastTitle)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.manager?.updateMediaInfo(
                title:               self.lastTitle,
                artist:              self.lastArtist,
                album:               self.lastAlbum,
                duration:            self.lastDuration,
                elapsedTime:         self.lastElapsedTime,
                isPlaying:           self.lastIsPlaying,
                mediaAction:         self.lastIsPlaying ? "resume" : "pause",
                bundleId:            self.lastBundleId,
                triggerNotification: shouldTrigger
            )
        }
    }

    private func fetchOneShotState(triggerNotification: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let oneShot = Process()
            let pipe = Pipe()
            oneShot.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            let script = """
            const b = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
            b.load;
            const req = $.NSClassFromString('MRNowPlayingRequest');
            const item = req ? req.localNowPlayingItem : null;
            const path = req ? req.localNowPlayingPlayerPath : null;
            let title = '', artist = '', album = '', duration = 0, elapsed = 0, isPlaying = false, appName = '', bundleId = '';
            if (item && item.nowPlayingInfo) {
                const d = item.nowPlayingInfo;
                try { const t = d.valueForKey('kMRMediaRemoteNowPlayingInfoTitle'); if (t) title = t.js; } catch(e){}
                try { const a = d.valueForKey('kMRMediaRemoteNowPlayingInfoArtist'); if (a) artist = a.js; } catch(e){}
                try { const al = d.valueForKey('kMRMediaRemoteNowPlayingInfoAlbum'); if (al) album = al.js; } catch(e){}
                try { const dur = d.valueForKey('kMRMediaRemoteNowPlayingInfoDuration'); if (dur) duration = dur.js; } catch(e){}
                try { const el = d.valueForKey('kMRMediaRemoteNowPlayingInfoElapsedTime'); if (el) elapsed = el.js; } catch(e){}
                try { const rate = d.valueForKey('kMRMediaRemoteNowPlayingInfoPlaybackRate'); if (rate && rate.js > 0) isPlaying = true; } catch(e){}
            }
            if (path && path.client) {
                try { appName = path.client.displayName.js || ''; } catch(e){}
                try { bundleId = path.client.parentApplicationBundleIdentifier.js || path.client.bundleIdentifier.js || ''; } catch(e){}
            }
            const s = JSON.stringify({ isInitial: false, title, artist, album, duration, elapsed, isPlaying, appName, bundleId }) + '\\n';
            $.NSFileHandle.fileHandleWithStandardOutput.writeData($.NSString.alloc.initWithString(s).dataUsingEncoding($.NSUTF8StringEncoding));
            """
            oneShot.arguments = ["-l", "JavaScript", "-e", script]
            oneShot.standardOutput = pipe
            oneShot.standardError = pipe
            do {
                try oneShot.run()
                oneShot.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    self?.parseJSON(str)
                }
            } catch {}
        }
    }

    deinit {
        audioPauseTimer?.invalidate()
        audioPauseTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
        helperProcess?.terminationHandler = nil
        helperProcess?.terminate()
    }
}
