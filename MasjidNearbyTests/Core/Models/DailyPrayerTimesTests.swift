import Foundation
import Testing
@testable import MasjidNearby

struct DailyPrayerTimesTests {
    @Test func decodesAScheduleDocument() throws {
        let json = """
        {
          "day": "2026-10-02",
          "fajr": { "adhan": "05:53", "iqamah": "06:15" },
          "sunrise": "07:04",
          "dhuhr": { "adhan": "12:57", "iqamah": "13:30" },
          "asr": { "adhan": "16:17", "iqamah": "16:45" },
          "maghrib": { "adhan": "18:49" },
          "isha": { "adhan": "20:01", "iqamah": "20:30" },
          "source": "manual"
        }
        """
        let times = try JSONDecoder().decode(DailyPrayerTimes.self, from: Data(json.utf8))

        #expect(times.day.key == "2026-10-02")
        #expect(times.source == .manual)
        #expect(times[.fajr].iqamah?.description == "06:15")
        #expect(times[.maghrib].adhan.description == "18:49")
        #expect(times[.maghrib].iqamah == nil)
        #expect(try JSONDecoder().decode(DailyPrayerTimes.self, from: JSONEncoder().encode(times)) == times)
    }

    @Test func unknownSourceFailsToDecode() {
        let json = """
        { "day": "2026-10-02", "fajr": { "adhan": "05:53" }, "sunrise": "07:04", "dhuhr": { "adhan": "12:57" },
          "asr": { "adhan": "16:17" }, "maghrib": { "adhan": "18:49" }, "isha": { "adhan": "20:01" }, "source": "guess" }
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DailyPrayerTimes.self, from: Data(json.utf8))
        }
    }

    @Test func calculationMethodRawValuesAreStable() {
        #expect(CalculationMethod.isna.rawValue == "isna")
        #expect(CalculationMethod.muslimWorldLeague.rawValue == "mwl")
        #expect(CalculationMethod.ummAlQura.rawValue == "ummAlQura")
        #expect(CalculationMethod.egyptian.rawValue == "egyptian")
        #expect(CalculationMethod.karachi.rawValue == "karachi")
        #expect(AsrMadhab.standard.shadowFactor == 1)
        #expect(AsrMadhab.hanafi.shadowFactor == 2)
    }
}
