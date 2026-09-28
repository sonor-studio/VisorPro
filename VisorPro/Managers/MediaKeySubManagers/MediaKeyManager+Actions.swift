import Foundation
import AppKit
import SwiftUI

extension MediaKeyManager {
    func setVolume(to level: Int) {
        self.currentVolume = level
        VolumeManager.shared.setVolume(to: level) { _, _ in }
    }

    func toggleVolumeMute() {
        self.isMuted.toggle()
        VolumeManager.shared.toggleMute { _, _ in }
    }

    func setBrightness(to level: Int) {
        self.currentBrightness = level
        BrightnessManager.shared.setBrightness(to: level) { _ in }
    }

    func setKeyboardBrightness(to level: Int) {
        self.currentKeyboardBrightness = level
        KeyboardBrightnessManager.shared.setBrightness(to: level) { _ in }
    }

    func simulatePlayPause() {
        sendMediaRemoteCommand(2) // togglePlayPause
    }

    func simulateNext() {
        sendMediaRemoteCommand(4) // nextTrack
    }

    func simulatePrevious() {
        sendMediaRemoteCommand(5) // previousTrack
    }

    func setAirPodsMode(_ mode: Int) {
        guard !OverlayStateRelay.shared.isChangingAirPodsMode else { return }
        OverlayStateRelay.shared.isChangingAirPodsMode = true
        
        _ = self.airPodsModeObserver?.setMode(mode)
        
        // Failsafe: if the hardware doesn't respond within 2 seconds, unlock it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            OverlayStateRelay.shared.isChangingAirPodsMode = false
        }
    }

    func simulateSeek(to time: Double) {
        let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        if let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
            typealias MRMediaRemoteSetElapsedTimeFunc = @convention(c) (Double) -> Void
            let command = unsafeBitCast(pointer, to: MRMediaRemoteSetElapsedTimeFunc.self)
            command(time)
        }
    }

    func openMediaApp() {
        guard !mediaBundleId.isEmpty else { return }
        
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: mediaBundleId)
        if let app = runningApps.first {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        } else {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mediaBundleId) {
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            }
        }
    }

}
