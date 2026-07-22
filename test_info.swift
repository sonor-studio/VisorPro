import Foundation

let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
    print("Could not find MRMediaRemoteGetNowPlayingInfo")
    exit(1)
}

typealias MRMediaRemoteGetNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
let getInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunc.self)

let semaphore = DispatchSemaphore(value: 0)

getInfo(DispatchQueue.main) { info in
    for (key, value) in info {
        print("\(key): \(value)")
    }
    semaphore.signal()
}

semaphore.wait()
