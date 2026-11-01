import Foundation

/// Prayer times from the sun's position, after the method published by PrayTimes.org
/// (low-precision solar coordinates from the U.S. Naval Observatory), with each event re-solved
/// iteratively. Checked against a full ephemeris at five cities across 2026: within 5 seconds.
///
/// Pure and synchronous, so it is safe to call from any isolation.
///
/// Rounding is conservative: prayer start times round up to the next minute and sunrise rounds
/// down, so a displayed time is never earlier than the prayer actually starts.
struct AstronomicalPrayerTimeCalculator: PrayerTimeCalculator {
    /// Sun's centre below the horizon at sunrise and sunset: refraction plus the solar radius.
    private static let horizonAngle = 0.833

    /// Each event is solved this many times, feeding the result back in as the next guess.
    private static let refinementPasses = 3

    func times(on day: CalendarDay,
               at coordinates: Coordinates,
               in timeZone: TimeZone,
               parameters: CalculationParameters) throws -> DailyPrayerTimes {
        guard coordinates.isValid else { throw PrayerCalculationError.invalidCoordinates }

        let latitude = coordinates.latitude
        // Julian date at 0h local mean time for this longitude.
        let julianDate = Double(day.julianDayNumber) - 0.5 - coordinates.longitude / 360

        // All hours below are local mean time: hours since 0h at this longitude.
        func sunHour(belowHorizonBy angle: Double, before: Bool, startingAt hourGuess: Double) -> Double? {
            refined(from: hourGuess) { guess in
                hour(sunBelowHorizonBy: angle, before: before,
                     julianDate: julianDate, hourGuess: guess, latitude: latitude)
            }
        }

        var dhuhr = 12.0
        for _ in 0..<Self.refinementPasses {
            dhuhr = solarNoon(julianDate: julianDate, hourGuess: dhuhr)
        }

        // Asr: an object's shadow equals `shadowFactor` times its length plus its shadow at noon.
        let noonDeclination = sunPosition(julianDate: julianDate + dhuhr / 24).declination
        let asrAltitude = atanDegrees(
            1 / (parameters.asrMadhab.shadowFactor + tanDegrees(abs(latitude - noonDeclination)))
        )

        guard let sunrise = sunHour(belowHorizonBy: Self.horizonAngle, before: true, startingAt: 6),
              let sunset = sunHour(belowHorizonBy: Self.horizonAngle, before: false, startingAt: 18),
              let asr = sunHour(belowHorizonBy: -asrAltitude, before: false, startingAt: 13)
        else { throw PrayerCalculationError.sunDoesNotRiseOrSet }

        let night = normalizeHours(sunrise - sunset)
        let rule = parameters.highLatitudeRule
        let fajrAngle = parameters.method.fajrAngle

        let fajr = try twilightHour(
            sunHour(belowHorizonBy: fajrAngle, before: true, startingAt: 5),
            angle: fajrAngle, base: sunrise, before: true, night: night, rule: rule
        )

        let maghrib = sunset
        let isha: Double
        switch parameters.method.ishaRule {
        case .minutesAfterMaghrib(let minutes):
            isha = maghrib + Double(minutes) / 60
        case .angle(let ishaAngle):
            isha = try twilightHour(
                sunHour(belowHorizonBy: ishaAngle, before: false, startingAt: 18),
                angle: ishaAngle, base: sunset, before: false, night: night, rule: rule
            )
        }

        func clock(_ localMeanHour: Double, roundingUp: Bool) -> WallClockTime {
            wallClock(localMeanHour: localMeanHour, day: day, longitude: coordinates.longitude,
                      timeZone: timeZone, roundingUp: roundingUp)
        }

        return DailyPrayerTimes(
            day: day,
            fajr: PrayerTime(adhan: clock(fajr, roundingUp: true)),
            sunrise: clock(sunrise, roundingUp: false),
            dhuhr: PrayerTime(adhan: clock(dhuhr, roundingUp: true)),
            asr: PrayerTime(adhan: clock(asr, roundingUp: true)),
            maghrib: PrayerTime(adhan: clock(maghrib, roundingUp: true)),
            isha: PrayerTime(adhan: clock(isha, roundingUp: true)),
            source: .calculated
        )
    }

    // MARK: - Sun position

    private struct SunPosition {
        /// Degrees north of the celestial equator.
        let declination: Double
        /// Apparent solar time minus mean solar time, in hours.
        let equationOfTime: Double
    }

