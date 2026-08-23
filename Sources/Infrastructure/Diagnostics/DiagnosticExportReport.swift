import Foundation

struct DiagnosticExportEvent: Encodable, Equatable, Sendable {
  let timestamp: Date
  let category: String
  let outcome: String?
  let source: String?
  let status: String?
  let trigger: String?
  let reason: String?
  let format: String?
  let operation: String?
  let proxyKind: String?
  let userAgentSource: String?
  let statusCode: Int?
  let httpStatus: Int?
  let networkCode: Int?
  let elapsedMilliseconds: Int?
  let timeoutSeconds: Int?
  let reconnectAfterSeconds: Int?
  let lastSnapshotAgeMilliseconds: Int?
  let delaySeconds: Int?
  let attemptNumber: Int?
  let retryAfterSeconds: Int?
  let isCurrentProfile: Bool?

  init(
    timestamp: Date,
    category: String,
    outcome: String? = nil,
    source: String? = nil,
    status: String? = nil,
    trigger: String? = nil,
    reason: String? = nil,
    format: String? = nil,
    operation: String? = nil,
    proxyKind: String? = nil,
    userAgentSource: String? = nil,
    statusCode: Int? = nil,
    httpStatus: Int? = nil,
    networkCode: Int? = nil,
    elapsedMilliseconds: Int? = nil,
    timeoutSeconds: Int? = nil,
    reconnectAfterSeconds: Int? = nil,
    lastSnapshotAgeMilliseconds: Int? = nil,
    delaySeconds: Int? = nil,
    attemptNumber: Int? = nil,
    retryAfterSeconds: Int? = nil,
    isCurrentProfile: Bool? = nil
  ) {
    self.timestamp = timestamp
    self.category = category
    self.outcome = outcome
    self.source = source
    self.status = status
    self.trigger = trigger
    self.reason = reason
    self.format = format
    self.operation = operation
    self.proxyKind = proxyKind
    self.userAgentSource = userAgentSource
    self.statusCode = statusCode
    self.httpStatus = httpStatus
    self.networkCode = networkCode
    self.elapsedMilliseconds = elapsedMilliseconds
    self.timeoutSeconds = timeoutSeconds
    self.reconnectAfterSeconds = reconnectAfterSeconds
    self.lastSnapshotAgeMilliseconds = lastSnapshotAgeMilliseconds
    self.delaySeconds = delaySeconds
    self.attemptNumber = attemptNumber
    self.retryAfterSeconds = retryAfterSeconds
    self.isCurrentProfile = isCurrentProfile
  }
}

struct DiagnosticExportEnvironment: Encodable, Equatable, Sendable {
  let platform: String
  let version: String
  let build: String
  let operatingSystem: String
  let architecture: String
}

struct DiagnosticExportReport: Encodable, Equatable, Sendable {
  static let schemaVersion = 1
  static let maximumEventCount = 200

  let schemaVersion: Int
  let generatedAt: Date
  let application: DiagnosticExportEnvironment
  let runtime: Runtime
  let events: [DiagnosticExportEvent]

  struct Runtime: Encodable, Equatable, Sendable {
    let connectionState: String
  }

  init(
    generatedAt: Date,
    application: DiagnosticExportEnvironment,
    connectionState: String,
    events: [DiagnosticExportEvent]
  ) {
    schemaVersion = Self.schemaVersion
    self.generatedAt = generatedAt
    self.application = application
    runtime = Runtime(connectionState: connectionState)
    self.events = Array(events.suffix(Self.maximumEventCount))
  }

  func encodedData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }
}
