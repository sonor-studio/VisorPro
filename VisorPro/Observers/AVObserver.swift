import Cocoa
import CoreAudio
import CoreMediaIO
import AVFoundation

class AVObserver {
    weak var manager: MediaKeyManager?
    
    private var micDevices = [AudioDeviceID]()
    private var cameraDevices = [CMIODeviceID]()
    
    init(manager: MediaKeyManager) {
        self.manager = manager
    }
    
    func startObserving() {
        setupMicObserver()
        setupCameraObserver()
    }
    
    private func setupMicObserver() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.rebuildMicDevices()
        }
        
        rebuildMicDevices()
    }
    
    private func rebuildMicDevices() {
        // We don't strictly need to remove old listeners because AudioObjectAddPropertyListenerBlock with the same block on the same device just adds it or is safe, but ideally we'd remove. For simplicity, we just rebuild the list.
        micDevices.removeAll()
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &devices)
        
        for device in devices {
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(device, &streamAddr, 0, nil, &streamSize)
            if streamSize > 0 {
                if !micDevices.contains(device) {
                    micDevices.append(device)
                    
                    var runningAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    
                    AudioObjectAddPropertyListenerBlock(device, &runningAddress, DispatchQueue.main) { [weak self] _, _ in
                        self?.checkMicState()
                    }
                }
            }
        }
        
        checkMicState()
    }
    
    private func checkMicState() {
        var isAnyRunning = false
        var activeDeviceName = ""
        
        for device in micDevices {
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var isRunning: UInt32 = 0
            var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
            let err = AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &size, &isRunning)
            if err == 0 && isRunning > 0 {
                isAnyRunning = true
                activeDeviceName = getAudioDeviceName(deviceID: device)
                break
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.micDebounceTimer?.invalidate()
            
            if isAnyRunning {
                if self.manager?.isMicActive != true {
                    self.manager?.triggerMicIndicator(isActive: true, deviceName: activeDeviceName)
                }
            } else {
                self.micDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                    if self?.manager?.isMicActive == true {
                        self?.manager?.triggerMicIndicator(isActive: false, deviceName: "")
                    }
                }
            }
        }
    }
    
    private func setupCameraObserver() {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        var devices = [CMIODeviceID](repeating: 0, count: deviceCount)
        
        CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, dataSize, &dataUsed, &devices)
        
        for device in devices {
            cameraDevices.append(device)
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            
            CMIOObjectAddPropertyListenerBlock(device, &runningAddress, DispatchQueue.main) { [weak self] _, _ in
                self?.checkCameraState()
            }
        }
        
        checkCameraState()
    }
    
    private var cameraDebounceTimer: Timer?
    private var micDebounceTimer: Timer?
    
    private func checkCameraState() {
        var isAnyRunning = false
        var activeDeviceName = ""
        
        for device in cameraDevices {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            
            var isRunning: UInt32 = 0
            var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
            let err = CMIOObjectGetPropertyData(device, &runningAddress, 0, nil, size, &size, &isRunning)
            if err == 0 && isRunning > 0 {
                isAnyRunning = true
                activeDeviceName = getCameraDeviceName(deviceID: device)
                break
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isAnyRunning {
                self.cameraDebounceTimer?.invalidate()
                self.cameraDebounceTimer = nil
                
                if self.manager?.isCameraActive != true {
                    self.manager?.triggerCameraIndicator(isActive: true, deviceName: activeDeviceName)
                }
            } else {
                if self.cameraDebounceTimer == nil {
                    self.cameraDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        if self.manager?.isCameraActive == true {
                            self.manager?.triggerCameraIndicator(isActive: false, deviceName: "")
                        }
                        self.cameraDebounceTimer = nil
                    }
                }
            }
        }
    }

    
    private func getAudioDeviceName(deviceID: AudioDeviceID) -> String {
        var name = ""
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        if AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr {
            var nameCF: CFString? = nil
            var size2 = UInt32(MemoryLayout<CFString?>.size)
            let status = withUnsafeMutablePointer(to: &nameCF) { ptr in
                AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size2, ptr)
            }
            if status == noErr {
                if let nameString = nameCF as String? {
                    name = nameString
                }
            }
        }
        return name
    }
    
    private func getCameraDeviceName(deviceID: CMIODeviceID) -> String {
        var name = ""
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        if CMIOObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr {
            var nameCF: CFString? = nil
            let size2 = UInt32(MemoryLayout<CFString?>.size)
            var dataUsed: UInt32 = 0
            let status = withUnsafeMutablePointer(to: &nameCF) { ptr in
                CMIOObjectGetPropertyData(deviceID, &address, 0, nil, size2, &dataUsed, ptr)
            }
            if status == noErr {
                if let nameString = nameCF as String? {
                    name = nameString
                }
            }
        }
        return name
    }
    
    func getAvailableCameraDevices() -> [(id: UInt32, name: String)] {
        var devicesList = [(id: UInt32, name: String)]()
        for device in cameraDevices {
            let name = getCameraDeviceName(deviceID: device)
            if !name.isEmpty {
                devicesList.append((id: device, name: name))
            }
        }
        return devicesList
    }
}

class CameraClientObserver {
    weak var manager: MediaKeyManager?
    
    init(manager: MediaKeyManager) {
        self.manager = manager
    }
    