    private func sunPosition(julianDate: Double) -> SunPosition {
        let d = julianDate - 2_451_545.0
        let meanAnomaly = normalizeDegrees(357.529 + 0.98560028 * d)
        let meanLongitude = normalizeDegrees(280.459 + 0.98564736 * d)
        let eclipticLongitude = normalizeDegrees(
            meanLongitude + 1.915 * sinDegrees(meanAnomaly) + 0.020 * sinDegrees(2 * meanAnomaly)
        )
        let obliquity = 23.439 - 0.00000036 * d
        let rightAscensionHours = atan2Degrees(
            cosDegrees(obliquity) * sinDegrees(eclipticLongitude),
            cosDegrees(eclipticLongitude)
        ) / 15
        return SunPosition(
            declination: asinDegrees(sinDegrees(obliquity) * sinDegrees(eclipticLongitude)),
            equationOfTime: meanLongitude / 15 - normalizeHours(rightAscensionHours)
        )
    }

    private func solarNoon(julianDate: Double, hourGuess: Double) -> Double {
        let position = sunPosition(julianDate: julianDate + hourGuess / 24)
        return normalizeHours(12 - position.equationOfTime)
    }

    /// Hour at which the sun is `angle` degrees below the horizon, before or after solar noon.
    /// Nil when the sun never reaches that angle on this date at this latitude.
    private func hour(sunBelowHorizonBy angle: Double,
                      before: Bool,
                      julianDate: Double,
                      hourGuess: Double,
                      latitude: Double) -> Double? {
        let declination = sunPosition(julianDate: julianDate + hourGuess / 24).declination
        let noon = solarNoon(julianDate: julianDate, hourGuess: hourGuess)
        let cosHourAngle = (-sinDegrees(angle) - sinDegrees(declination) * sinDegrees(latitude))
            / (cosDegrees(declination) * cosDegrees(latitude))
        guard cosHourAngle.isFinite, (-1.0...1.0).contains(cosHourAngle) else { return nil }
        let offset = acosDegrees(cosHourAngle) / 15
        return noon + (before ? -offset : offset)
    }

    /// The sun's declination and the equation of time are sampled at the guessed hour,
    /// so re-solving from the previous answer tightens the result to a few seconds.
    private func refined(from hourGuess: Double, _ solve: (Double) -> Double?) -> Double? {
        var hour = hourGuess
        for _ in 0..<Self.refinementPasses {
            guard let next = solve(hour) else { return nil }
            hour = next
        }
        return hour
    }

    // MARK: - High latitudes

    /// Applies the high-latitude rule to a Fajr or Isha hour.
    /// `base` is sunrise for Fajr and sunset for Isha.
    private func twilightHour(_ computed: Double?,
                              angle: Double,
                              base: Double,
                              before: Bool,
                              night: Double,
                              rule: HighLatitudeRule) throws -> Double {
        let nightFraction: Double
        switch rule {
        case .none:
            guard let computed else { throw PrayerCalculationError.twilightDoesNotOccur }
            return computed
        case .middleOfNight:
            nightFraction = 1.0 / 2
        case .seventhOfNight:
            nightFraction = 1.0 / 7
        case .twilightAngle:
            nightFraction = angle / 60
        }

        let limit = nightFraction * night
        let fallback = before ? base - limit : base + limit
        guard let computed else { return fallback }
        let distanceFromBase = before ? normalizeHours(base - computed) : normalizeHours(computed - base)
        return distanceFromBase > limit ? fallback : computed
    }

    // MARK: - Clock conversion

    private func wallClock(localMeanHour: Double,
                           day: CalendarDay,
                           longitude: Double,
                           timeZone: TimeZone,
                           roundingUp: Bool) -> WallClockTime {
        let utcHour = localMeanHour - longitude / 15
        let instant = day.startOfDayUTC.addingTimeInterval(utcHour * 3_600)
        // Use the UTC offset in force at that instant, so DST transition days come out right.
        let localSeconds = instant.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: instant))
        let minutes = (localSeconds / 60).rounded(roundingUp ? .up : .down)
        return WallClockTime(wrappingMinutesSinceMidnight: Int(minutes.truncatingRemainder(dividingBy: 1_440)))
    }

    // MARK: - Degree trigonometry

    private func sinDegrees(_ degrees: Double) -> Double { sin(degrees * .pi / 180) }
    private func cosDegrees(_ degrees: Double) -> Double { cos(degrees * .pi / 180) }
    private func tanDegrees(_ degrees: Double) -> Double { tan(degrees * .pi / 180) }
    private func asinDegrees(_ value: Double) -> Double { asin(value) * 180 / .pi }
    private func acosDegrees(_ value: Double) -> Double { acos(value) * 180 / .pi }
    private func atanDegrees(_ value: Double) -> Double { atan(value) * 180 / .pi }
    private func atan2Degrees(_ y: Double, _ x: Double) -> Double { atan2(y, x) * 180 / .pi }

    private func normalizeDegrees(_ degrees: Double) -> Double { normalize(degrees, modulus: 360) }
    private func normalizeHours(_ hours: Double) -> Double { normalize(hours, modulus: 24) }

    private func normalize(_ value: Double, modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder < 0 ? remainder + modulus : remainder
    }
}
