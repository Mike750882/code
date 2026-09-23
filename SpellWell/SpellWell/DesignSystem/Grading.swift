import SwiftUI

/// The letter-grade scale shared by the practice results screen and Home's
/// daily grade cards, so a session graded "B-" reads as the same B- in both
/// places.
enum Grading {
    static func letter(forPercent percent: Int) -> String {
        switch percent {
        case 97...: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 63..<67: return "D"
        case 60..<63: return "D-"
        default: return "F"
        }
    }

    static func caption(forPercent percent: Int) -> String {
        switch percent {
        case 90...: return "Excellent!"
        case 80..<90: return "Good Job!"
        case 70..<80: return "Getting Better"
        default: return "Need More Practice!"
        }
    }

    static func color(forPercent percent: Int) -> Color {
        percent >= 70 ? Theme.success : Theme.error
    }
}
