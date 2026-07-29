import Foundation
import XCTest

@testable import MihomoMeter

final class QuotaUsageChartAxisTests: XCTestCase {
  func testBuildsEqualNaturalSlotsAndPreservesMissingBucket() {
    let calendar = utcCalendar()
    let rangeStart = Date(timeIntervalSince1970: 1_704_067_200)
    let rangeEnd = rangeStart.addingTimeInterval(3 * 3_600)
    let firstInterval = DateInterval(
      start: rangeStart,
      duration: 3_600
    )
    let thirdInterval = DateInterval(
      start: rangeStart.addingTimeInterval(2 * 3_600),
      duration: 3_600
    )
    let series = makeSeries(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      aggregation: .hour,
      intervals: [firstInterval, thirdInterval]
    )

    let axis = QuotaUsageChartAxis(series: series, calendar: calendar)

    XCTAssertEqual(axis.slots.map(\.index), [0, 1, 2])
    XCTAssertNotNil(axis.slots[0].bar)
    XCTAssertNil(axis.slots[1].bar)
    XCTAssertNotNil(axis.slots[2].bar)
  }

  func testNaturalHourRangeDropsLeadingPartialBucketAndKeepsCurrentBucket() {
    let calendar = utcCalendar()
    let rangeStart = Date(timeIntervalSince1970: 1_704_069_000)
    let rangeEnd = rangeStart.addingTimeInterval(24 * 3_600)

    let intervals = QuotaUsageAggregator.bucketIntervals(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      aggregation: .hour,
      calendar: calendar
    )

    XCTAssertEqual(intervals.count, 24)
    XCTAssertEqual(
      intervals.first?.start,
      calendar.date(bySettingHour: 1, minute: 0, second: 0, of: rangeStart)
    )
    XCTAssertEqual(intervals.last?.start, rangeEnd.addingTimeInterval(-30 * 60))
  }

  func testThirtyDayRangeProducesThirtyNaturalDaySlots() {
    let calendar = utcCalendar()
    let rangeStart = Date(timeIntervalSince1970: 1_704_105_000)
    let rangeEnd = rangeStart.addingTimeInterval(30 * 24 * 3_600)

    let intervals = QuotaUsageAggregator.bucketIntervals(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      aggregation: .day,
      calendar: calendar
    )

    XCTAssertEqual(intervals.count, 30)
    XCTAssertTrue(intervals.allSatisfy { calendar.startOfDay(for: $0.start) == $0.start })
  }

  func testMapsTrendWindowsToDefaultAggregations() {
    XCTAssertEqual(QuotaTrendWindow.day.defaultUsageAggregation, .hour)
    XCTAssertEqual(QuotaTrendWindow.week.defaultUsageAggregation, .day)
    XCTAssertEqual(QuotaTrendWindow.month.defaultUsageAggregation, .day)
    XCTAssertEqual(QuotaTrendWindow.year.defaultUsageAggregation, .month)
  }

  func testLargeChartFitsThirtyOneDailySlotsWithoutScrolling() {
    XCTAssertEqual(
      QuotaTrendChartLayout.contentWidth(slotCount: 31),
      QuotaTrendChartLayout.minimumViewportWidth
    )
  }

  func testLargeChartExpandsForHighDensityAggregation() {
    XCTAssertEqual(
      QuotaTrendChartLayout.contentWidth(slotCount: 168),
      2_760
    )
  }

  private func makeSeries(
    rangeStart: Date,
    rangeEnd: Date,
    aggregation: QuotaUsageAggregation,
    intervals: [DateInterval]
  ) -> QuotaUsageSeries {
    QuotaUsageSeries(
      requestedAggregation: aggregation,
      resolvedAggregation: aggregation,
      bars: intervals.map { interval in
        QuotaUsageBar(
          id: QuotaUsagePeriodID(
            startAt: interval.start,
            endAt: interval.end
          ),
          startAt: interval.start,
          endAt: interval.end,
          uploadBytes: 10,
          downloadBytes: 100,
          intervalCount: 1,
          isBoundaryApproximation: false
        )
      },
      unresolvedIntervals: [],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd
    )
  }

  private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }
}
