import SwiftUI

struct QuotaTrendRangeControl: View {
  @Binding var window: QuotaTrendWindow

  var body: some View {
    HStack(spacing: 10) {
      Text("范围")
        .font(.caption)
        .foregroundStyle(.secondary)

      Picker("趋势窗口", selection: $window) {
        Text("24 小时").tag(QuotaTrendWindow.day)
        Text("7 天").tag(QuotaTrendWindow.week)
        Text("30 天").tag(QuotaTrendWindow.month)
        Text("12 月").tag(QuotaTrendWindow.year)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 320)

      Spacer()
    }
  }
}

struct QuotaTrendAggregationControl: View {
  @Binding var aggregation: QuotaUsageAggregation
  let availableAggregations: Set<QuotaUsageAggregation>

  var body: some View {
    HStack(spacing: 10) {

      Text("粒度")
        .font(.caption)
        .foregroundStyle(.secondary)

      Picker("聚合粒度", selection: $aggregation) {
        ForEach(QuotaUsageAggregation.selectableCases, id: \.self) { option in
          Text(optionTitle(option))
            .tag(option)
            .disabled(!availableAggregations.contains(option))
        }
      }
      .pickerStyle(.menu)
      .frame(width: 90)
    }
  }

  private func optionTitle(_ option: QuotaUsageAggregation) -> String {
    availableAggregations.contains(option) ? option.title : "\(option.title)（数据不足）"
  }
}
