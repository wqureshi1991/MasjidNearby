import Foundation

/// Turns recognised text from a photo of a monthly timetable into times per day.
///
/// A row is any line that starts with a day of the month (1–31) and has exactly as many
/// times as the layout has columns. Headers, footers, Hijri dates and Jumuah notes don't
/// match, so they're ignored.
enum TimetableParser {
    // MARK: - Lines

    /// Groups text fragments into lines, top to bottom, each read left to right.
    static func lines(from fragments: [RecognizedText]) -> [String] {
        let sorted = fragments.sorted { $0.midY > $1.midY }
        var groups: [[RecognizedText]] = []
        for fragment in sorted {
            if let last = groups.last {
                let averageY = last.reduce(0) { $0 + $1.midY } / Double(last.count)
                let tallest = max(last.reduce(0) { max($0, $1.height) }, fragment.height)
                if abs(fragment.midY - averageY) <= tallest * 0.5 {
                    groups[groups.count - 1].append(fragment)
                    continue
                }
            }
            groups.append([fragment])
        }
        return groups.map { group in
            group.sorted { $0.minX < $1.minX }.map { $0.text }.joined(separator: " ")
        }
    }

    // MARK: - Parsing

    /// The layout most rows fit, or nil if no row looks like a timetable row.
    static func detectLayout(in lines: [String]) -> TimetableLayout? {
        let rows = lines.map { row(from: $0) }
        var best: (layout: TimetableLayout, count: Int)?
        for layout in TimetableLayout.allCases {
            let count = rows.filter { $0.day != nil && $0.times.count == layout.slots.count }.count
            if count > 0, count > (best?.count ?? 0) {
                best = (layout, count)
            }
        }
        return best?.layout
    }

    static func parse(lines: [String], layout: TimetableLayout) -> ParsedTimetable {
        let slots = layout.slots
        var seen = Set<Int>()
        var days: [ParsedTimetableDay] = []
        let rows = lines.map { row(from: $0) }
        for entry in rows {
            guard let day = entry.day, entry.times.count == slots.count, !seen.contains(day) else { continue }
            seen.insert(day)
            var values: [TimetableSlot: WallClockTime] = [:]
            var flagged = Set<TimetableSlot>()
            for (raw, slot) in zip(entry.times, slots) {
                if let time = wallClockTime(raw, for: slot) {
                    values[slot] = time
                    if raw.corrected {
                        flagged.insert(slot)
                    }
                } else {
                    flagged.insert(slot)
                }
            }
            days.append(ParsedTimetableDay(dayOfMonth: day, values: values, flagged: flagged))
        }
        return ParsedTimetable(layout: layout, days: days.sorted { $0.dayOfMonth < $1.dayOfMonth })
    }

    // MARK: - Tokens

    enum Meridiem: Sendable {
        case am
        case pm
    }

    struct RawTime: Sendable, Equatable {
        let hour: Int
        let minute: Int
        var meridiem: Meridiem?
        /// A letter OCR commonly confuses with a digit was replaced ("O" → "0").
        let corrected: Bool
    }

    private struct Row {
        let day: Int?
        let times: [RawTime]
    }

    private static let meridiemSuffixes: [(String, Meridiem)] = [("a.m.", .am), ("p.m.", .pm), ("am", .am), ("pm", .pm)]
    private static let characterFixes: [Character: Int] = ["o": 0, "d": 0, "l": 1, "i": 1, "|": 1, "s": 5, "b": 8]
    private static let punctuation = CharacterSet(charactersIn: ",;()[]*")

    private static func row(from line: String) -> Row {
        let tokens = line.split(whereSeparator: { $0.isWhitespace })
        var day: Int?
        var times: [RawTime] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if var time = rawTime(token) {
                if time.meridiem == nil, index + 1 < tokens.count, let meridiem = standaloneMeridiem(tokens[index + 1]) {
                    time.meridiem = meridiem
                    index += 1
                }
                times.append(time)
            } else if day == nil, times.isEmpty, let value = dayOfMonth(token) {
                day = value
            }
            index += 1
        }
        return Row(day: day, times: times)
    }

    /// Reads "5:42", "05.42", "5:42pm" or "5:4O" (fixed up and marked corrected).
    static func rawTime(_ token: Substring) -> RawTime? {
        var text = token.lowercased().trimmingCharacters(in: punctuation)
        var meridiem: Meridiem?
        for (suffix, value) in meridiemSuffixes where text.hasSuffix(suffix) {
            meridiem = value
            text.removeLast(suffix.count)
            break
        }
        let separator: Character = text.contains(":") ? ":" : "."
        let parts = text.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 2, (1...2).contains(parts[0].count), parts[1].count == 2 else { return nil }

        var corrected = false
        var realDigits = 0
        func number(_ part: Substring) -> Int? {
            var value = 0
            for character in part {
                let digit: Int
                if character.isASCII, let parsed = character.wholeNumberValue {
                    digit = parsed
                    realDigits += 1
                } else if let fixed = characterFixes[character] {
                    digit = fixed
                    corrected = true
                } else {
                    return nil
                }
                value = value * 10 + digit
            }
            return value
        }
        guard let hour = number(parts[0]), let minute = number(parts[1]), realDigits > 0 else { return nil }
        return RawTime(hour: hour, minute: minute, meridiem: meridiem, corrected: corrected)
    }

    private static func standaloneMeridiem(_ token: Substring) -> Meridiem? {
        switch token.lowercased().trimmingCharacters(in: punctuation) {
        case "am", "a.m.": .am
        case "pm", "p.m.": .pm
        default: nil
        }
    }

    /// "1" to "31", allowing "1st", "22nd" and so on.
    private static func dayOfMonth(_ token: Substring) -> Int? {
        var text = token.lowercased().trimmingCharacters(in: punctuation)
        for suffix in ["st", "nd", "rd", "th"] where text.hasSuffix(suffix) {
            text.removeLast(suffix.count)
            break
        }
        guard (1...2).contains(text.count),
              text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(text), (1...31).contains(value)
        else { return nil }
        return value
    }

    /// Converts to 24-hour time. Without am/pm, Dhuhr before 6 and Asr, Maghrib and Isha
    /// before 12 are afternoon times printed on a 12-hour clock.
    static func wallClockTime(_ raw: RawTime, for slot: TimetableSlot) -> WallClockTime? {
        guard (0...23).contains(raw.hour), (0...59).contains(raw.minute) else { return nil }
        var hour = raw.hour
        switch raw.meridiem {
        case .pm?:
            if hour < 12 { hour += 12 }
        case .am?:
            if hour == 12 { hour = 0 }
        case nil:
            switch slot.prayer {
            case .dhuhr?:
                if hour < 6 { hour += 12 }
            case .asr?, .maghrib?, .isha?:
                if hour < 12 { hour += 12 }
            case .fajr?, nil:
                break
            }
        }
        return WallClockTime(hour: hour, minute: raw.minute)
    }
}
