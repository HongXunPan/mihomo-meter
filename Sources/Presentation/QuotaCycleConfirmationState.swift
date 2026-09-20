import Combine

@MainActor
final class QuotaCycleConfirmationState: ObservableObject {
  @Published private(set) var isConfirming = false
  @Published private(set) var errorMessage: String?

  func confirm(using operation: @MainActor () async -> String?) async {
    guard !isConfirming else {
      return
    }
    isConfirming = true
    errorMessage = nil
    defer { isConfirming = false }

    if let message = await operation() {
      errorMessage = "确认失败：\(message)"
    }
  }
}
