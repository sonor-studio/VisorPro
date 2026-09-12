import Foundation

public extension SMCKit {
    // Add a dummy shared instance to mimic whatever wrapper the user was using
    static let shared = SMCKitSharedWrapper()
}

public struct SMCKitSharedWrapper {
    public init() {
        do {
            try SMCKit.open()
        } catch {
            print("SMCKit.open() failed: \(error)")
        }
    }
    
    public func read(_ key: UInt32) throws -> Float {
        // Find key info first to get correct data type and size
        let keyInfo = try SMCKit.keyInformation(key)
        
        let smcKey = SMCKey(code: key, info: keyInfo)
        let data = try SMCKit.readData(smcKey)
        
        // If it's a Float (flt )
        if keyInfo.type == 0x666c7420 { // 'f' 'l' 't' ' '
            let floatBytes: [UInt8] = [data.0, data.1, data.2, data.3]
            var tempFloat: Float = 0.0
            memcpy(&tempFloat, floatBytes, 4)
            return tempFloat
        }
        
        // If it's SP78 (Intel)
        if keyInfo.type == 0x73703738 { // 's' 'p' '7' '8'
            let temperatureInCelsius = Double(data.0) + (Double(data.1) / 256.0)
            return Float(temperatureInCelsius)
        }
        
        // If it's sp96 (Intel/Apple Silicon)
        if keyInfo.type == 0x73703936 { // 's' 'p' '9' '6'
            let temp1 = Int(data.0) << 1
            let temp2 = Int(data.1) >> 7
            let temp3 = Double(data.1 & 0x7F) / 128.0
            return Float(Double(temp1 | temp2) + temp3)
        }
        
        throw SMCKit.SMCError.keyNotFound(code: "Unsupported DataType")
    }
}
