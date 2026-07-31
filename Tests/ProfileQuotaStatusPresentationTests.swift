import Foundation
import XCTest

@testable import MihomoMeter

final class ProfileQuotaStatusPresentationTests: SQLiteQuotaLedgerTestCase {
  func testScheduledSummaryIncludesLastUpdateAndNextQuery() throws {
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let updatedAt = now.addingTimeInterval(-7_200)
    let queryAt = now.addingTimeInterval(10_800)
    let item = try trackingItem(
      at: now,
      latestQuotaAt: updatedAt,
      queryStatus: .scheduled(queryAt)
    )

    let presentation = ProfileQuotaStatusPresentation(item: item, relativeTo: now)
    let lastUpdate = SubscriptionQuotaFormatter.updatedAt(updatedAt, relativeTo: now)
    let nextQuery = SubscriptionQuotaFormatter.upcomingDate(queryAt, relativeTo: now)

    XCTAssertEqual(
      presentation.compactSummary,
      "\(lastUpdate)更新 · \(nextQuery)再次查询"
    )
    XCTAssertFalse(presentation.compactSummary.contains("已安排下次查询"))
  }

  func testScheduledSummaryExplainsPendingFirstQuery() throws {
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let queryAt = now.addingTimeInterval(10_800)
    let item = try trackingItem(
      at: now,
      latestQuotaAt: nil,
      queryStatus: .scheduled(queryAt)
    )

    let presentation = ProfileQuotaStatusPresentation(item: item, relativeTo: now)
    let nextQuery = SubscriptionQuotaFormatter.upcomingDate(queryAt, relativeTo: now)

    XCTAssertEqual(presentation.compactSummary, "等待首次查询 · \(nextQuery)查询")
  }

  func testNearNowDatesUseStableBoundaryWording() throws {
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let item = try trackingItem(
      at: now,
      latestQuotaAt: now.addingTimeInterval(1),
      queryStatus: .scheduled(now.addingTimeInterval(1))
    )

    let presentation = ProfileQuotaStatusPresentation(item: item, relativeTo: now)

    XCTAssertEqual(SubscriptionQuotaFormatter.updatedAt(now, relativeTo: now), "刚刚")
    XCTAssertEqual(
      SubscriptionQuotaFormatter.upcomingDate(now, relativeTo: now),
      "即将"
    )
    XCTAssertEqual(presentation.compactSummary, "刚刚更新 · 即将再次查询")
  }

  func testOperationalFailureOverridesForecastButScheduledStateDoesNot() throws {
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let updatedAt = now.addingTimeInterval(-7_200)
    let retryAt = now.addingTimeInterval(900)
    let scheduledItem = try trackingItem(
      at: now,
      latestQuotaAt: updatedAt,
      queryStatus: .scheduled(now.addingTimeInterval(10_800))
    )
    let failedItem = try trackingItem(
      at: now,
      latestQuotaAt: updatedAt,
      queryStatus: .failed(
        message: "网络不可用",
        retryAt: retryAt,
        manualRetryPolicy: .immediate
      )
    )

    let scheduled = ProfileQuotaStatusPresentation(item: scheduledItem, relativeTo: now)
    let failed = ProfileQuotaStatusPresentation(item: failedItem, relativeTo: now)

    XCTAssertFalse(scheduled.overridesForecast)
    XCTAssertTrue(failed.overridesForecast)
    XCTAssertEqual(failed.title, "本次查询失败")
    XCTAssertEqual(
      failed.compactSummary,
      "2小时前更新 · \(SubscriptionQuotaFormatter.upcomingDate(retryAt, relativeTo: now))自动重试"
    )
  }

  func testCanonicalForecastUsesSevenDayTrendIndependentOfStatusMenuRange() {
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let estimatedAt = now.addingTimeInterval(3.2 * 86_400)
    let trends = RuntimeQuotaTrends(
      day: trend(
        window: .day,
        forecast: .unavailable(.insufficientObservationSpan)
      ),
      week: trend(window: .week, forecast: .available(estimatedAt)),
      month: trend(window: .month, forecast: .unavailable(.staleData)),
      year: trend(window: .year, forecast: .unavailable(.unconfirmedCycle))
    )

    XCTAssertEqual(RuntimeQuotaTrends.depletionForecastWindow, .week)
    XCTAssertEqual(trends.depletionForecast, .available(estimatedAt))
    XCTAssertEqual(StatusMenuQuotaMetricsView.supportedWindows, [.day, .week])
    XCTAssertEqual(
      SubscriptionQuotaFormatter.depletion(trends.depletionForecast, relativeTo: now),
      "预计可用约 4 天"
    )
  }

  private func trackingItem(
    at date: Date,
    latestQuotaAt: Date?,
    queryStatus: ProfileQuotaQueryStatus
  ) throws -> ProfileQuotaTrackingItem {
    let subscription = try profileSubscription(at: date)
    let latestQuota = try latestQuotaAt.map { effectiveAt in
      let observation = try observation(
        subscriptionID: subscription.id,
        at: effectiveAt,
        source: .meterActiveQuery,
        usedBytes: 300,
        totalBytes: 1_000
      )
      return SubscriptionQuotaSnapshot(
        id: UUID(),
        cycleID: UUID(),
        observation: observation
      )
    }
    return ProfileQuotaTrackingItem(
      subscription: subscription,
      profileUID: "profile-test",
      isCurrent: true,
      availability: .available,
      analysis: SubscriptionQuotaAnalysis(
        latestQuota: latestQuota,
        trends: RuntimeQuotaTrends(),
        currentCycle: nil,
        recentEvents: []
      ),
      queryStatus: queryStatus,
      isManualRefreshEligible: true,
      manualRefreshAvailableAt: nil
    )
  }

  private func trend(
    window: QuotaTrendWindow,
    forecast: QuotaDepletionForecast
  ) -> QuotaTrend {
    QuotaTrend(
      window: window,
      points: [],
      segments: [],
      usageByAggregation: [:],
      consumedBytes: nil,
      dailyConsumptionBytes: nil,
      depletionForecast: forecast
    )
  }
}
