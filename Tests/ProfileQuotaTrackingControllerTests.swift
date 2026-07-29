import Foundation
import XCTest

@testable import MihomoMeter

@MainActor
final class ProfileQuotaTrackingControllerTests: SQLiteQuotaLedgerTestCase {
  func testQueriesSelectedProfileThroughValidatedMihomoProxy() async throws {
    let context = try await makeContext()
    defer { context.stop() }

    context.controller.updateTargets([context.target])
    context.connectProxy(globalUserAgent: "mihomo-test-agent")
    try await waitUntil {
      context.controller.snapshot.profiles.first?.queryStatus == .available
    }

    let item = try XCTUnwrap(context.controller.snapshot.profiles.first)
    XCTAssertEqual(item.latestQuota?.traffic.remainingBytes, 700)
    XCTAssertEqual(item.queryStatus, .available)
    XCTAssertFalse(item.canRefresh)
    let metrics = await context.queryClient.metrics()
    XCTAssertEqual(metrics.userAgents, ["mihomo-test-agent"])
    let state = try await context.ledger.profileQueryState(for: context.subscription.id)
    XCTAssertEqual(state?.nextAttemptAt, context.now.addingTimeInterval(21_600))
  }

  func testWaitsWithoutDirectFallbackWhenMihomoHasNoProxyPort() async throws {
    let context = try await makeContext()
    defer { context.stop() }

    context.controller.updateTargets([context.target])
    context.controller.controllerValidated(
      endpoint: try ControllerEndpoint(address: "127.0.0.1:9090"),
      runtimeConfiguration: runtimeConfiguration(mixedPort: nil)
    )
    try await waitUntil { !context.controller.snapshot.profiles.isEmpty }

    let metrics = await context.queryClient.metrics()
    XCTAssertEqual(metrics.queryCount, 0)
    XCTAssertEqual(
      context.controller.snapshot.profiles.first?.queryStatus,
      .waitingForProxy
    )
  }

  func testRenameKeepsScheduleAndURLChangeQueriesImmediately() async throws {
    let context = try await makeContext(responseCount: 2)
    defer { context.stop() }
    context.controller.updateTargets([context.target])
    context.connectProxy()
    try await waitUntil {
      context.controller.snapshot.profiles.first?.queryStatus == .available
    }

    let renamed = try replacing(
      context.subscription,
      name: "新名称",
      fingerprint: context.subscription.urlFingerprint,
      updatedAt: context.now.addingTimeInterval(1)
    )
    _ = try await context.ledger.upsertSubscription(renamed)
    context.controller.updateTargets([
      target(subscription: renamed, url: "https://example.com/first")
    ])
    try await Task.sleep(nanoseconds: 50_000_000)
    let renamedMetrics = await context.queryClient.metrics()
    XCTAssertEqual(renamedMetrics.queryCount, 1)

    let changed = try replacing(
      renamed,
      name: renamed.name,
      fingerprint: "fingerprint-new-url",
      updatedAt: context.now.addingTimeInterval(2)
    )
    _ = try await context.ledger.upsertSubscription(changed)
    context.controller.updateTargets([
      target(subscription: changed, url: "https://example.com/second")
    ])
    try await waitUntil {
      let state = try? await context.ledger.profileQueryState(for: changed.id)
      return state?.lastQueriedURLFingerprint == changed.urlFingerprint
        && context.controller.snapshot.profiles.first?.queryStatus == .available
    }
  }

  func testSerializesMultipleDueProfiles() async throws {
    let context = try await makeContext(responseCount: 2)
    defer { context.stop() }
    let secondary = try profileSubscription(
      name: "备用 Profile",
      uid: "profile-secondary",
      at: context.now
    )
    _ = try await context.ledger.upsertSubscription(secondary)

    context.controller.updateTargets([
      context.target,
      target(
        subscription: secondary,
        url: "https://secondary.example/sub",
        isCurrent: false
      ),
    ])
    context.connectProxy()
    try await waitUntil {
      context.controller.snapshot.profiles.compactMap(\.latestQuota).count == 2
    }

    let metrics = await context.queryClient.metrics()
    XCTAssertEqual(metrics.maximumConcurrentQueries, 1)
    XCTAssertEqual(context.controller.snapshot.profiles.compactMap(\.latestQuota).count, 2)
  }

  func testLogsTypedMissingHeaderFailureWithoutSensitiveProfileData() async throws {
    let context = try await makeContext(
      queryResponses: [
        .failure(.missingSubscriptionUserInfo(statusCode: 200))
      ]
    )
    defer { context.stop() }

    context.controller.updateTargets([context.target])
    context.connectProxy()
    try await waitUntil {
      guard case .failed = context.controller.snapshot.profiles.first?.queryStatus else {
        return false
      }
      return true
    }

    let messages = await context.diagnosticLogger.messages()
    let joinedMessages = messages.joined(separator: "\n")
    XCTAssertTrue(joinedMessages.contains("event=profile_quota.query.started"))
    XCTAssertTrue(joinedMessages.contains("event=profile_quota.query.finished"))
    XCTAssertTrue(joinedMessages.contains("result=missing_subscription_info http_status=200"))
    XCTAssertTrue(joinedMessages.contains("user_agent_source=mihomo_default"))
    XCTAssertTrue(joinedMessages.contains("retry_after_seconds=300"))
    XCTAssertFalse(joinedMessages.contains(context.subscription.name))
    XCTAssertFalse(joinedMessages.contains(context.target.profileUID))
    XCTAssertFalse(joinedMessages.contains("https://example.com/first"))
    XCTAssertFalse(joinedMessages.contains(context.subscription.urlFingerprint ?? ""))
  }

