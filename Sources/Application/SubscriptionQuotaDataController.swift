import Combine
import Foundation

@MainActor
final class SubscriptionQuotaDataController: ObservableObject {
  @Published private(set) var isClearing = false
  @Published private(set) var operationMessage: String?

  private let ledger: any QuotaLedgerStoring
  private unowned let runtimeController: RuntimeQuotaTrackingController
  private unowned let profileQuotaController: ProfileQuotaTrackingController
  private unowned let profileDirectoryController: ClashProfileDirectoryController

  init(
    ledger: any QuotaLedgerStoring,
    runtimeController: RuntimeQuotaTrackingController,
    profileQuotaController: ProfileQuotaTrackingController,
    profileDirectoryController: ClashProfileDirectoryController
  ) {
    self.ledger = ledger
    self.runtimeController = runtimeController
    self.profileQuotaController = profileQuotaController
    self.profileDirectoryController = profileDirectoryController
  }

  func clear() async {
    guard !isClearing else {
      return
    }
    isClearing = true
    operationMessage = nil
    runtimeController.prepareForDataReset()
    await profileQuotaController.prepareForDataReset()

    do {
      try await ledger.reset()
      runtimeController.completeDataReset()
      profileDirectoryController.resetTrackingAfterQuotaClear()
    } catch {
      operationMessage = error.localizedDescription
      runtimeController.cancelDataReset()
      profileDirectoryController.republishTrackingTargets()
    }

    profileQuotaController.resumeAfterDataReset()
    isClearing = false
  }
}
