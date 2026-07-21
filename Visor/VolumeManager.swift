import Foundation
import Cocoa
import CoreAudio

class VolumeManager {
    static let shared = VolumeManager()
    
    private let queue = DispatchQueue(label: "com.visor.volumeQueue")
    
    private var cachedVolume: Int = 50
    private var cachedMuted: Bool = false
    private var isInitialized: Bool = false
    private var pendingTask: DispatchWorkItem?
    
    init() {
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
        
        guard status == noErr else { return "Internal speakers" }
        
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
        
        guard nameStatus == noErr else { return "Internal speakers" }
        
        return deviceName as String
    }
    
    func changeVolume(increase: Bool, completion: @escaping (Int, Bool) -> Void) {
        DispatchQueue.main.async {
            if !self.isInitialized {
                self.cachedVolume = 50
                self.isInitialized = true
            }
            
            let step = 6.25
            var newVol = Double(self.cachedVolume) + (increase ? step : -step)
            if newVol < 0 { newVol = 0 }
            if newVol > 100 { newVol = 100 }
            
            self.cachedVolume = Int(newVol)
            self.cachedMuted = false
            
            let targetVol = self.cachedVolume
            let targetMuted = self.cachedMuted
            
            // Optymistyczna aktualizacja UI – natychmiastowa reakcja
            completion(targetVol, targetMuted)
            
            self.pendingTask?.cancel()
            
            let task = DispatchWorkItem {
                let script = "set volume output volume \(targetVol)\nset volume output muted false"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            
            self.pendingTask = task
            self.queue.asyncAfter(deadline: .now() + 0.05, execute: task)
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
                        self.cachedVolume = newVol
                        self.cachedMuted = isMuted
                        self.isInitialized = true
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
    
    func increaseVolume(completion: @escaping (Int, Bool) -> Void) {
        changeVolume(increase: true, completion: completion)
    }
    
    func decreaseVolume(completion: @escaping (Int, Bool) -> Void) {
        changeVolume(increase: false, completion: completion)
    }
    
    func toggleMute(completion: @escaping (Int, Bool) -> Void) {
        DispatchQueue.main.async {
            if !self.isInitialized {
                self.cachedVolume = 50
                self.isInitialized = true
            }
            
            self.cachedMuted.toggle()
            
            let targetVol = self.cachedVolume
            let targetMuted = self.cachedMuted
            
            if !targetMuted {
                // Dźwięk jest teraz odtwarzany globalnie przez MediaKeyManager
            }
            completion(targetVol, targetMuted)
            
            self.pendingTask?.cancel()
            
            let task = DispatchWorkItem {
                let script = "set volume output muted \(targetMuted ? "true" : "false")"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            
            self.pendingTask = task
            self.queue.asyncAfter(deadline: .now() + 0.05, execute: task)
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
