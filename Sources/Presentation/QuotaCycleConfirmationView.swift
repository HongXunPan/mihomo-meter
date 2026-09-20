import SwiftUI

struct QuotaCycleConfirmationView: View {
  let cycle: QuotaCycle
  let subscriptionName: String
  var isCompact = false
  let confirmCurrentCycle: @MainActor (UUID) async -> String?

  @StateObject private var state = QuotaCycleConfirmationState()

  var body: some View {
    HStack(spacing: 8) {
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(
          state.errorMessage == nil
            ? MihomoColorToken.statusWarning : MihomoColorToken.statusDanger
        )
        .lineLimit(isCompact ? 2 : nil)
        .fixedSize(horizontal: false, vertical: true)
        .help(message)

      Spacer(minLength: 0)

      Button(buttonTitle) {
        Task {
          await state.confirm {
            await confirmCurrentCycle(cycle.id)
          }
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .fixedSize()
      .disabled(state.isConfirming)
      .accessibilityLabel("\(buttonTitle)：\(subscriptionName)")
      .help("仅确认本次用量重置，不会查询机场或更改套餐。")
    }
    .font(.caption)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var message: String {
    state.errorMessage ?? "检测到用量下降，需确认新周期"
  }

  private var buttonTitle: String {
    if state.isConfirming {
      return "确认中…"
    }
    return state.errorMessage == nil ? "确认新周期" : "重试确认"
  }
}
