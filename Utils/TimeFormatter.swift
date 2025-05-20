import Foundation

struct TimeFormatter {
    private static let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.zeroFormattingBehavior = .pad
        f.unitsStyle = .positional
        return f
    }()

    /// Formate un TimeInterval en "m:ss"
    static func formatTime(_ seconds: TimeInterval) -> String {
        return formatter.string(from: seconds) ?? "0:00"
    }
}
