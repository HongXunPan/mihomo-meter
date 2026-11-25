import Foundation

enum LiveConnectionTableSorting {
  static func connections(
    _ source: [LiveTrafficConnection],
    column: LiveConnectionTableColumn?,
    ascending: Bool
  ) -> [LiveTrafficConnection] {
    guard let column else {
      return source
    }

    return source.sorted { left, right in
      switch column {
      case .hostname:
        return precedes(
          left.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname,
          right.metadata.hostname ?? ConnectionAttributionLabel.unknownHostname,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .application:
        return precedes(
          left.metadata.applicationName ?? ConnectionAttributionLabel.unknownApplication,
          right.metadata.applicationName ?? ConnectionAttributionLabel.unknownApplication,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .download:
        return precedes(
          left.rate.downloadBytesPerSecond,
          right.rate.downloadBytesPerSecond,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .upload:
        return precedes(
          left.rate.uploadBytesPerSecond,
          right.rate.uploadBytesPerSecond,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .cumulative:
        return precedes(
          left.cumulativeBytes.total,
          right.cumulativeBytes.total,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .duration:
        switch (left.startedAt, right.startedAt) {
        case (nil, nil): return left.id < right.id
        case (nil, _): return false
        case (_, nil): return true
        case (let leftStart?, let rightStart?):
          return precedes(
            leftStart,
            rightStart,
            ascending: !ascending,
            leftID: left.id,
            rightID: right.id
          )
        }
      }
    }
  }

  static func groups(
    _ source: [LiveConnectionGroupRow],
    column: LiveConnectionGroupTableColumn?,
    ascending: Bool
  ) -> [LiveConnectionGroupRow] {
    guard let column else {
      return source
    }
    return source.sorted { left, right in
      switch column {
      case .name:
        return precedes(
          left.name,
          right.name,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .relatedCount:
        return precedes(
          left.relatedCount,
          right.relatedCount,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .connectionCount:
        return precedes(
          left.connectionCount,
          right.connectionCount,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .download:
        return precedes(
          left.rate.downloadBytesPerSecond,
          right.rate.downloadBytesPerSecond,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .upload:
        return precedes(
          left.rate.uploadBytesPerSecond,
          right.rate.uploadBytesPerSecond,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      case .cumulative:
        return precedes(
          left.cumulativeBytes.total,
          right.cumulativeBytes.total,
          ascending: ascending,
          leftID: left.id,
          rightID: right.id
        )
      }
    }
  }

  private static func precedes(
    _ left: String,
    _ right: String,
    ascending: Bool,
    leftID: String,
    rightID: String
  ) -> Bool {
    let result = left.localizedStandardCompare(right)
    return result == .orderedSame
      ? leftID < rightID
      : result == (ascending ? .orderedAscending : .orderedDescending)
  }

  private static func precedes<Value: Comparable>(
    _ left: Value,
    _ right: Value,
    ascending: Bool,
    leftID: String,
    rightID: String
  ) -> Bool {
    return left == right ? leftID < rightID : (ascending ? left < right : left > right)
  }
}
