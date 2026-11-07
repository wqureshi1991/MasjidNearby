import Foundation

extension Int {
    /// The value in ASCII digits, left-padded with zeros to `width`: 5 → "05".
    /// Used for stored keys and times, which must not change with the user's locale.
    func zeroPadded(to width: Int) -> String {
        let digits = String(magnitude)
        let padding = String(repeating: "0", count: Swift.max(0, width - digits.count))
        return (self < 0 ? "-" : "") + padding + digits
    }
}
