import Foundation
import Cocoa

let bundleURL = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL) else {
    fputs("Failed to create MediaRemote CFBundle\n", stderr)
    exit(1)
}

if !CFBundleIsExecutableLoaded(bundle) {
    _ = CFBundleLoadExecutable(bundle)
}

guard
    let infoPtr      = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString),
    let isPlayingPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString),
    let registerPtr  = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString)
else {
    fputs("Failed to get MediaRemote function pointers\n", stderr)
    exit(1)
}

typealias InfoFunc      = @convention(c) (DispatchQueue, @escaping @convention(block) (NSDictionary?) -> Void) -> Void
typealias IsPlayingFunc = @convention(c) (DispatchQueue, @escaping @convention(block) (Bool) -> Void) -> Void
typealias RegisterFunc  = @convention(c) (DispatchQueue) -> Void
typealias AppPIDFunc    = @convention(c) (DispatchQueue, @escaping @convention(block) (Int32) -> Void) -> Void

let getInfo      = unsafeBitCast(infoPtr,      to: InfoFunc.self)
let getIsPlaying = unsafeBitCast(isPlayingPtr, to: IsPlayingFunc.self)
let register     = unsafeBitCast(registerPtr,  to: RegisterFunc.self)

// MRMediaRemoteGetNowPlayingApplicationPID — identifies the playing app by PID,
// independent of which app currently has focus.
let getAppPID: AppPIDFunc? = {
    guard let p = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationPID" as CFString) else { return nil }
    return unsafeBitCast(p, to: AppPIDFunc.self)
}()

func printState() {
    getIsPlaying(DispatchQueue.main) { isPlaying in
        getInfo(DispatchQueue.main) { info in
            let infoDict = (info as? [String: Any]) ?? [:]
            let title    = infoDict["kMRMediaRemoteNowPlayingInfoTitle"]  as? String ?? ""
            let artist   = infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album    = infoDict["kMRMediaRemoteNowPlayingInfoAlbum"]  as? String ?? ""

            let durVal   = infoDict["kMRMediaRemoteNowPlayingInfoDuration"]
            let duration = (durVal as? Double) ?? (durVal as? NSNumber)?.doubleValue ?? (durVal as? String).flatMap { Double($0) } ?? 0.0

            let elVal       = infoDict["kMRMediaRemoteNowPlayingInfoElapsedTime"]
            let elapsedTime = (elVal as? Double) ?? (elVal as? NSNumber)?.doubleValue ?? (elVal as? String).flatMap { Double($0) } ?? 0.0

            // Timestamp: seconds since NSDate reference date (2001-01-01) so the host
            // can calculate how stale the snapshot is and add the delta to elapsedTime.
            let tsDate = infoDict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date
            let timestamp = tsDate?.timeIntervalSinceReferenceDate ?? Date().timeIntervalSinceReferenceDate

            let rateVal      = infoDict["kMRMediaRemoteNowPlayingInfoPlaybackRate"]
            let playbackRate = (rateVal as? Double) ?? (rateVal as? NSNumber)?.doubleValue ?? 1.0

            // Identify the playing app by PID (not by focus)
            if let pidFunc = getAppPID {
                pidFunc(DispatchQueue.main) { pid in
                    var appName  = ""
                    var bundleId = ""
                    if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                        appName  = app.localizedName ?? ""
                        bundleId = app.bundleIdentifier ?? ""
                    }
                    emit(title: title, artist: artist, album: album, duration: duration,
                         elapsedTime: elapsedTime, timestamp: timestamp, playbackRate: playbackRate,
                         isPlaying: isPlaying, appName: appName, bundleId: bundleId)
                }
            } else {
                // Fallback: no PID function — emit without app identity
                emit(title: title, artist: artist, album: album, duration: duration,
                     elapsedTime: elapsedTime, timestamp: timestamp, playbackRate: playbackRate,
                     isPlaying: isPlaying, appName: "", bundleId: "")
            }
        }
    }
}

func emit(title: String, artist: String, album: String, duration: Double,
          elapsedTime: Double, timestamp: Double, playbackRate: Double,
          isPlaying: Bool, appName: String, bundleId: String) {
    let dict: [String: Any] = [
        "title":        title,
        "artist":       artist,
        "album":        album,
        "duration":     duration,
        "elapsedTime":  elapsedTime,
        "timestamp":    timestamp,
        "playbackRate": playbackRate,
        "isPlaying":    isPlaying,
        "appName":      appName,
        "bundleId":     bundleId
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict),
       let jsonStr = String(data: data, encoding: .utf8) {
        print(jsonStr)
        fflush(stdout)
    }
}

class Observer {
    @objc func changed() { printState() }
}
let obs = Observer()

register(DispatchQueue.main)
NotificationCenter.default.addObserver(obs, selector: #selector(Observer.changed),
    name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil)
NotificationCenter.default.addObserver(obs, selector: #selector(Observer.changed),
    name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil)
NotificationCenter.default.addObserver(obs, selector: #selector(Observer.changed),
    name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification"), object: nil)

printState()
RunLoop.main.run()
