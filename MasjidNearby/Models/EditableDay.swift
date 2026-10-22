import Foundation

/// One prayer's times as a form edits them. The iqamah value is kept while switched off,
/// so toggling it back on restores what was there.
struct EditablePrayer: Sendable {
    var adhan: WallClockTime
    var hasIqamah: Bool
    var iqamah: WallClockTime

    init(_ time: PrayerTime) {
        adhan = time.adhan
        hasIqamah = time.iqamah != nil
        iqamah = time.iqamah ?? time.adhan.adding(minutes: 15)
    }

    var prayerTime: PrayerTime {
        PrayerTime(adhan: adhan, iqamah: hasIqamah ? iqamah : nil)
    }
}

extension EditablePrayer: Equatable {
    /// Equal when they publish the same times; a hidden iqamah value doesn't count.
    static func == (lhs: EditablePrayer, rhs: EditablePrayer) -> Bool {
        lhs.prayerTime == rhs.prayerTime
    }
}

/// A day's schedule as the editor binds to it.
struct EditableDay: Sendable, Equatable {
    var fajr: EditablePrayer
    var sunrise: WallClockTime
    var dhuhr: EditablePrayer
    var asr: EditablePrayer
    var maghrib: EditablePrayer
    var isha: EditablePrayer

    init(_ times: DailyPrayerTimes) {
        fajr = EditablePrayer(times.fajr)
        sunrise = times.sunrise
        dhuhr = EditablePrayer(times.dhuhr)
        asr = EditablePrayer(times.asr)
        maghrib = EditablePrayer(times.maghrib)
        isha = EditablePrayer(times.isha)
    }

    /// The times a masjid publishes for `day`.
    func dailyTimes(on day: CalendarDay) -> DailyPrayerTimes {
        DailyPrayerTimes(
            day: day,
            fajr: fajr.prayerTime,
            sunrise: sunrise,
            dhuhr: dhuhr.prayerTime,
            asr: asr.prayerTime,
            maghrib: maghrib.prayerTime,
            isha: isha.prayerTime,
            source: .manual
        )
    }
}
