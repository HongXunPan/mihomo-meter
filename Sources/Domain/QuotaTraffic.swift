import Foundation

struct QuotaTraffic: Equatable, Sendable {
  let uploadBytes: UInt64
  let downloadBytes: UInt64
  let totalBytes: UInt64
  let usedBytes: UInt64
  let remainingBytes: UInt64

  init(
    uploadBytes: UInt64,
    downloadBytes: UInt64,
    totalBytes: UInt64
  ) throws {
    guard totalBytes > 0 else {
      throw QuotaLedgerError.invalidTotal
    }
    let (usedBytes, overflow) = uploadBytes.addingReportingOverflow(downloadBytes)
    guard
      !overflow,
      uploadBytes <= UInt64(Int64.max),
      downloadBytes <= UInt64(Int64.max),
      totalBytes <= UInt64(Int64.max),
      usedBytes <= UInt64(Int64.max)
    else {
      throw QuotaLedgerError.byteCountOverflow
    }

    self.uploadBytes = uploadBytes
    self.downloadBytes = downloadBytes
    self.totalBytes = totalBytes
    self.usedBytes = usedBytes
    remainingBytes = totalBytes > usedBytes ? totalBytes - usedBytes : 0
  }

  var isOverQuota: Bool {
    usedBytes > totalBytes
  }
}
