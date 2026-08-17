import Foundation
import Cocoa

class KeyboardBrightnessManager {
    static let shared = KeyboardBrightnessManager()
    
    private let queue = DispatchQueue(label: "com.visor.keyboardBrightnessQueue")
    
    private var bsClient: AnyObject?
    private var copyPropertySel: Selector?
    private var setPropertySel: Selector?
    
    private var copyPropertyFunc: (@convention(c) (AnyObject, Selector, AnyObject) -> Unmanaged<AnyObject>?)?
    private var setPropertyFunc: (@convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Bool)?
    
    private var maxHardwareBrightness: Float = 0.0
    
    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        if handle != nil {
            if let bsClass = NSClassFromString("BrightnessSystemClient") as? NSObject.Type {
                self.bsClient = bsClass.init()
                
                let copySel = NSSelectorFromString("copyPropertyForKey:")
                if let client = self.bsClient, client.responds(to: copySel) {
                    self.copyPropertySel = copySel
                    let methodSig = client.method(for: copySel)
                    typealias CopyFunc = @convention(c) (AnyObject, Selector, AnyObject) -> Unmanaged<AnyObject>?
                    self.copyPropertyFunc = unsafeBitCast(methodSig, to: CopyFunc.self)
                }
                
                let setSel = NSSelectorFromString("setProperty:forKey:")
                if let client = self.bsClient, client.responds(to: setSel) {
                    self.setPropertySel = setSel
                    let methodSig = client.method(for: setSel)
                    typealias SetFunc = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Bool
                    self.setPropertyFunc = unsafeBitCast(methodSig, to: SetFunc.self)
                }
            }
        }
    }
    
    private func discoverMaxIfNeeded() {
        guard maxHardwareBrightness <= 0.0 else { return }
        
        if let client = self.bsClient, let copySel = self.copyPropertySel, let copyFunc = self.copyPropertyFunc,
           let setSel = self.setPropertySel, let setFunc = self.setPropertyFunc {
            
            var initial: Float = 0.0
            if let unmanaged = copyFunc(client, copySel, "KeyboardBacklightLevel" as NSString),
               let num = unmanaged.takeUnretainedValue() as? NSNumber {
                initial = num.floatValue
            }
            
            _ = setFunc(client, setSel, NSNumber(value: 1000.0), "KeyboardBacklightLevel" as NSString)
            
            if let unmanaged = copyFunc(client, copySel, "KeyboardBacklightLevel" as NSString),
               let num = unmanaged.takeUnretainedValue() as? NSNumber {
                self.maxHardwareBrightness = num.floatValue
            }
            
            _ = setFunc(client, setSel, NSNumber(value: initial), "KeyboardBacklightLevel" as NSString)
        }
        
        if maxHardwareBrightness <= 0.0 {
            maxHardwareBrightness = 14.66 // Fallback value
        }
    }
    
    private var currentBrightness: Float {
        discoverMaxIfNeeded()
        
        if let client = self.bsClient, let copySel = self.copyPropertySel, let copyFunc = self.copyPropertyFunc {
            if let unmanaged = copyFunc(client, copySel, "KeyboardBacklightLevel" as NSString) {
                if let num = unmanaged.takeUnretainedValue() as? NSNumber {
                    return num.floatValue / self.maxHardwareBrightness
                }
            }
        }
        if UserDefaults.standard.object(forKey: "VisorPro_KeyboardBrightness") != nil {
            return UserDefaults.standard.float(forKey: "VisorPro_KeyboardBrightness")
        }
        return 0.5
    }
    
    private func saveBrightness(_ val: Float) {
        discoverMaxIfNeeded()
        UserDefaults.standard.set(val, forKey: "VisorPro_KeyboardBrightness")
        
        let hardwareVal = val * self.maxHardwareBrightness
        if let client = self.bsClient, let setSel = self.setPropertySel, let setFunc = self.setPropertyFunc {
            _ = setFunc(client, setSel, NSNumber(value: hardwareVal), "KeyboardBacklightLevel" as NSString)
        }
    }
    
    func fetchCurrentBrightness(completion: @escaping (Int) -> Void) {
        queue.async {
            let intBrightness = Int(self.currentBrightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
    
    func changeBrightness(increase: Bool, completion: @escaping (Int) -> Void) {
        queue.async {
            let step: Float = 1.0 / 16.0
            var newBrightness = increase ? self.currentBrightness + step : self.currentBrightness - step
            newBrightness = max(0.0, min(1.0, newBrightness))
            
            self.saveBrightness(newBrightness)
            
            let intBrightness = Int(newBrightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
    
    func increaseBrightness(completion: @escaping (Int) -> Void) {
        changeBrightness(increase: true, completion: completion)
    }
    
    func decreaseBrightness(completion: @escaping (Int) -> Void) {
        changeBrightness(increase: false, completion: completion)
    }
    
    func setBrightness(to level: Int, completion: @escaping (Int) -> Void) {
        queue.async {
            var newBrightness = Float(level) / 100.0
            newBrightness = max(0.0, min(1.0, newBrightness))
            
            self.saveBrightness(newBrightness)
            
            let intBrightness = Int(newBrightness * 100)
            DispatchQueue.main.async {
                completion(intBrightness)
            }
        }
    }
}






