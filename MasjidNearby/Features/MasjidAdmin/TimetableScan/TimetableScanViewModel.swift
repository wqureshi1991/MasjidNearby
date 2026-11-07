import Foundation
import Observation

/// Reads a photo of a masjid's printed monthly timetable, lets the admin check every day,
/// then publishes the days as scanned (`.ocr`) times.
///
/// Each day starts from what's already published, or calculated times, and the scan
/// overwrites the columns it read. So an adhan-only timetable keeps published iqamah times.
@MainActor
@Observable
final class TimetableScanViewModel {
    struct ScannedDay: Identifiable, Sendable, Equatable {
        let day: CalendarDay
        var times: EditableDay
        /// Columns that were hard to read, or unreadable and filled from the starting times.
        var flagged: Set<TimetableSlot>
        var isIncluded = true

        var id: CalendarDay { day }

        var issues: [ScheduleIssue] {
            ScheduleValidator.issues(in: times.dailyTimes(on: day, source: .ocr))
        }

        var needsReview: Bool { !flagged.isEmpty || !issues.isEmpty }
    }

    static let monthCount = 3

    let masjid: Masjid
    let timeZone: TimeZone
    /// The first day of this month and the next two.
    let months: [CalendarDay]

    private(set) var scanState: LoadState<Void> = .idle
    /// Loaded value is the number of days published.
    private(set) var publishState: LoadState<Int> = .idle
    /// Changing the month or layout rebuilds this list from the photo, discarding edits.
    var days: [ScannedDay] = [] {
        didSet { resetPublishResult() }
    }
    private(set) var detectedLayout: TimetableLayout?

    @ObservationIgnored var onFinished: (@MainActor () -> Void)?

    private var storedMonth: CalendarDay
    private var layoutOverride: TimetableLayout?
    private var lines: [String] = []
    private var published: [CalendarDay: DailyPrayerTimes] = [:]

    private let repository: any MasjidRepository
    private let calculator: any PrayerTimeCalculator
    private let recognizer: any TextRecognizer

    init(masjid: Masjid,
         repository: any MasjidRepository,
         calculator: any PrayerTimeCalculator,
         recognizer: any TextRecognizer,
         now: Date = Date()) {
        let timeZone = masjid.timeZone ?? .current
        var months: [CalendarDay] = []
        var start = Self.monthStart(CalendarDay(date: now, in: timeZone))
        for _ in 0..<Self.monthCount {
            months.append(start)
            start = Self.monthStart(start.adding(days: 31))
        }
        self.masjid = masjid
        self.timeZone = timeZone
        self.months = months
        self.repository = repository
        self.calculator = calculator
        self.recognizer = recognizer
        storedMonth = months[0]
    }

    // MARK: - Settings

    /// The first day of the month the timetable is for.
    var month: CalendarDay {
        get { storedMonth }
        set {
            guard newValue != storedMonth, months.contains(newValue) else { return }
            storedMonth = newValue
            rebuild()
        }
    }

    /// The column layout: detected from the photo unless the admin picks one.
    var layout: TimetableLayout {
        get { layoutOverride ?? detectedLayout ?? .adhanWithSunrise }
        set {
            guard newValue != layout else { return }
            layoutOverride = newValue
            rebuild()
        }
    }

    var dayCountInMonth: Int {
        Self.monthStart(month.adding(days: 31)).julianDayNumber - month.julianDayNumber
    }

    var hasResults: Bool { !days.isEmpty }
    var includedCount: Int { days.filter { $0.isIncluded }.count }
    var reviewCount: Int { days.filter { $0.isIncluded && $0.needsReview }.count }
    var daysWithIssues: Int { days.filter { $0.isIncluded && !$0.issues.isEmpty }.count }

    var canPublish: Bool {
        includedCount > 0 && daysWithIssues == 0 && !publishState.isLoading && !scanState.isLoading
    }

    var photoPickerTitle: String {
        hasResults ? "Choose a Different Photo" : "Choose Timetable Photo"
    }

    var settingsFooter: String {
        "Found \(days.count) of \(dayCountInMonth) days. Changing the month or columns reads the photo again and discards your edits."
    }

    var daysFooter: String {
        guard reviewCount > 0 else { return "Tap any day to correct it." }
        return "Tap the \(reviewCount) marked \(reviewCount == 1 ? "day" : "days") to check them against the timetable."
    }

