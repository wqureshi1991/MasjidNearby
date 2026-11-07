import Foundation
import Testing
@testable import MasjidNearby

struct PrayerNotificationPlannerTests {
    private func plan(_ schedules: [MasjidSchedule],
                      settings: PrayerAlertSettings = AlertFixtures.enabled,
                      now: Date = OfflineFixtures.noon) -> [PrayerNotification] {
        PrayerNotificationPlanner.notifications(for: schedules, settings: settings,
                                                calculator: AlertFixtures.calculator, now: now)
    }

    private func schedule(_ id: String = "m1", published: [DailyPrayerTimes] = []) -> MasjidSchedule {
        MasjidSchedule(masjid: Fixtures.masjid(id: id, isVerified: true), published: published)
    }

    @Test func plansTheComingWeekSoonestFirst() {
        let alerts = plan([schedule()])

        #expect(alerts.count == AlertFixtures.alertsFromNoon)
        #expect(alerts.first?.prayer == .dhuhr)
        #expect(alerts.first?.fireDate == AlertFixtures.instant("12:57", on: "2026-10-21"))
        #expect(alerts.allSatisfy { $0.kind == .adhan && $0.fireDate > OfflineFixtures.noon })
        #expect(alerts.map(\.fireDate) == alerts.map(\.fireDate).sorted())
    }

    @Test func addsIqamahAlertsWherePublished() {
        let published = Fixtures.times(on: "2026-10-21", fajrIqamah: "06:10", source: .manual)
        let settings = PrayerAlertSettings(isEnabled: true, prayers: [.fajr], alertsAtIqamah: true)
        let alerts = plan([schedule(published: [published])], settings: settings,
                          now: AlertFixtures.instant("04:00", on: "2026-10-21"))

        // Today's adhan and iqamah, then only adhan on calculated days.
        #expect(alerts.count == 8)
        #expect(alerts[0].kind == .adhan)
        #expect(alerts[0].fireDate == AlertFixtures.instant("05:53", on: "2026-10-21"))
        #expect(alerts[1].kind == .iqamah)
        #expect(alerts[1].fireDate == AlertFixtures.instant("06:10", on: "2026-10-21"))
    }

    @Test func ishaAfterMidnightFiresTheNextDay() {
        let t = Fixtures.time
        let late = DailyPrayerTimes(day: Fixtures.day("2026-10-21"), fajr: PrayerTime(adhan: t("05:53")), sunrise: t("07:04"),
                                    dhuhr: PrayerTime(adhan: t("12:57")), asr: PrayerTime(adhan: t("16:17")),
                                    maghrib: PrayerTime(adhan: t("18:49")), isha: PrayerTime(adhan: t("00:30")),
                                    source: .manual)
        let alerts = plan([schedule(published: [late])], settings: PrayerAlertSettings(isEnabled: true, prayers: [.isha]))

        #expect(alerts.first?.fireDate == AlertFixtures.instant("00:30", on: "2026-10-22"))
    }

    @Test func staysWithinTheSystemLimit() {
        let alerts = plan([schedule("a"), schedule("b"), schedule("c")])

        #expect(alerts.count == PrayerNotificationPlanner.maximumPending)
        #expect(alerts.map(\.fireDate) == alerts.map(\.fireDate).sorted())
    }

    @Test func respectsTheSettings() {
        #expect(plan([schedule()], settings: PrayerAlertSettings()).isEmpty)
        #expect(plan([schedule()], settings: PrayerAlertSettings(isEnabled: true, prayers: [])).isEmpty)

        var muted = AlertFixtures.enabled
        muted[alertsForMasjid: "m1"] = false
        #expect(plan([schedule("m1"), schedule("m2")], settings: muted).allSatisfy { $0.masjidID == "m2" })

        let maghribOnly = plan([schedule()], settings: PrayerAlertSettings(isEnabled: true, prayers: [.maghrib]))
        #expect(maghribOnly.count == 7)
        #expect(maghribOnly.allSatisfy { $0.prayer == .maghrib })
    }

    @Test func alertIdentifiersAreUniqueAndPrefixed() {
        let alerts = plan([schedule("a"), schedule("b")])
        #expect(Set(alerts.map(\.id)).count == alerts.count)
        #expect(alerts.allSatisfy { $0.id.hasPrefix(PrayerNotification.identifierPrefix) })
    }
}
