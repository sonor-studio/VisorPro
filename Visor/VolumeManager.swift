import Foundation
import Cocoa
import CoreAudio

class VolumeManager {
    static let shared = VolumeManager()
    
    private let soundFile = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
    private var volumeSound: NSSound?
    private let queue = DispatchQueue(label: "com.visor.volumeQueue")
    
    init() {
        if FileManager.default.fileExists(atPath: soundFile) {
            volumeSound = NSSound(contentsOfFile: soundFile, byReference: true)
        } else {
            volumeSound = NSSound(named: "Pop")
        }
    }
    
    func getCurrentAudioDeviceName() -> String {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultOutputDevicePropertyAddress,
            0,
            nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )
        
        guard status == noErr else { return "Wewnętrzne głośniki" }
        
        var deviceName = "" as CFString
        var deviceNameSize = UInt32(MemoryLayout<CFString>.size)
        
        var deviceNamePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let nameStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &deviceNamePropertyAddress,
            0,
            nil,
            &deviceNameSize,
            &deviceName
        )
        
        guard nameStatus == noErr else { return "Wewnętrzne głośniki" }
        
        return deviceName as String
    }
    
    func changeVolume(increase: Bool, completion: @escaping (Int, Bool) -> Void) {
        queue.async {
            let script = """
            set vol to output volume of (get volume settings)
            if \(increase ? "true" : "false") then
                set vol to vol + 6.25
            else
                set vol to vol - 6.25
            end if
            if vol < 0 then set vol to 0
            if vol > 100 then set vol to 100
            set volume output volume vol
            set isMuted to output muted of (get volume settings)
            return {vol, isMuted}
            """
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                if error == nil {
                    let newVol = Int(result.atIndex(1)?.int32Value ?? 50)
                    let isMuted = result.atIndex(2)?.booleanValue ?? false
                    DispatchQueue.main.async {
                        self.playSound()
                        completion(newVol, isMuted)
                    }
                } else {
                    print("AppleScript Error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        completion(50, false)
                    }
                }
            }
        }
    }
    
    func fetchCurrentVolume(completion: @escaping (Int, Bool) -> Void) {
        queue.async {
            let script = """
            set vol to output volume of (get volume settings)
            set isMuted to output muted of (get volume settings)
            return {vol, isMuted}
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                if error == nil {
                    let newVol = Int(result.atIndex(1)?.int32Value ?? 50)
                    let isMuted = result.atIndex(2)?.booleanValue ?? false
                    DispatchQueue.main.async {
                        completion(newVol, isMuted)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(50, false)
                    }
                }
            }
        }
    }
    
    private func playSound() {
        if let sound = volumeSound {
            // Zatrzymujemy poprzedni dźwięk przed odtworzeniem kolejnego
            if sound.isPlaying {
                sound.stop()
            }
            sound.play()
        } else {
            NSSound.beep()
        }
    }
    
    func increaseVolume(completion: @escaping (Int, Bool) -> Void) {
        changeVolume(increase: true, completion: completion)
    }
    
    func decreaseVolume(completion: @escaping (Int, Bool) -> Void) {
        changeVolume(increase: false, completion: completion)
    }
    
    func toggleMute(completion: @escaping (Int, Bool) -> Void) {
        queue.async {
            let script = """
            set isMuted to output muted of (get volume settings)
            set volume output muted (not isMuted)
            set newMuted to output muted of (get volume settings)
            set vol to output volume of (get volume settings)
            return {vol, newMuted}
            """
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                if error == nil {
                    let newVol = Int(result.atIndex(1)?.int32Value ?? 50)
                    let isNowMuted = result.atIndex(2)?.booleanValue ?? false
                    
                    DispatchQueue.main.async {
                        if !isNowMuted {
                            self.playSound()
                        }
                        completion(newVol, isNowMuted)
                    }
                } else {
                    print("AppleScript Mute Error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        completion(50, false)
                    }
                }
            }
        }
    }
}

class BrightnessManager {
    static let shared = BrightnessManager()
    
    private let queue = DispatchQueue(label: "com.visor.brightnessQueue")
    
    private var DisplayServicesGetBrightness: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    private var DisplayServicesSetBrightness: (@convention(c) (CGDirectDisplayID, Float) -> Int32)?
    
    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        if handle != nil {
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                typealias GetFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
                DisplayServicesGetBrightness = unsafeBitCast(getSym, to: GetFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                typealias SetFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
                DisplayServicesSetBrightness = unsafeBitCast(setSym, to: SetFunc.self)
            }
        } else {
            print("Could not load DisplayServices.framework")
        }
    }
    
    func fetchCurrentBrightness(completion: @escaping (Int) -> Void) {
        queue.async {
            var brightness: Float = 0.5
            if let getFunc = self.DisplayServicesGetBrightness {
                let _ = getFunc(CGMainDisplayID(), &brightness)
            }
            let intBrightness = Int(brightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
    
    func changeBrightness(increase: Bool, completion: @escaping (Int) -> Void) {
        queue.async {
            var currentBrightness: Float = 0.5
            if let getFunc = self.DisplayServicesGetBrightness {
                let _ = getFunc(CGMainDisplayID(), &currentBrightness)
            }
            
            let step: Float = 1.0 / 16.0
            var newBrightness = increase ? currentBrightness + step : currentBrightness - step
            newBrightness = max(0.0, min(1.0, newBrightness))
            
            if let setFunc = self.DisplayServicesSetBrightness {
                let _ = setFunc(CGMainDisplayID(), newBrightness)
            }
            
            let intBrightness = Int(newBrightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
    
    func increaseBrightness(completion: @escaping (Int) -> Void) {
        changeBrightness(increase: true, completion: completion)
    }
    
    func decreaseBrightness(completion: @escaping (Int) -> Void) {
        changeBrightness(increase: false, completion: completion)
    }
}
