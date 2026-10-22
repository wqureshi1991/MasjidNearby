import Foundation
import Observation

/// Edits a masjid's prayer times one day at a time over the next `windowLength` days,
/// then publishes every edited day in one batch.
///
/// Each day starts from its published times, or from calculated times when nothing is
/// published, so admins mostly just adjust iqamah.
@MainActor
@Observable
final class ScheduleEditorViewModel {
    enum DayStatus: Equatable {
        case published
        case calculated
        case edited
    }

    static let windowLength = 60
    static let maximumCopyDays = 30

    let masjid: Masjid
    let timeZone: TimeZone
    let firstDay: CalendarDay
    let lastDay: CalendarDay
    var copyDayCount = 6

    private(set) var loadState: LoadState<Void> = .idle
    /// Loaded value is the number of days published.
    private(set) var publishState: LoadState<Int> = .idle

    private var storedSelectedDay: CalendarDay
    private var storedEditingDay: EditableDay
    private var published: [CalendarDay: DailyPrayerTimes] = [:]
    /// Days whose times differ from their baseline, keyed by day.
    private var drafts: [CalendarDay: DailyPrayerTimes] = [:]

    private let repository: any MasjidRepository
    private let calculator: any PrayerTimeCalculator

    init(masjid: Masjid,
         repository: any MasjidRepository,
         calculator: any PrayerTimeCalculator,
         now: Date = Date()) {
        let timeZone = masjid.timeZone ?? .current
        let today = CalendarDay(date: now, in: timeZone)
        self.masjid = masjid
        self.timeZone = timeZone
        self.repository = repository
        self.calculator = calculator
        firstDay = today
        lastDay = today.adding(days: Self.windowLength - 1)
        storedSelectedDay = today
        storedEditingDay = EditableDay(
            Self.calculatedTimes(on: today, masjid: masjid, timeZone: timeZone, calculator: calculator)
        )
    }

    // MARK: - Selected day

    var selectedDay: CalendarDay {
        get { storedSelectedDay }
        set {
            let clamped = min(max(newValue, firstDay), lastDay)
            guard clamped != storedSelectedDay else { return }
            storedSelectedDay = clamped
            editingDay = EditableDay(drafts[clamped] ?? baseline(for: clamped))
        }
    }

    /// The selected day's times. Views bind straight to its fields.
    var editingDay: EditableDay {
        get { storedEditingDay }
        set {
            storedEditingDay = newValue
            recordEdit()
        }
    }

    var canGoBack: Bool { selectedDay > firstDay }
    var canGoForward: Bool { selectedDay < lastDay }

    func goToPreviousDay() {
        selectedDay = selectedDay.adding(days: -1)
    }

    func goToNextDay() {
        selectedDay = selectedDay.adding(days: 1)
    }

    var selectedDayStatus: DayStatus {
        if drafts[selectedDay] != nil { return .edited }
        if published[selectedDay] != nil { return .published }
        return .calculated
    }

    var issues: [ScheduleIssue] {
        ScheduleValidator.issues(in: editingDay.dailyTimes(on: selectedDay))
    }

    // MARK: - Editing

    /// Copies the selected day's times to the following `copyDayCount` days, within the window.
    func copyToFollowingDays() {
        let count = min(max(copyDayCount, 1), Self.maximumCopyDays)
        let source = editingDay
        for offset in 1...count {
            let day = selectedDay.adding(days: offset)
            guard day <= lastDay else { break }
            let times = source.dailyTimes(on: day)
            drafts[day] = source == EditableDay(baseline(for: day)) ? nil : times
        }
        resetPublishResult()
    }

    func revertSelectedDay() {
        editingDay = EditableDay(baseline(for: selectedDay))
    }

    // MARK: - Loading and publishing

    var editedDayCount: Int { drafts.count }

    var daysWithIssues: Int {
        drafts.values.filter { !ScheduleValidator.issues(in: $0).isEmpty }.count
    }

    var canPublish: Bool {
        !drafts.isEmpty && daysWithIssues == 0 && !publishState.isLoading
    }

    func load() async {
        guard !loadState.isLoading else { return }
        loadState = .loading
        do {
            let days = try await repository.schedule(masjidID: masjid.id, from: firstDay, through: lastDay)
            published = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
            loadState = .loaded(())
            if drafts[selectedDay] == nil {
                editingDay = EditableDay(baseline(for: selectedDay))
            }
        } catch {
            loadState = .failed(error)
        }
    }

    func publish() async {
        guard canPublish else { return }
        let days = drafts.values.sorted { $0.day < $1.day }
        publishState = .loading
        do {
            try await repository.publish(days, masjidID: masjid.id)
            for day in days {
                published[day.day] = day
                // Keep anything edited again while the publish was in flight.
                if drafts[day.day] == day {
                    drafts[day.day] = nil
                }
            }
            publishState = .loaded(days.count)
        } catch {
            publishState = .failed(error)
        }
    }

    // MARK: - Private

    private func recordEdit() {
        let times = storedEditingDay.dailyTimes(on: storedSelectedDay)
        let isUnchanged = storedEditingDay == EditableDay(baseline(for: storedSelectedDay))
        drafts[storedSelectedDay] = isUnchanged ? nil : times
        resetPublishResult()
    }

    private func resetPublishResult() {
        if !publishState.isLoading {
            publishState = .idle
        }
    }

    private func baseline(for day: CalendarDay) -> DailyPrayerTimes {
        published[day] ?? Self.calculatedTimes(on: day, masjid: masjid, timeZone: timeZone, calculator: calculator)
    }

    private static func calculatedTimes(on day: CalendarDay,
                                        masjid: Masjid,
                                        timeZone: TimeZone,
                                        calculator: any PrayerTimeCalculator) -> DailyPrayerTimes {
        do {
            return try calculator.times(on: day, at: masjid.coordinates, in: timeZone, parameters: masjid.calculation)
        } catch {
            // Only at polar latitudes: start from a plain template the admin overwrites.
            func time(_ hour: Int, _ minute: Int) -> WallClockTime {
                WallClockTime(wrappingMinutesSinceMidnight: hour * 60 + minute)
            }
            return DailyPrayerTimes(
                day: day,
                fajr: PrayerTime(adhan: time(5, 0)),
                sunrise: time(6, 30),
                dhuhr: PrayerTime(adhan: time(13, 0)),
                asr: PrayerTime(adhan: time(16, 30)),
                maghrib: PrayerTime(adhan: time(19, 0)),
                isha: PrayerTime(adhan: time(20, 30)),
                source: .calculated
            )
        }
    }
}
