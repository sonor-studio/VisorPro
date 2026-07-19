import Foundation
import CoreAudio

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
    
    guard status == noErr else { return "Unknown Device" }
    
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
    
    guard nameStatus == noErr else { return "Speaker" }
    
    return deviceName as String
}

print("Device: \(getCurrentAudioDeviceName())")
