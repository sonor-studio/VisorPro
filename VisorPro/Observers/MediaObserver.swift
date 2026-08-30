import Cocoa
import Foundation

class MediaObserver {
    private weak var manager: MediaKeyManager?
    private var helperProcess: Process?
    private var outputPipe: Pipe?
    
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
    }
    
    func startObserving() {
        startHelperScript()
    }
    
    private func startHelperScript() {
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("visor_media_helper.swift").path
        let scriptContent = """
        import Foundation
        import Cocoa

        let bundleURL = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL) else { exit(1) }

        let infoPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString)!
        let isPlayingPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString)!
        let registerPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString)!
        let clientPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingClient" as CFString)!

        typealias InfoFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (NSDictionary?) -> Void) -> Void
        typealias IsPlayingFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (Bool) -> Void) -> Void
        typealias ClientFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (AnyObject?) -> Void) -> Void
        typealias RegisterFunc = @convention(c) (DispatchQueue) -> Void

        let getInfo = unsafeBitCast(infoPtr, to: InfoFunc.self)
        let getIsPlaying = unsafeBitCast(isPlayingPtr, to: IsPlayingFunc.self)
        let getClient = unsafeBitCast(clientPtr, to: ClientFunc.self)
        let register = unsafeBitCast(registerPtr, to: RegisterFunc.self)

        func printState() {
            getClient(DispatchQueue.main) { client in
                let clientObj = client as? NSObject
                let appName = (clientObj?.value(forKey: "displayName") as? String) ?? ""
                let bundleId = (clientObj?.value(forKey: "parentApplicationBundleIdentifier") as? String) ?? (clientObj?.value(forKey: "bundleIdentifier") as? String) ?? ""
                
                getIsPlaying(DispatchQueue.main) { isPlaying in
                    getInfo(DispatchQueue.main) { info in
                        let infoDict = (info as? [String: Any]) ?? [:]
                        let title = infoDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
                        let artist = infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                        let album = infoDict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
                        let durVal = infoDict["kMRMediaRemoteNowPlayingInfoDuration"]
                        let duration = (durVal as? Double) ?? (durVal as? NSNumber)?.doubleValue ?? (durVal as? String).flatMap { Double($0) } ?? 0.0
                        let elapsedVal = infoDict["kMRMediaRemoteNowPlayingInfoElapsedTime"]
                        let elapsedTime = (elapsedVal as? Double) ?? (elapsedVal as? NSNumber)?.doubleValue ?? (elapsedVal as? String).flatMap { Double($0) } ?? 0.0
                        
                        let dict: [String: Any] = [
                            "title": title, "artist": artist, "album": album, "duration": duration, "elapsedTime": elapsedTime, "isPlaying": isPlaying, "appName": appName, "bundleId": bundleId
                        ]
                        if let data = try? JSONSerialization.data(withJSONObject: dict), let jsonStr = String(data: data, encoding: .utf8) {
                            print(jsonStr)
                            fflush(stdout)
                        }
                    }
                }
            }
        }

        class Observer {
            @objc func changed() { printState() }
        }
        let obs = Observer()

        register(DispatchQueue.main)
        NotificationCenter.default.addObserver(obs, selector: #selector(Observer.changed), name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil)
        NotificationCenter.default.addObserver(obs, selector: #selector(Observer.changed), name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil)
        NotificationCenter.default.addObserver(obs, selector: #selector(Observer.changed), name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification"), object: nil)

        printState()
        RunLoop.main.run()
        """
        
        do {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        } catch {
            return
        }
        
        helperProcess = Process()
        helperProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        helperProcess?.arguments = [scriptPath]
        
        outputPipe = Pipe()
        helperProcess?.standardOutput = outputPipe
        
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                for line in lines {
                    self.parseJSON(line, triggerNotification: false) // We handle explicit triggers via key
                }
            }
        }
        
        do {
            try helperProcess?.run()
        } catch {
        }
    }
    
    private func parseJSON(_ jsonString: String, triggerNotification: Bool = false) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        let title = json["title"] as? String ?? ""
        let artistRaw = json["artist"] as? String ?? ""
        let album = json["album"] as? String ?? ""
        let appName = json["appName"] as? String ?? ""
        let bundleId = json["bundleId"] as? String ?? ""
        
        let qlBundle = bundleId.lowercased()
        let qlApp = appName.lowercased()
        if qlBundle.contains("quicklook") || qlBundle.contains("finder") || qlApp.contains("quick look") || qlApp.contains("quick look") || qlApp == "finder" {
            return
        }
        
        var finalArtist = ""
        _ = ["Safari", "Google Chrome", "Chrome", "Brave Browser", "Arc", "Edge", "Firefox"]
        
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
        
        let duration = json["duration"] as? Double ?? 0.0
        let elapsedTime = json["elapsedTime"] as? Double ?? 0.0
        let isPlaying = json["isPlaying"] as? Bool ?? false
        
        var shouldTrigger = triggerNotification
        var mediaAction = "pause"
        
        if self.isFirstRun {
            self.isFirstRun = false
            mediaAction = isPlaying ? "resume" : "pause"
        } else {
            // Wykrywanie konkretnej akcji
            if self.lastTitle != title && !title.isEmpty {
                mediaAction = "start"
                shouldTrigger = true
            } else if self.lastIsPlaying != isPlaying {
                shouldTrigger = true
                if isPlaying {
                    if elapsedTime < 1.0 {
                        mediaAction = "start"
                    } else {
                        mediaAction = "resume"
                    }
                } else {
                    if duration > 0 && elapsedTime >= (duration - 2.0) {
                        mediaAction = "end"
                    } else {
                        mediaAction = "pause"
                    }
                }
            } else {
                mediaAction = isPlaying ? "resume" : "pause"
            }
        }
        
        if shouldTrigger && !bundleId.isEmpty {
            if let activeApp = NSWorkspace.shared.frontmostApplication {
                if activeApp.bundleIdentifier == bundleId {
                    let browserBundles = ["com.apple.Safari", "com.google.Chrome", "com.brave.Browser", "company.thebrowser.Browser", "com.microsoft.edgemac", "org.mozilla.firefox"]
                    if browserBundles.contains(bundleId) {
                        let winTitles = getActiveWindowTitles(pid: activeApp.processIdentifier)
                        let cleanMediaTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
                        
                        for winTitle in winTitles {
                            let cleanWinTitle = winTitle.lowercased().trimmingCharacters(in: .whitespaces)
                            
                            if cleanWinTitle.contains("youtube") || cleanWinTitle.contains("tiktok") || cleanWinTitle.contains("instagram") || cleanWinTitle.contains("shorts") || cleanWinTitle.contains("reels") {
                                shouldTrigger = false
                                break
                            }
                            
                            let cleanWinTitleStripped = cleanWinTitle.replacingOccurrences(of: " - youtube", with: "")
                            
                            if !cleanWinTitleStripped.isEmpty && !cleanMediaTitle.isEmpty && (cleanWinTitleStripped.contains(cleanMediaTitle) || cleanMediaTitle.contains(cleanWinTitleStripped)) {
                                shouldTrigger = false
                                break
                            }
                        }
                    } else {
                        shouldTrigger = false
                    }
                }
            }
        }
        // --------------------------------------------------------------------------
        
        self.lastIsPlaying = isPlaying
        self.lastTitle = title
        self.lastArtist = finalArtist
        self.lastAlbum = album
        self.lastDuration = duration
        self.lastElapsedTime = elapsedTime
        
        DispatchQueue.main.async {
            self.manager?.updateMediaInfo(
                title: title,
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
            let window = focusedWindow as! AXUIElement
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title) == .success, let t = title as? String {
                titles.append(t)
            }
        }
        
        var mainWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWindow) == .success {
            let window = mainWindow as! AXUIElement
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title) == .success, let t = title as? String {
                titles.append(t)
            }
        }
        
        return titles
    }
    
    func fetchCurrentState(triggerNotification: Bool = false) {
        // Trigger a fresh output from the helper by killing and restarting, or just read the latest state
        // To be instant, we can just trigger UI with what we have since the helper is always listening!
        DispatchQueue.main.async {
            self.manager?.updateMediaInfo(
                title: self.lastTitle,
                artist: self.lastArtist,
                album: self.lastAlbum,
                duration: self.lastDuration,
                elapsedTime: self.lastElapsedTime,
                isPlaying: self.lastIsPlaying,
                mediaAction: self.lastIsPlaying ? "resume" : "pause",
                bundleId: "",
                triggerNotification: triggerNotification
            )
        }
    }
    
    deinit {
        helperProcess?.terminate()
    }
}
