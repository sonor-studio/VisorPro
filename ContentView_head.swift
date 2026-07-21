    
    enum OverlayType: String, CaseIterable {
        case volume, brightness, battery, copy, capsLock, bluetooth, language, media, theme, mic, camera, wifi, peripheral
    }
    
    private func activeOverlays(for position: String) -> [OverlayType] {
        var active: [OverlayType] = []
        
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning
        
        if mediaKeyManager.showVolumeIndicator && volumeOverlayPosition == position { active.append(.volume) }
        if mediaKeyManager.showBrightnessIndicator && brightnessOverlayPosition == position { active.append(.brightness) }
        if showBattery && batteryOverlayPosition == position { active.append(.battery) }
        if mediaKeyManager.showCopyIndicator && copyOverlayPosition == position { active.append(.copy) }
        if mediaKeyManager.showCapsLockIndicator && capsLockOverlayPosition == position { active.append(.capsLock) }
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        if !mediaKeyManager.activeBluetoothNotifications.isEmpty && btPos == position { active.append(.bluetooth) }
        
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        if mediaKeyManager.showLanguageIndicator && langPos == position { active.append(.language) }
        
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        if mediaKeyManager.showMediaIndicator && mediaPos == position { active.append(.media) }
        
        let themePos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "bottom"
        if mediaKeyManager.showThemeIndicator && themePos == position { active.append(.theme) }
        
        let micPos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
        if mediaKeyManager.showMicIndicator && micPos == position { active.append(.mic) }
        
        let camPos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
        if mediaKeyManager.showCameraIndicator && camPos == position { active.append(.camera) }
        
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        if mediaKeyManager.showWiFiIndicator && wifiPos == position { active.append(.wifi) }
        
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        if !mediaKeyManager.activePeripheralNotifications.isEmpty && periPos == position { active.append(.peripheral) }
        
        // Zastosuj limit jednoczesnych powiadomień
        let limit = max(1, mediaKeyManager.maxSimultaneousNotifications)
        return Array(active.prefix(limit))
    }
    
    private func yPos(for position: String, index: Int, in geo: GeometryProxy) -> CGFloat {
        let padding: CGFloat = 40
        let pillHeight: CGFloat = 56
        let spacing: CGFloat = 16
        
        let offset = CGFloat(index) * (pillHeight + spacing)
        
        if position == "top" {
            return padding + (pillHeight / 2) + offset
        } else {
            return geo.size.height - padding - (pillHeight / 2) - offset
        }
    }
    
    var body: some View {
        let showBattery = mediaKeyManager.showChargingStatus || mediaKeyManager.showLowBatteryWarning
        let showVolume = mediaKeyManager.showVolumeIndicator
        let showBrightness = mediaKeyManager.showBrightnessIndicator
        let showCopy = mediaKeyManager.showCopyIndicator
        let showCapsLock = mediaKeyManager.showCapsLockIndicator
        let showBluetooth = !mediaKeyManager.activeBluetoothNotifications.isEmpty
        let showLanguage = mediaKeyManager.showLanguageIndicator
        let showMedia = mediaKeyManager.showMediaIndicator
        let showTheme = mediaKeyManager.showThemeIndicator
        let showMic = mediaKeyManager.showMicIndicator
        let showCamera = mediaKeyManager.showCameraIndicator
        let showWiFi = mediaKeyManager.showWiFiIndicator
        let showPeripheral = !mediaKeyManager.activePeripheralNotifications.isEmpty
        
        let isVisible = showBattery || showVolume || showBrightness || showCopy || showCapsLock || showBluetooth || showLanguage || showMedia || showTheme || showMic || showCamera || showWiFi || showPeripheral
        
        let btPos = UserDefaults.standard.string(forKey: "bluetoothOverlayPosition") ?? "bottom"
        let langPos = UserDefaults.standard.string(forKey: "languageOverlayPosition") ?? "bottom"
        let mediaPos = UserDefaults.standard.string(forKey: "mediaOverlayPosition") ?? "bottom"
        let themePos = UserDefaults.standard.string(forKey: "themeOverlayPosition") ?? "bottom"
        let micPos = UserDefaults.standard.string(forKey: "micOverlayPosition") ?? "top"
        let camPos = UserDefaults.standard.string(forKey: "cameraOverlayPosition") ?? "top"
        let wifiPos = UserDefaults.standard.string(forKey: "wifiOverlayPosition") ?? "bottom"
        let periPos = UserDefaults.standard.string(forKey: "peripheralOverlayPosition") ?? "bottom"
        
        GeometryReader { geo in
            ZStack {
                if let index = activeOverlays(for: volumeOverlayPosition).firstIndex(of: .volume) {
                    VolumeOverlayView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: volumeOverlayPosition, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: brightnessOverlayPosition).firstIndex(of: .brightness) {
                    BrightnessOverlayView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: brightnessOverlayPosition, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: batteryOverlayPosition).firstIndex(of: .battery) {
                    BatteryOverlayView(isWarningMode: mediaKeyManager.showLowBatteryWarning && !mediaKeyManager.isPluggedIn)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: batteryOverlayPosition, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: copyOverlayPosition).firstIndex(of: .copy) {
                    CopyOverlayView()
                        .id(mediaKeyManager.clipboardEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: copyOverlayPosition, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: capsLockOverlayPosition).firstIndex(of: .capsLock) {
                    CapsLockOverlayView()
                        .id(mediaKeyManager.capsLockEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: capsLockOverlayPosition, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: btPos).firstIndex(of: .bluetooth) {
                    BluetoothOverlayView()
                        .id(mediaKeyManager.bluetoothEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: btPos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: langPos).firstIndex(of: .language) {
                    LanguageOverlayView()
                        .id(mediaKeyManager.languageEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: langPos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: mediaPos).firstIndex(of: .media) {
                    MediaOverlayView()
                        .id(mediaKeyManager.mediaEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: mediaPos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: themePos).firstIndex(of: .theme) {
                    ThemeOverlayView()
                        .id(mediaKeyManager.themeEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: themePos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: micPos).firstIndex(of: .mic) {
                    MicOverlayView()
                        .id(mediaKeyManager.micEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: micPos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: camPos).firstIndex(of: .camera) {
                    CameraOverlayView()
                        .id(mediaKeyManager.cameraEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: camPos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: wifiPos).firstIndex(of: .wifi) {
                    WiFiOverlayView()
                        .id(mediaKeyManager.wiFiEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: wifiPos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
                
                if let index = activeOverlays(for: periPos).firstIndex(of: .peripheral) {
                    PeripheralOverlayView()
                        .id(mediaKeyManager.peripheralEventId)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .position(x: geo.size.width / 2, y: yPos(for: periPos, index: index, in: geo))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.easeInOut(duration: 0.25), value: showVolume)
        .animation(.easeInOut(duration: 0.25), value: showBrightness)
        .animation(.easeInOut(duration: 0.25), value: showBattery)
        .animation(.easeInOut(duration: 0.25), value: showCopy)
        .animation(.easeInOut(duration: 0.25), value: showCapsLock)
        .animation(.easeInOut(duration: 0.25), value: showBluetooth)
        .animation(.easeInOut(duration: 0.25), value: showLanguage)
        .animation(.easeInOut(duration: 0.25), value: showMedia)
        .animation(.easeInOut(duration: 0.25), value: showTheme)