  private func makeContext(
    responseCount: Int = 1,
    queryResponses: [Result<ActiveQuotaQueryResult, ActiveQuotaQueryError>]? = nil
  ) async throws -> ProfileQuotaTestContext {
    let database = temporaryDatabase()
    let ledger = SQLiteQuotaLedger(databaseURL: database)
    let now = Date(timeIntervalSince1970: 1_700_800_000)
    let subscription = try profileSubscription(at: now)
    _ = try await ledger.upsertSubscription(subscription)
    let result = ActiveQuotaQueryResult(
      traffic: try QuotaTraffic(uploadBytes: 100, downloadBytes: 200, totalBytes: 1_000),
      expireAt: nil
    )
    let queryClient = TestActiveQuotaQueryClient(
      responses: queryResponses ?? Array(repeating: .success(result), count: responseCount)
    )
    let diagnosticLogger = TestProfileQuotaDiagnosticLogger()
    let controller = ProfileQuotaTrackingController(
      ledger: ledger,
      queryClient: queryClient,
      diagnosticLogger: diagnosticLogger,
      now: { now },
      jitter: { 0 }
    )
    await controller.prepare()
    return ProfileQuotaTestContext(
      database: database,
      ledger: ledger,
      queryClient: queryClient,
      diagnosticLogger: diagnosticLogger,
      controller: controller,
      subscription: subscription,
      target: target(subscription: subscription, url: "https://example.com/first"),
      now: now,
      removeDatabase: removeDatabase
    )
  }

  private func target(
    subscription: TrackedSubscription,
    url: String,
    isCurrent: Bool = true
  ) -> ProfileQuotaTarget {
    ProfileQuotaTarget(
      subscription: subscription,
      profileUID: subscription.identity.clashProfileUID ?? "",
      subscriptionURL: URL(string: url),
      isCurrent: isCurrent,
      availability: .available
    )
  }

  private func replacing(
    _ subscription: TrackedSubscription,
    name: String,
    fingerprint: String?,
    updatedAt: Date
  ) throws -> TrackedSubscription {
    try TrackedSubscription(
      id: subscription.id,
      name: name,
      identity: subscription.identity,
      urlFingerprint: fingerprint,
      refreshIntervalMinutes: subscription.refreshIntervalMinutes,
      status: subscription.status,
      createdAt: subscription.createdAt,
      updatedAt: updatedAt
    )
  }

  private func runtimeConfiguration(mixedPort: Int?) -> MihomoRuntimeConfiguration {
    MihomoRuntimeConfiguration(
      mode: nil,
      tun: nil,
      isIPv6Enabled: nil,
      allowsLAN: nil,
      mixedPort: mixedPort
    )
  }

  private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping () async -> Bool
  ) async throws {
    var elapsed: UInt64 = 0
    while !(await condition()), elapsed < timeoutNanoseconds {
      try await Task.sleep(nanoseconds: 10_000_000)
      elapsed += 10_000_000
    }
    let didFinish = await condition()
    XCTAssertTrue(didFinish, "等待 Profile 配额状态变化超时")
  }
}

private actor TestActiveQuotaQueryClient: ActiveQuotaQuerying {
  private let responses: [Result<ActiveQuotaQueryResult, ActiveQuotaQueryError>]
  private(set) var queryCount = 0
  private(set) var maximumConcurrentQueries = 0
  private var userAgents: [String] = []
  private var concurrentQueries = 0

  init(responses: [Result<ActiveQuotaQueryResult, ActiveQuotaQueryError>]) {
    self.responses = responses
  }

  func metrics() -> (queryCount: Int, maximumConcurrentQueries: Int, userAgents: [String]) {
    (queryCount, maximumConcurrentQueries, userAgents)
  }

  func query(
    subscriptionURL: URL,
    via proxy: MihomoLocalProxy,
    userAgent: String
  ) async throws -> ActiveQuotaQueryResult {
    concurrentQueries += 1
    maximumConcurrentQueries = max(maximumConcurrentQueries, concurrentQueries)
    defer { concurrentQueries -= 1 }
    let index = queryCount
    queryCount += 1
    userAgents.append(userAgent)
    try await Task.sleep(nanoseconds: 10_000_000)
    guard responses.indices.contains(index) else {
      throw ActiveQuotaQueryError.transport
    }
    return try responses[index].get()
  }
}

private actor TestProfileQuotaDiagnosticLogger: AppDiagnosticLogging {
  private var events: [AppDiagnosticEvent] = []

  func record(_ event: AppDiagnosticEvent) {
    events.append(event)
  }

  func messages() -> [String] {
    events.map(\.logMessage)
  }
}

@MainActor
private struct ProfileQuotaTestContext {
  let database: URL
  let ledger: SQLiteQuotaLedger
  let queryClient: TestActiveQuotaQueryClient
  let diagnosticLogger: TestProfileQuotaDiagnosticLogger
  let controller: ProfileQuotaTrackingController
  let subscription: TrackedSubscription
  let target: ProfileQuotaTarget
  let now: Date
  let removeDatabase: (URL) -> Void

  func connectProxy(globalUserAgent: String? = nil) {
    controller.controllerValidated(
      endpoint: try! ControllerEndpoint(address: "127.0.0.1:9090"),
      runtimeConfiguration: MihomoRuntimeConfiguration(
        mode: nil,
        tun: nil,
        isIPv6Enabled: nil,
        allowsLAN: nil,
        mixedPort: 7_890,
        globalUserAgent: globalUserAgent
      )
    )
  }

  func stop() {
    controller.stop()
    removeDatabase(database)
  }
}
