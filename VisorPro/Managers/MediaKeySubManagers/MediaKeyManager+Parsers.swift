import Foundation
import AppKit

extension MediaKeyManager {
    func parseTopOutput(_ output: String) {
        DispatchQueue.main.async {
            let blocks = output.components(separatedBy: "COMMAND")
            guard let lastBlock = blocks.last else { return }
            
            let lines = lastBlock.components(separatedBy: .newlines)
            var results: [(name: String, power: String, icon: NSImage?)] = []
            
            for line in lines.dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                
                let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if words.count >= 2 {
                    if let power = words.last, let doublePower = Double(power), doublePower > 0.0 {
                        let name = words.dropLast().joined(separator: " ")
                        if name != "top" && name != "kernel_task" && name != "WindowServer" && name != "coreaudiod" && name != "VisorPro" {
                            let icon = self.getIconForProcess(name: name)
                            results.append((name: name, power: power, icon: icon))
                            if results.count == 4 { break }
                        }
                    }
                }
            }
            
            self.topBatteryConsumers = results
        }
    }

}
