import Foundation
import AppKit
import Combine

struct AppConfig: Codable {
    let latest_version: String
    let min_required_version: String
    let update_url: String
    let release_notes: String?
}

class UpdateProgressWindowController: NSWindowController {
    let progressIndicator = NSProgressIndicator()
    let statusLabel = NSTextField(labelWithString: "Downloading update...")
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Updating VisorPro"
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        
        statusLabel.frame = NSRect(x: 20, y: 70, width: 260, height: 20)
        statusLabel.alignment = .center
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.drawsBackground = false
        container.addSubview(statusLabel)
        
        progressIndicator.frame = NSRect(x: 20, y: 40, width: 260, height: 20)
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        container.addSubview(progressIndicator)
        
        window.contentView = container
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
}

class AutoUpdater: NSObject, URLSessionDownloadDelegate {
    static let shared = AutoUpdater()
    private var progressWindow: UpdateProgressWindowController?
    private var downloadTask: URLSessionDownloadTask?
    
    func performUpdate(from url: URL) {
        DispatchQueue.main.async {
            self.progressWindow = UpdateProgressWindowController()
            self.progressWindow?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressWindow?.progressIndicator.doubleValue = progress
            let percentage = Int(progress * 100)
            self.progressWindow?.statusLabel.stringValue = "Downloading update... \(percentage)%"
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let httpResponse = downloadTask.response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            DispatchQueue.main.async {
                self.showError("Download error: Server returned HTTP \(httpResponse.statusCode). Make sure the file is exactly named VisorPro.dmg on the server.")
            }
            return
        }
        
        DispatchQueue.main.async {
            self.progressWindow?.progressIndicator.isIndeterminate = true
            self.progressWindow?.progressIndicator.startAnimation(nil)
            self.progressWindow?.statusLabel.stringValue = "Installing update..."
        }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dmgURL = tempDir.appendingPathComponent("update.dmg")
        let mountPoint = tempDir.appendingPathComponent("MountPoint")
        let updateAppDir = tempDir.appendingPathComponent("NewApp")
        
        do {
            try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: updateAppDir, withIntermediateDirectories: true, attributes: nil)
            try fileManager.moveItem(at: location, to: dmgURL)
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Mount the DMG silently
                    let attachProcess = Process()
                    attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    attachProcess.arguments = [
                        "attach", dmgURL.path,
                        "-mountpoint", mountPoint.path,
                        "-nobrowse",
                        "-quiet",
                        "-noverify"
                    ]
                    try attachProcess.run()
                    attachProcess.waitUntilExit()
                    
                    if attachProcess.terminationStatus != 0 {
                        self.showError("Failed to mount the downloaded disk image.")
                        return
                    }
                    
                    // Find the application inside the DMG
                    let mountedContents = try fileManager.contentsOfDirectory(atPath: mountPoint.path)
                    guard let appFolderName = mountedContents.first(where: { $0.hasSuffix(".app") }) else {
                        self.detach(mountPoint: mountPoint)
                        self.showError("Could not find the application inside the disk image.")
                        return
                    }
                    
                    let mountedAppPath = mountPoint.appendingPathComponent(appFolderName).path
                    let copiedAppPath = updateAppDir.appendingPathComponent(appFolderName).path
                    
                    // Copy app to the isolated folder
                    let copyProcess = Process()
                    copyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    copyProcess.arguments = [mountedAppPath, copiedAppPath]
                    try copyProcess.run()
                    copyProcess.waitUntilExit()
                    
                    // Unmount the DMG
                    self.detach(mountPoint: mountPoint)
                    
                    if copyProcess.terminationStatus == 0 {
                        self.installAndRestart(tempDir: tempDir, newAppPath: copiedAppPath)
                    } else {
                        self.showError("Failed to copy the application from the disk image.")
                    }
                } catch {
                    self.showError("Update preparation failed: \(error.localizedDescription)")
                }
            }
        } catch {
            self.showError("Update directory setup failed: \(error.localizedDescription)")
        }
    }
    
    private func detach(mountPoint: URL) {
        let detachProcess = Process()
        detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        detachProcess.arguments = ["detach", mountPoint.path, "-force", "-quiet"]
        try? detachProcess.run()
        detachProcess.waitUntilExit()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.showError("Download failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func installAndRestart(tempDir: URL, newAppPath: String) {
        let fileManager = FileManager.default
        let currentAppPath = Bundle.main.bundlePath
        
        let script = #"""
        #!/bin/bash
        # Wait a moment to ensure the app has quit
        sleep 1
        
        NEW_APP="$1"
        CUR_APP="$2"
        TMP_DIR="$3"
        
        NEEDS_ADMIN=0
        if [ ! -w "$(dirname "$CUR_APP")" ]; then
            NEEDS_ADMIN=1
        elif [ -e "$CUR_APP" ] && [ ! -w "$CUR_APP" ]; then
            NEEDS_ADMIN=1
        fi
        
        if [ $NEEDS_ADMIN -eq 1 ]; then
            ADMIN_SCRIPT="$TMP_DIR/admin_update.sh"
            echo '#!/bin/bash' > "$ADMIN_SCRIPT"
            echo 'rm -rf "$2"' >> "$ADMIN_SCRIPT"
            echo 'ditto "$1" "$2"' >> "$ADMIN_SCRIPT"
            echo 'xattr -rc "$2"' >> "$ADMIN_SCRIPT"
            chmod +x "$ADMIN_SCRIPT"
            osascript -e "do shell script \"'$ADMIN_SCRIPT' '$NEW_APP' '$CUR_APP'\" with administrator privileges"
        else
            rm -rf "$CUR_APP"
            ditto "$NEW_APP" "$CUR_APP"
            xattr -rc "$CUR_APP"
        fi
        
        open "$CUR_APP"
        rm -rf "$TMP_DIR"
        rm "$0"
        """#
        
        let scriptURL = tempDir.appendingPathComponent("update_script.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path, newAppPath, currentAppPath, tempDir.path]
            
            // Detach standard I/O so the parent app termination doesn't kill the child process
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            try process.run()
            
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            showError("Failed to prepare installation script: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        DispatchQueue.main.async {
            self.progressWindow?.close()
            let alert = NSAlert()
            alert.messageText = "Update Error"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
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
    
    private var activePromptWindowController: NSWindowController?
    
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
                do {
                    let configs = try decoder.decode([AppConfig].self, from: data)
                    if let config = configs.first {
                        compareVersionsAndAlert(config: config)
                    }
                } catch {
                    // Silently fail on JSON parsing error
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
            showCustomPrompt(config: config, currentVersion: currentVersion, isBlocking: true)
        } else if isLessThanLatest {
            showCustomPrompt(config: config, currentVersion: currentVersion, isBlocking: false)
        }
    }
    
    private func showCustomPrompt(config: AppConfig, currentVersion: String, isBlocking: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        
        var githubAction: (() -> Void)? = nil
        let urlString = config.update_url
        if let downloadRange = urlString.range(of: "/releases/download/") {
            let prefix = urlString[..<downloadRange.lowerBound]
            let afterDownload = urlString[downloadRange.upperBound...]
            
            if let slashIndex = afterDownload.firstIndex(of: "/") {
                let tag = String(afterDownload[..<slashIndex])
                let finalURLString = prefix + "/releases/tag/" + tag
                
                if let githubURL = URL(string: finalURLString) {
                    githubAction = {
                        NSWorkspace.shared.open(githubURL)
                    }
                }
            }
        }
        
        let promptVC = UpdatePromptWindowController(
            currentVersion: currentVersion,
            latestVersion: config.latest_version,
            releaseNotes: config.release_notes ?? "Bug fixes and performance improvements.",
            isBlocking: isBlocking,
            onUpdate: {
                if isBlocking { NSApp.stopModal() }
                if let updateURL = URL(string: config.update_url) {
                    AutoUpdater.shared.performUpdate(from: updateURL)
                }
                self.activePromptWindowController?.close()
                self.activePromptWindowController = nil
            },
            onLater: {
                if isBlocking {
                    NSApp.stopModal()
                    Darwin._exit(0)
                } else {
                    self.activePromptWindowController?.close()
                    self.activePromptWindowController = nil
                    
                    DispatchQueue.main.async {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.openDashboard()
                        }
                    }
                }
            },
            onGitHub: githubAction
        )
        
        activePromptWindowController = promptVC
        promptVC.window?.makeKeyAndOrderFront(nil)
        
        if isBlocking {
            // Disconnect event taps (disable key / overlay listening)
            MediaKeyManager.shared.stopEventTaps()
            
            // Close all other windows, e.g. Dashboard
            for window in NSApp.windows {
                if window != promptVC.window {
                    window.orderOut(nil)
                }
            }
            
            // Run window as modal, which will block the rest of the application
            if let w = promptVC.window {
                NSApp.runModal(for: w)
            }
        }
    }
}
import SwiftUI
import AppKit

struct UpdatePromptView: View {
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String
    let isBlocking: Bool
    let onUpdate: () -> Void
    let onLater: () -> Void
    let onGitHub: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("A new version of VisorPro is available!")
                        .font(.headline)
                    Text("VisorPro \(latestVersion) is now available—you have \(currentVersion). Would you like to download it now?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Release Notes:")
                    .font(.headline)
                
                ScrollView {
                    let fallback = "Bug fixes and performance improvements."
                    let rawText = releaseNotes.isEmpty ? fallback : releaseNotes
                    let normalizedText = rawText
                        .replacingOccurrences(of: "\\n", with: "\n")
                        .replacingOccurrences(of: "\r\n", with: "\n")
                    
                    let lines = normalizedText.components(separatedBy: "\n")
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<lines.count, id: \.self) { index in
                            let line = lines[index].trimmingCharacters(in: .whitespaces)
                            if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
                                let headerText = line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                                Text(LocalizedStringKey(headerText))
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.top, index == 0 ? 0 : 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if line.isEmpty {
                                Text("")
                                    .frame(height: 4)
                            } else {
                                Text(LocalizedStringKey(line))
                                    .font(.system(size: 12))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            
            HStack {
                if let onGitHub = onGitHub {
                    Button("Open GitHub") {
                        onGitHub()
                    }
                }
                
                Spacer()
                
                if isBlocking {
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("Later") {
                        onLater()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                Button("Install Update") {
                    onUpdate()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 450)
    }
}

class UpdatePromptWindowController: NSWindowController {
    convenience init(currentVersion: String, latestVersion: String, releaseNotes: String, isBlocking: Bool, onUpdate: @escaping () -> Void, onLater: @escaping () -> Void, onGitHub: (() -> Void)?) {
        let view = UpdatePromptView(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            isBlocking: isBlocking,
            onUpdate: onUpdate,
            onLater: onLater,
            onGitHub: onGitHub
        )
        
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Software Update"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        if isBlocking {
            window.styleMask.remove(.closable)
        }
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.animationBehavior = .alertPanel
        
        self.init(window: window)
    }
}
