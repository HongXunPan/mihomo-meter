import Foundation

struct QuotaUsageChartSlot: Identifiable, Equatable {
  let index: Int
  let interval: DateInterval
  let bar: QuotaUsageBar?

  var id: Int {
    index
  }
}

struct QuotaUsageChartAxis: Equatable {
  let aggregation: QuotaUsageAggregation
  let slots: [QuotaUsageChartSlot]

  init(
    series: QuotaUsageSeries,
    calendar: Calendar = .autoupdatingCurrent
  ) {
    aggregation = series.resolvedAggregation
    var barsByID: [QuotaUsagePeriodID: QuotaUsageBar] = [:]
    for bar in series.bars {
      barsByID[bar.id] = bar
    }
    slots = QuotaUsageAggregator.bucketIntervals(
      rangeStart: series.rangeStart,
      rangeEnd: series.rangeEnd,
      aggregation: series.resolvedAggregation,
      calendar: calendar
    ).enumerated().map { index, interval in
      let periodID = QuotaUsagePeriodID(
        startAt: interval.start,
        endAt: interval.end
      )
      return QuotaUsageChartSlot(
        index: index,
        interval: interval,
        bar: barsByID[periodID]
      )
    }
  }

  var domain: ClosedRange<Double> {
    let upperBound = Double(max(slots.count - 1, 0)) + 0.5
    return -0.5...upperBound
  }

  var tickValues: [Double] {
    guard slots.count > 1 else {
      return slots.isEmpty ? [] : [0]
    }
    let lastIndex = slots.count - 1
    let step = max(Int(ceil(Double(lastIndex) / 4)), 1)
    var values = Array(stride(from: 0, through: lastIndex, by: step))
    if values.last != lastIndex {
      values.append(lastIndex)
    }
    return values.map(Double.init)
  }

  func slot(at index: Int) -> QuotaUsageChartSlot? {
    guard slots.indices.contains(index) else {
      return nil
    }
    return slots[index]
  }

  func nearestSlot(to value: Double) -> QuotaUsageChartSlot? {
    slot(at: Int(value.rounded()))
  }
}