    func fetchActiveCameraClient() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.launchPath = "/usr/bin/log"
            process.arguments = ["show", "--predicate", "subsystem == 'com.apple.cmio' AND eventMessage CONTAINS 'CMIODeviceStartStream'", "--last", "1m", "--style", "json"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                if jsonArray == nil || jsonArray?.isEmpty == true {
                    DispatchQueue.main.async {
                        self?.manager?.finalizeCameraIndicator(appName: "")
                    }
                }
                if let jsonArray = jsonArray {
                    if let lastEntry = jsonArray.last,
                       let pid = lastEntry["processID"] as? Int,
                       let path = lastEntry["processImagePath"] as? String {
                        
                        var appName = ""
                        var iconPath = path
                        
                        if let range = path.range(of: ".app/") {
                            let appBundlePath = String(path[..<range.lowerBound]) + ".app"
                            appName = FileManager.default.displayName(atPath: appBundlePath).replacingOccurrences(of: ".app", with: "")
                            iconPath = appBundlePath
                        }
                        
                        if appName.isEmpty {
                            appName = NSRunningApplication(processIdentifier: Int32(pid))?.localizedName ?? (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                        }
                        
                        let lowerName = appName.lowercased()
                        if lowerName.contains("webkit") || lowerName.contains("safari") {
                            appName = "Safari"
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                                iconPath = url.path
                            }
                        } else if lowerName.contains("avconferenced") {
                            appName = "FaceTime"
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.FaceTime") {
                                iconPath = url.path
                            }
                        } else if lowerName.contains("apple account") || lowerName.starts(with: "sys") {
                            appName = "System Settings"
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
                                iconPath = url.path
                            }
                        } else if appName.starts(with: "com.apple.") {
                            appName = appName.replacingOccurrences(of: "com.apple.", with: "")
                            if appName.contains(".") {
                                appName = appName.components(separatedBy: ".").last ?? appName
                            }
                        } else if appName.contains(".") && !appName.contains(" ") {
                            appName = appName.components(separatedBy: ".").last ?? appName
                        }
                        
                        DispatchQueue.main.async {
                            if let manager = self?.manager {
                                if !appName.isEmpty {
                                    manager.activeCameraClientName = appName
                                    manager.activeCameraClientBundleID = iconPath
                                    manager.activeCameraClientPID = Int32(pid)
                                }
                                manager.finalizeCameraIndicator(appName: appName)
                            }
                        }
                    }
                }
            } catch {
            }
        }
    }
    
    func startObserving() {
        // precyzyjnego `log show` dla CoreMediaIO w fetchActiveCameraClient(),
    }
    
    func stopObserving() {
    }
    
    deinit {
    }
    
    func fetchActiveMicClient() {
        let task = Process()
        task.launchPath = "/usr/bin/log"
        // coreaudio logs use "Started  Input" (with two spaces)
        task.arguments = [
            "show",
            "--last", "1m",
            "--predicate", "subsystem == 'com.apple.coreaudio' AND eventMessage CONTAINS 'Started  Input'",
            "--style", "json"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                
                guard let self = self else { return }
                
                let logs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                if logs == nil || logs?.isEmpty == true {
                    DispatchQueue.main.async {
                        self.manager?.finalizeMicIndicator(appName: "")
                    }
                }
                
                if let logs = logs {
                    if let lastLog = logs.last {
                        var appName = ""
                        var iconPath = ""
                        var pid: Int? = nil
                        
                        if let path = lastLog["processImagePath"] as? String {
                            iconPath = path
                            let url = URL(fileURLWithPath: path)
                            
                            if let appRange = path.range(of: ".app/") {
                                let bundlePath = String(path[..<appRange.upperBound]).dropLast()
                                let bundleURL = URL(fileURLWithPath: String(bundlePath))
                                appName = bundleURL.deletingPathExtension().lastPathComponent
                                iconPath = String(bundlePath)
                            } else {
                                appName = url.lastPathComponent
                            }
                            
                            let lowerName = appName.lowercased()
                            if lowerName.contains("webkit") || lowerName.contains("safari") {
                                appName = "Safari"
                                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") { iconPath = url.path }
                            } else if lowerName.contains("avconferenced") {
                                appName = "FaceTime"
                                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.FaceTime") { iconPath = url.path }
                            } else if lowerName.contains("corespeechd") || lowerName.contains("siri") {
                                appName = "Siri"
                                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Siri") { iconPath = url.path }
                            } else if lowerName.contains("apple account") || lowerName.starts(with: "sys") {
                                appName = "System Settings"
                                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") { iconPath = url.path }
                            } else if appName.starts(with: "com.apple.") {
                                appName = appName.replacingOccurrences(of: "com.apple.", with: "")
                                if appName.contains(".") {
                                    appName = appName.components(separatedBy: ".").last ?? appName
                                }
                            } else if appName.contains(".") && !appName.contains(" ") {
                                appName = appName.components(separatedBy: ".").last ?? appName
                            }
                        }
                        
                        if let processID = lastLog["processID"] as? Int32 {
                            pid = Int(processID)
                        } else if let processID = lastLog["processID"] as? Int {
                            pid = processID
                        }
                        
                        DispatchQueue.main.async {
                            if !appName.isEmpty {
                                self.manager?.activeMicClientName = appName
                                self.manager?.activeMicClientBundleID = iconPath
                                self.manager?.activeMicClientPID = pid
                            }
                            self.manager?.finalizeMicIndicator(appName: appName)
                        }
                    }
                }
            }
        } catch {
        }
    }}
