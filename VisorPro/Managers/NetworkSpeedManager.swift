import Foundation
import QuartzCore // For CACurrentMediaTime()

struct NetworkQualityResult: Codable, Equatable {
    var dl_throughput: Double? // In bits per second
    var ul_throughput: Double? // In bits per second
    var base_rtt: Double?      // Ping in milliseconds
    var dl_responsiveness: Double?
    var ul_responsiveness: Double?
    var error_code: Int?
}

enum SpeedTestError: Error {
    case testFailed(code: Int)
    case processError
    case invalidURL
    case timeout
}

final class NetworkSpeedManager: NSObject, URLSessionDataDelegate {
    static let shared = NetworkSpeedManager()
    
    private var downloadTask: URLSessionDataTask?
    private var uploadTask: URLSessionDataTask?
    private var pingTask: URLSessionDataTask?
    
    private var bytesTransferred: Int = 0
    private var startTime: TimeInterval = 0
    private var lastReportTime: TimeInterval = 0
    
    private var currentResult = NetworkQualityResult()
    private var progressCallback: ((NetworkQualityResult) -> Void)?
    
    // Limits
    private let downloadSize = 25_000_000 // 25 MB payload for download
    private let uploadSize = 10_000_000 // 10 MB payload for upload
    private let throttleInterval: TimeInterval = 0.25 // 250ms update throttle
    
    private var activeContinuation: CheckedContinuation<Void, Error>?
    private var isTestingDownload = false
    
    func cancelCurrentTest() {
        downloadTask?.cancel()
        uploadTask?.cancel()
        pingTask?.cancel()
        activeContinuation?.resume(throwing: URLError(.cancelled))
        activeContinuation = nil
        progressCallback = nil
    }
    
    // Standard NetworkQuality - maintained for compatibility if needed, but not used by live view.
    func runSpeedTest(retries: Int = 1) async throws -> NetworkQualityResult {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try await runSpeedTestLive(progress: { _ in })
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    @MainActor
    func runSpeedTestLive(progress: @escaping (NetworkQualityResult) -> Void, retryCount: Int = 3) async throws -> NetworkQualityResult {
        if retryCount == 3 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        self.progressCallback = progress
        currentResult = NetworkQualityResult(dl_throughput: nil, ul_throughput: nil, base_rtt: nil, dl_responsiveness: nil, ul_responsiveness: nil, error_code: nil)
        progress(currentResult)
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ]
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        defer {
            session.invalidateAndCancel()
            self.progressCallback = nil
        }
        
        // 1. Measure Ping
        do {
            try await measurePing(session: session)
            progress(currentResult)
        } catch {
            print("SpeedTest: Ping failed. \(error)")
            if retryCount > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return try await runSpeedTestLive(progress: progress, retryCount: retryCount - 1)
            }
            throw error
        }
        
        // 2. Measure Download
        do {
            try await measureDownload(session: session)
            progress(currentResult)
        } catch {
            print("SpeedTest: Download failed. \(error)")
            if retryCount > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return try await runSpeedTestLive(progress: progress, retryCount: retryCount - 1)
            }
            throw error
        }
        
        // 3. Measure Upload
        do {
            try await measureUpload(session: session)
            progress(currentResult)
        } catch {
            print("SpeedTest: Upload failed. \(error)")
            // Upload failure might be ignored since DL succeeded, but if you want to retry:
        }
        
        return currentResult
    }
    
    private func measurePing(session: URLSession) async throws {
        // Zawsze próbujemy natywnego pinga ICMP by pominąć narzuty na zestawienie połączeń HTTPS (np TLS handshake), 
        // które w URLSession wypaczają pomiar pingu do wielkości >100ms.
        let baseRtt: Double? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                process.arguments = ["-c", "3", "-t", "1", "1.1.1.1"]
                let pipe = Pipe()
                process.standardOutput = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        if let range = output.range(of: "round-trip min/avg/max/stddev = ") {
                            let numbersStr = output[range.upperBound...].prefix(while: { $0 != " " })
                            let components = numbersStr.split(separator: "/")
                            if components.count >= 2, let avgPing = Double(components[1]) {
                                continuation.resume(returning: max(1.0, min(avgPing, 999.0)))
                                return
                            }
                        }
                    }
                } catch {
                    // Ignorujemy błędy i przechodzimy do fallbacku.
                }
                continuation.resume(returning: nil)
            }
        }
        
        if let rtt = baseRtt {
            currentResult.base_rtt = rtt
            return
        }
        
        // Fallback HTTP gdy ICMP jest zablokowane na sieci (częste w korporacjach / macOS app sandbox)
        _ = try? await session.data(from: URL(string: "https://speed.cloudflare.com/__down?bytes=0")!)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let fallbackStart = CACurrentMediaTime()
        _ = try? await session.data(from: URL(string: "https://speed.cloudflare.com/__down?bytes=0")!)
        let fallbackPing = (CACurrentMediaTime() - fallbackStart) * 1000.0
        currentResult.base_rtt = max(1.0, min(fallbackPing, 999.0))
    }
    
    private func measureDownload(session: URLSession) async throws {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(downloadSize)") else { throw SpeedTestError.invalidURL }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        isTestingDownload = true
        bytesTransferred = 0
        startTime = CACurrentMediaTime()
        lastReportTime = startTime
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.activeContinuation = continuation
            self.downloadTask = session.dataTask(with: request)
            self.downloadTask?.resume()
        }
    }
    
    private func measureUpload(session: URLSession) async throws {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { throw SpeedTestError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        // Generate random data for upload
        let uploadData = Data(count: uploadSize) // 10MB of empty (zero) bytes is fine for Cloudflare
        
        isTestingDownload = false
        bytesTransferred = 0
        startTime = CACurrentMediaTime()
        lastReportTime = startTime
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.activeContinuation = continuation
            self.uploadTask = session.uploadTask(with: request, from: uploadData)
            self.uploadTask?.resume()
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if isTestingDownload {
            handleProgress(bytes: data.count)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if !isTestingDownload {
            handleProgress(bytes: Int(bytesSent))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            activeContinuation?.resume(throwing: error)
        } else {
            activeContinuation?.resume(returning: ())
        }
        activeContinuation = nil
    }
    
    private func handleProgress(bytes: Int) {
        bytesTransferred += bytes
        let currentTime = CACurrentMediaTime()
        let elapsedTotal = currentTime - startTime
        
        // Throttle updates to UI (e.g. max every 250ms) to follow global performance rules
        if (currentTime - lastReportTime) >= throttleInterval && elapsedTotal > 0 {
            lastReportTime = currentTime
            
            // Calculate bits per second
            let bps = (Double(bytesTransferred) * 8.0) / elapsedTotal
            
            if isTestingDownload {
                currentResult.dl_throughput = bps
            } else {
                currentResult.ul_throughput = bps
            }
            
            if let callback = progressCallback {
                let resultSnapshot = currentResult
                DispatchQueue.main.async {
                    callback(resultSnapshot)
                }
            }
        }
    }
}