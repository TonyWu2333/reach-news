import XCTest
@testable import ReachNews

// MARK: - 归一化与枚举

final class NormalizationTests: XCTestCase {
    func testMissedReasonKeepsUnknownValues() {
        XCTAssertEqual(MissedReason.parse("no-material"), .noMaterial)
        XCTAssertEqual(MissedReason.parse("queue-timeout"), .queueTimeout)
        XCTAssertEqual(MissedReason.parse("resume-writing"), .resumeWriting)
        // 服务端会新增原因：未知值必须保留原文。
        XCTAssertEqual(MissedReason.parse("rate-limited"), .unknown("rate-limited"))
        XCTAssertEqual(MissedReason.parse("rate-limited")?.rawValue, "rate-limited")
        XCTAssertNil(MissedReason.parse(nil))
        XCTAssertNil(MissedReason.parse(""))
    }

    func testErrorCodeKeepsUnknownValues() {
        XCTAssertEqual(APIErrorCode.parse("unauthorized"), .unauthorized)
        XCTAssertEqual(APIErrorCode.parse("not_found"), .notFound)
        XCTAssertEqual(APIErrorCode.parse("invalid_input"), .invalidInput)
        XCTAssertEqual(APIErrorCode.parse("busy"), .busy)
        XCTAssertEqual(APIErrorCode.parse("bad_request"), .badRequest)
        XCTAssertEqual(APIErrorCode.parse("internal_error"), .internalError)
        XCTAssertEqual(APIErrorCode.parse("teapot"), .unknown("teapot"))
        XCTAssertEqual(APIErrorCode.parse("teapot").rawValue, "teapot")
    }

