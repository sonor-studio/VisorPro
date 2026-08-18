import Foundation

let task = Process()
task.launchPath = "/usr/bin/log"
task.arguments = ["stream", "--predicate", "subsystem == 'com.apple.locationd'"]

let pipe = Pipe()
task.standardOutput = pipe

let fileURL = URL(fileURLWithPath: "/Users/macbook/Desktop/Dev/VisorPro/location_logs.txt")
try? "".write(to: fileURL, atomically: true, encoding: .utf8)

let fileHandle = try? FileHandle(forWritingTo: fileURL)

pipe.fileHandleForReading.readabilityHandler = { pipe in
    let data = pipe.availableData
    if data.count > 0 {
        fileHandle?.seekToEndOfFile()
        fileHandle?.write(data)
    }
}

task.launch()

DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
    task.terminate()
    fileHandle?.closeFile()
    exit(0)
}

RunLoop.main.run()
