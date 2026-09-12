import SwiftUI
import CoreWLAN

extension MediaKeyManager {
    
    func triggerWiFiIndicator(ssid: String, isConnected: Bool, isHotspot: Bool = false) {
        let premiumKey = UserDefaults.standard.string(forKey: "PremiumLicenseKey") ?? ""
        if premiumKey.isEmpty { return }

        if !enableWiFi { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.wifiHistory.contains(ssid) {
                self.wifiHistory.append(ssid)
            }
        }
        
        if isConnected && !notifyOnWiFiConnect { return }
        if !isConnected && !notifyOnWiFiDisconnect { return }
        if wifiBlocklist.contains(ssid) { return }
        
        let soundToPlay = isConnected ? soundOnWiFiConnect : soundOnWiFiDisconnect
        playNotificationSound(named: soundToPlay)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.wiFiTimer?.invalidate()
            
            let pos = self.getOverlayPosition(for: "wifiOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "wifi")
            
            self.wiFiSSID = ssid
            self.wiFiIsConnected = isConnected
            self.wiFiIsHotspot = isHotspot
            let executeShow = { [weak self] in
                guard let self = self else { return }

                self.wiFiEventId = UUID()

                withAnimation(.easeInOut(duration: 0.15)) {

                    self.showWiFiIndicator = true; self.overlayTriggerTimes["wifi"] = Date()
                    self.notifyOverlayStateChanged()

                }

                self.wiFiTimer = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in

                    withAnimation(.easeInOut(duration: 0.25)) {

                        self?.showWiFiIndicator = false

                    }

                }

            }

            

            if self.showWiFiIndicator {

                withAnimation(.easeInOut(duration: 0.25)) {

                    self.showWiFiIndicator = false

                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                    executeShow()

                }

            } else {

                executeShow()

            }
        }
    }
    
    func fetchWiFiDetails() {
        DispatchQueue.global(qos: .userInitiated).async {
            let interface = CWWiFiClient.shared().interface()
            
            let rssi = interface?.rssiValue() ?? 0
            let txRate = interface?.transmitRate() ?? 0.0
            
            var channelStr: String? = nil
            if let channel = interface?.wlanChannel() {
                let band: String
                if channel.channelBand == .band5GHz {
                    band = "5 GHz"
                } else if channel.channelBand == .band6GHz {
                    band = "6 GHz"
                } else {
                    band = "2.4 GHz"
                }
                channelStr = "Ch \(channel.channelNumber) (\(band))"
            }
            
            var ipAddr: String? = nil
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaddr) == 0 {
                var ptr = ifaddr
                while ptr != nil {
                    defer { ptr = ptr?.pointee.ifa_next }
                    
                    let interfaceInfo = ptr?.pointee
                    let addrFamily = interfaceInfo?.ifa_addr.pointee.sa_family
                    if addrFamily == UInt8(AF_INET) {
                        let name = String(cString: (interfaceInfo?.ifa_name)!)
                        if name == "en0" { // en0 is typically Wi-Fi on Mac
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(interfaceInfo?.ifa_addr, socklen_t((interfaceInfo?.ifa_addr.pointee.sa_len)!),
                                        &hostname, socklen_t(hostname.count),
                                        nil, socklen_t(0), NI_NUMERICHOST)
                            ipAddr = String(cString: hostname)
                        }
                    }
                }
                freeifaddrs(ifaddr)
            }
            
            DispatchQueue.main.async {
                self.wiFiRSSI = rssi
                self.wiFiTxRate = txRate
                self.wiFiChannel = channelStr
                self.wiFiIPAddress = ipAddr
                self.wiFiDetailsFetched = true
            }
        }
    }
    
    func fetchDynamicWiFiDetails() {
        DispatchQueue.global(qos: .userInitiated).async {
            let interface = CWWiFiClient.shared().interface()
            
            // Safety check: Do not query details if Wi-Fi is powered off.
            // Querying transmitRate or rssiValue when disconnected can cause EXC_BREAKPOINT in CoreWLAN.
            if (interface != nil && !interface!.powerOn()) || !self.wiFiIsConnected {
                LogManager.shared.log("fetchDynamicWiFiDetails: Wi-Fi is disconnected or powered off, skipping detail fetch.", level: "WARNING")
                DispatchQueue.main.async {
                    self.wiFiRSSI = nil
                    self.wiFiTxRate = nil
                    self.wiFiChannel = nil
                    self.wiFiIPAddress = nil
                }
                return
            }
            
            let rssi = interface?.rssiValue() ?? 0
            let txRate = interface?.transmitRate() ?? 0.0
            
            var channelStr: String? = nil
            if let channel = interface?.wlanChannel() {
                let band: String
                if channel.channelBand == .band5GHz {
                    band = "5 GHz"
                } else if channel.channelBand == .band6GHz {
                    band = "6 GHz"
                } else {
                    band = "2.4 GHz"
                }
                channelStr = "Ch \(channel.channelNumber) (\(band))"
            }
            
            let expectedInterfaceName = interface?.interfaceName ?? "en0"
            var ipAddr: String? = nil
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaddr) == 0 {
                var ptr = ifaddr
                while ptr != nil {
                    defer { ptr = ptr?.pointee.ifa_next }
                    if let interfaceInfo = ptr?.pointee {
                        let addrFamily = interfaceInfo.ifa_addr?.pointee.sa_family
                        if addrFamily == UInt8(AF_INET) {
                            if let namePtr = interfaceInfo.ifa_name, String(cString: namePtr) == expectedInterfaceName {
                                if let sockaddr = interfaceInfo.ifa_addr {
                                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                    let result = getnameinfo(sockaddr, socklen_t(sockaddr.pointee.sa_len),
                                                             &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                                    if result == 0 {
                                        ipAddr = String(cString: hostname)
                                    } else {
                                        LogManager.shared.log("fetchDynamicWiFiDetails: getnameinfo failed with error code \(result)", level: "ERROR")
                                    }
                                }
                            }
                        }
                    }
                }
                freeifaddrs(ifaddr)
            } else {
                LogManager.shared.log("fetchDynamicWiFiDetails: getifaddrs failed.", level: "ERROR")
            }
            
            DispatchQueue.main.async {
                self.wiFiRSSI = rssi
                self.wiFiTxRate = txRate
                if let newChannel = channelStr {
                    self.wiFiChannel = newChannel
                }
                if let newIp = ipAddr {
                    self.wiFiIPAddress = newIp
                }
            }
        }
    }
}