    func testErrorEnvelopeNormalization() throws {
        let busy = Data(#"{"error":{"code":"busy","message":"Channel has a run in progress"}}"#.utf8)
        let decoded = try JSONDecoder().decode(ErrorEnvelope.self, from: busy)
        XCTAssertEqual(decoded.normalized, .busy("Channel has a run in progress"))
        XCTAssertTrue(decoded.normalized.isBusy)

        let notFound = Data(#"{"error":{"code":"not_found","message":"Resource not found"}}"#.utf8)
        let decodedNotFound = try JSONDecoder().decode(ErrorEnvelope.self, from: notFound)
        XCTAssertEqual(decodedNotFound.normalized, .notFound)
    }

    func testRunStateThreeWaySplit() {
        XCTAssertTrue(RunState.queued.isRunning)
        XCTAssertTrue(RunState.collecting.isRunning)
        XCTAssertTrue(RunState.writing.isRunning)

        XCTAssertFalse(RunState.published.isRunning)
        XCTAssertTrue(RunState.published.producedBrief)

        // missed 不是失败，也不产出日报。
        XCTAssertFalse(RunState.missed.isRunning)
        XCTAssertFalse(RunState.missed.producedBrief)

        XCTAssertFalse(RunState.failed.isRunning)
        XCTAssertFalse(RunState.cancelled.producedBrief)
        XCTAssertEqual(RunState(rawValue: "collecting"), .collecting)
    }

    func testChannelKindParsing() {
        XCTAssertEqual(ChannelKind(apiValue: "channel"), .channel)
        XCTAssertEqual(ChannelKind(apiValue: "follow"), .follow)
        // 未知值回落为普通频道，不崩溃、不丢数据。
        XCTAssertEqual(ChannelKind(apiValue: "something-new"), .channel)
        XCTAssertEqual(ChannelKind(apiValue: nil), .channel)
    }

    func testScheduleParsingAndNormalization() {
        let schedule = Schedule(timesByWeekday: [
            "mon": ["08:00", "8:00", "25:00"],
            "wed": ["08:00"],
            "sat": []
        ])

        // 非两位小时与越界时间被丢弃；重复时刻去重。
        XCTAssertEqual(schedule.times(for: Schedule.Weekday.all[0]), ["08:00"])
        XCTAssertEqual(schedule.times(for: Schedule.Weekday.all[2]), ["08:00"])
        XCTAssertTrue(schedule.times(for: Schedule.Weekday.all[5]).isEmpty)

        XCTAssertEqual(schedule.activeWeekdays.map(\.key), ["mon", "wed"])
        XCTAssertEqual(schedule.allTimes, ["08:00"])
        XCTAssertFalse(schedule.isEmpty)
    }

    func testScheduleToggleAndAddRemove() {
        var schedule = Schedule()
        XCTAssertTrue(schedule.isEmpty)

        let monday = Schedule.Weekday.all[0]
        schedule.toggle(monday)
        XCTAssertTrue(schedule.isEnabled(monday))
        XCTAssertEqual(schedule.times(for: monday), ["08:00"])

        schedule.addTime("18:00", to: monday)
        XCTAssertEqual(schedule.times(for: monday), ["08:00", "18:00"])

        schedule.removeTime("08:00", from: monday)
        XCTAssertEqual(schedule.times(for: monday), ["18:00"])

        schedule.toggle(monday)
        XCTAssertFalse(schedule.isEnabled(monday))
        XCTAssertTrue(schedule.isEmpty)
    }

    func testScheduleValidation() {
        XCTAssertTrue(Schedule.isValid("00:00"))
        XCTAssertTrue(Schedule.isValid("23:59"))
        XCTAssertFalse(Schedule.isValid("24:00"))
        XCTAssertFalse(Schedule.isValid("08:60"))
        XCTAssertFalse(Schedule.isValid("8:00"))
        XCTAssertFalse(Schedule.isValid("0800"))
        XCTAssertFalse(Schedule.isValid(""))
    }

    func testDisplayTimeUsesShanghaiTimeZone() {
        // 02:01:50 UTC 在 Asia/Shanghai 是 10:01。
        let date = Date(timeIntervalSince1970: 1795140110.774)
        let locale = Locale(identifier: "zh-Hans")
        XCTAssertEqual(DisplayTime.clock(date, locale: locale), "10:01")
        XCTAssertEqual(DisplayTime.monthDayTime(date, locale: locale), "11月20日 10:01")
        XCTAssertEqual(DisplayTime.monthDay(date, locale: locale), "11月20日")
    }

    func testDayRuleTitleUsesRelativeWordsForTodayAndYesterday() {
        let calendar = Calendar.shanghai
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let older = calendar.date(byAdding: .day, value: -3, to: now)!
        let locale = Locale(identifier: "zh-Hans")

        XCTAssertEqual(DisplayTime.dayRuleTitle(now, now: now, locale: locale), "今天")
        XCTAssertEqual(DisplayTime.dayRuleTitle(yesterday, now: now, locale: locale), "昨天")
        XCTAssertEqual(DisplayTime.dayRuleTitle(older, now: now, locale: locale), "11月17日")
    }

    func testDayGroupingBucketsByShanghaiDay() {
        let calendar = Calendar.shanghai
        // 同一 UTC 日跨 Shanghai 日界：Shanghai 11-20 01:00 与 11-19 23:30 分属两天。
        let lateUtc = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 1))!
        let early = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 23, minute: 30))!

        let briefs = [
            makeBrief(id: "b1", createdAt: lateUtc),
            makeBrief(id: "b2", createdAt: early)
        ]
        let groups = BriefFeed.groupedByDay(briefs)

        XCTAssertEqual(groups.count, 2)
        // 倒序：Shanghai 11-20 在前。
        XCTAssertEqual(groups.first?.briefs.map(\.id), ["b1"])
        XCTAssertEqual(groups.last?.briefs.map(\.id), ["b2"])
    }

    func testChannelTintIsStablePerID() {
        let id = "chn_c7e81f00-3a2f-4f7b-9a1e-0d5c2b7e4a11"
        let first = ChannelTint.color(for: id)
        let second = ChannelTint.color(for: id)
        XCTAssertEqual(first, second)
        // 同一 id 永远落在同一索引。
        XCTAssertEqual(Palette.channelTints.firstIndex(of: first),
                       Palette.channelTints.firstIndex(of: second))
    }

    // MARK: 辅助

    private func makeBrief(id: String, createdAt: Date) -> Brief {
        Brief(
            id: id,
            channelID: "chn_test",
            title: id,
            sections: [],
            memorySummary: "",
            createdAt: createdAt
        )
    }
}
