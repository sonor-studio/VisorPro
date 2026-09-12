import Foundation

struct NetworkQualityResult: Codable {
    let dl_throughput: Double?
    let ul_throughput: Double?
    let base_rtt: Double?
    let dl_responsiveness: Double?  
    let ul_responsiveness: Double?
    let error_code: Int?
}

enum SpeedTestError: Error {
    case testFailed(code: Int)
    case processError
}

final class NetworkSpeedManager {
    static let shared = NetworkSpeedManager()
    
    func runSpeedTest(retries: Int = 1) async throws -> NetworkQualityResult {
        do {
            return try await executeTest()
        } catch {
            if retries > 0 {
                // Wait 1 second before retrying to let the system network stack settle
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return try await runSpeedTest(retries: retries - 1)
            } else {
                throw error
            }
        }
    }
    
    private func executeTest() async throws -> NetworkQualityResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        process.arguments = ["-c"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        
        var outputData = Data()
        for try await byte in pipe.fileHandleForReading.bytes {
            outputData.append(byte)
        }
        
        process.waitUntilExit()
        
        if outputData.isEmpty {
            throw SpeedTestError.processError
        }
        
        let result = try JSONDecoder().decode(NetworkQualityResult.self, from: outputData)
        if let code = result.error_code, code != 0 {
            throw SpeedTestError.testFailed(code: code)
        }
        
        return result
    }
}