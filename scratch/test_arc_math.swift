import Foundation

let cx: Double = 8
let cy: Double = 8
let cr: Double = 12

// We want to intersect the top and left edges of the button.
// But the button is in the top-left corner!
// Wait! The top-left corner is a ROUNDED corner with radius 28.
// The left straight edge is x=0, y >= 28.
// The top straight edge is y=0, x >= 28.
// The button is at (8,8) with radius 12.
// The cutout circle NEVER touches the straight edges! It only touches the ROUNDED corner!
print("Circle bounds: x in \((cx - cr)) to \((cx + cr)), y in \((cy - cr)) to \((cy + cr))")