    var publishTitle: String {
        switch includedCount {
        case 0: "Nothing to Publish"
        case 1: "Publish 1 Day"
        default: "Publish \(includedCount) Days"
        }
    }

    var publishFooter: String? {
        guard daysWithIssues > 0 else { return nil }
        return "Fix the problems on \(daysWithIssues) \(daysWithIssues == 1 ? "day" : "days"), or switch them off, before publishing."
    }

    // MARK: - Actions

    /// Loads what's already published for these months, the starting point for scanned days.
    func load() async {
        guard let first = months.first, let last = months.last else { return }
        let end = Self.monthStart(last.adding(days: 31)).adding(days: -1)
        do {
            let days = try await repository.schedule(masjidID: masjid.id, from: first, through: end)
            published = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
            if !lines.isEmpty && self.days.isEmpty {
                rebuild()
            }
        } catch {
            // Not fatal: scanned days start from calculated times instead.
        }
    }

    func scan(imageData: Data) async {
        guard !scanState.isLoading else { return }
        scanState = .loading
        do {
            let fragments = try await recognizer.recognizeText(in: imageData)
            lines = TimetableParser.lines(from: fragments)
            detectedLayout = TimetableParser.detectLayout(in: lines)
            layoutOverride = nil
            detectMonth()
            rebuild()
            scanState = days.isEmpty ? .failed(TimetableScanError.noRowsFound) : .loaded(())
        } catch {
            scanState = .failed(error)
        }
    }

    /// The view couldn't get image data out of the chosen photo.
    func photoUnavailable() {
        scanState = .failed(TimetableScanError.imageUnavailable)
    }

    /// The admin has checked this day; stop flagging it.
    func markReviewed(_ id: CalendarDay) {
        guard let index = days.firstIndex(where: { $0.id == id }) else { return }
        days[index].flagged = []
    }

    func publish() async {
        guard canPublish else { return }
        let times = days.filter { $0.isIncluded }.map { $0.times.dailyTimes(on: $0.day, source: .ocr) }
        publishState = .loading
        do {
            try await repository.publish(times, masjidID: masjid.id)
            for day in times {
                published[day.day] = day
            }
            publishState = .loaded(times.count)
        } catch {
            publishState = .failed(error)
        }
    }

    func finish() {
        onFinished?()
    }

    // MARK: - Formatting

    func monthTitle(_ month: CalendarDay) -> String {
        var style = Date.FormatStyle().month(.wide).year()
        style.timeZone = .gmt
        return month.startOfDayUTC.addingTimeInterval(12 * 3_600).formatted(style)
    }

    func dayTitle(_ day: CalendarDay) -> String {
        var style = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        style.timeZone = .gmt
        return day.startOfDayUTC.addingTimeInterval(12 * 3_600).formatted(style)
    }

    // MARK: - Private

    private func rebuild() {
        guard !lines.isEmpty else {
            days = []
            return
        }
        let parsed = TimetableParser.parse(lines: lines, layout: layout)
        let month = storedMonth
        days = parsed.days.compactMap { row in
            guard let day = CalendarDay(year: month.year, month: month.month, day: row.dayOfMonth) else { return nil }
            var times = EditableDay(baseline(for: day))
            for (slot, value) in row.values {
                switch slot {
                case .sunrise:
                    times.sunrise = value
                case .adhan(let prayer):
                    times[prayer].adhan = value
                case .iqamah(let prayer):
                    times[prayer].hasIqamah = true
                    times[prayer].iqamah = value
                }
            }
            return ScannedDay(day: day, times: times, flagged: row.flagged)
        }
    }

    /// Picks the month printed on the timetable ("October 2026"), if it's one of the options.
    private func detectMonth() {
        let text = lines.joined(separator: " ").lowercased()
        let named = months.filter { text.contains(Self.monthNames[$0.month - 1]) }
        if let match = named.first(where: { text.contains(String($0.year)) }) ?? named.first {
            storedMonth = match
        }
    }

    private func baseline(for day: CalendarDay) -> DailyPrayerTimes {
        published[day] ?? ScheduleEditorViewModel.calculatedTimes(
            on: day, masjid: masjid, timeZone: timeZone, calculator: calculator
        )
    }

    private func resetPublishResult() {
        if !publishState.isLoading {
            publishState = .idle
        }
    }

    private static func monthStart(_ day: CalendarDay) -> CalendarDay {
        day.adding(days: 1 - day.day)
    }

    private static let monthNames = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]
}
