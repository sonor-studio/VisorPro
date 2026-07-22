import Foundation

let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) else {
    print("Could not find MRMediaRemoteSetElapsedTime")
    exit(1)
}
typealias MRMediaRemoteSetElapsedTimeFunc = @convention(c) (Double) -> Void
let setElapsedTime = unsafeBitCast(pointer, to: MRMediaRemoteSetElapsedTimeFunc.self)

setElapsedTime(60.0) // Seek to 1 minute
print("Seek command sent")
