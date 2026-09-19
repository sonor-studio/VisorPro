import Foundation

let width: CGFloat = 300
let dynamicOffset: CGFloat = -2
let trackPadding: CGFloat = 3
let innerPadding: CGFloat = 3
let cutoutSize: CGFloat = 12
let closeButtonOnRight = false

let buttonCenter = CGPoint(x: closeButtonOnRight ? width - (dynamicOffset + 10) : dynamicOffset + 10, y: dynamicOffset + 10)
let cutoutCenterForShape = CGPoint(x: closeButtonOnRight ? width - buttonCenter.x : buttonCenter.x, y: buttonCenter.y)

let buttonRadius: CGFloat = 10
let buttonBottom = buttonCenter.y + buttonRadius
let buttonRight = buttonCenter.x + buttonRadius

let cutoutBottom = cutoutCenterForShape.y + cutoutSize
let cutoutRight = cutoutCenterForShape.x + cutoutSize

print("Button Center: \(buttonCenter)")
print("Cutout Center: \(cutoutCenterForShape)")
print("Gap Bottom: \(cutoutBottom - buttonBottom)")
print("Gap Right: \(cutoutRight - buttonRight)")
