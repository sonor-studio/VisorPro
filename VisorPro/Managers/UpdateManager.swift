import Foundation
import AppKit
import Combine

struct AppConfig: Codable {
    let latest_version: String
    let min_required_version: String
    let update_url: String
}

@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    private var supabaseUrl: String {
        return EnvReader.shared.getValue(for: "SUPABASE_URL") ?? ""
    }
    
    private var supabaseAnonKey: String {
        return EnvReader.shared.getValue(for: "SUPABASE_ANON_KEY") ?? ""
    }
    
    private init() {}
    
    func checkForUpdates() {
        Task {
            await fetchConfigAndCheck()
        }
    }
    
    private func fetchConfigAndCheck() async {
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else { return }
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/app_config?select=*&limit=1") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let configs = try decoder.decode([AppConfig].self, from: data)
                if let config = configs.first {
                    compareVersionsAndAlert(config: config)
                }
            }
        } catch {
            // Silently fail on network error so app can still start
        }
    }
    
    private func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let v1Components = v1.split(separator: ".").compactMap { Int($0) }
        let v2Components = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let p1 = i < v1Components.count ? v1Components[i] : 0
            let p2 = i < v2Components.count ? v2Components[i] : 0
            if p1 < p2 { return .orderedAscending }
            if p1 > p2 { return .orderedDescending }
        }
        return .orderedSame
    }
    
    private func compareVersionsAndAlert(config: AppConfig) {
        guard let rawCurrentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }
        
        let currentVersion = rawCurrentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let minRequired = config.min_required_version.trimmingCharacters(in: .whitespacesAndNewlines)
        let latestVersion = config.latest_version.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let comparisonToMin = compareVersions(currentVersion, minRequired)
        let comparisonToLatest = compareVersions(currentVersion, latestVersion)
        
        let isLessThanMin = (comparisonToMin == .orderedAscending)
        let isLessThanLatest = (comparisonToLatest == .orderedAscending)
        
        if isLessThanMin {
            showBlockingAlert(url: config.update_url, currentVersion: currentVersion, latestVersion: config.latest_version)
        } else if isLessThanLatest {
            showOptionalAlert(url: config.update_url, currentVersion: currentVersion, latestVersion: config.latest_version)
        }
    }
    
    private func showBlockingAlert(url: String, currentVersion: String, latestVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Update Required"
        alert.informativeText = String(format: "You are using an older version of the application that is no longer supported.\n\nCurrent version: %@\nLatest version: %@\n\nPlease update to continue using VisorPro.", currentVersion, latestVersion)
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Quit")
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let updateURL = URL(string: url) {
                NSWorkspace.shared.open(updateURL)
            }
            Darwin._exit(0)
        } else {
            Darwin._exit(0)
        }
    }
    
    private func showOptionalAlert(url: String, currentVersion: String, latestVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = String(format: "A new version of VisorPro is available.\n\nCurrent version: %@\nLatest version: %@\n\nWould you like to update now?", currentVersion, latestVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let updateURL = URL(string: url) {
                NSWorkspace.shared.open(updateURL)
            }
        } else {
            // Otwórz okno po kliknięciu "Later", żeby użytkownik widział, że aplikacja go "przepuściła"
            DispatchQueue.main.async {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.openDashboard()
                }
            }
        }
    }
}
