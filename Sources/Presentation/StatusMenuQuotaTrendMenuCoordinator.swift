import AppKit
import SwiftUI

@MainActor
final class StatusMenuQuotaTrendMenuCoordinator {
  let contentViewController: NSHostingController<StatusMenuQuotaTrendView>

  private let controller: RuntimeQuotaTrackingController
  private let profileQuotaController: ProfileQuotaTrackingController
  private let state: StatusMenuQuotaTrendState

  init(
    controller: RuntimeQuotaTrackingController,
    profileQuotaController: ProfileQuotaTrackingController,
    now: @escaping @MainActor () -> Date = Date.init
  ) {
    self.controller = controller
    self.profileQuotaController = profileQuotaController

    let state = StatusMenuQuotaTrendState(now: now)
    self.state = state
    contentViewController = NSHostingController(
      rootView: StatusMenuQuotaTrendView(
        controller: controller,
        profileQuotaController: profileQuotaController,
        state: state
      )
    )
    contentViewController.sizingOptions = []
    contentViewController.preferredContentSize = StatusMenuLayout.quotaTrendSubmenuSize

    prepareForPresentation()
  }

  func prepareForPresentation() {
    let targets = StatusMenuQuotaTrendTarget.available(
      controller: controller,
      profileQuotaController: profileQuotaController
    )
    state.prepareForPresentation(
      targetIDs: targets.map(\.id),
      defaultTargetID: targets.first(where: \.isCurrent)?.id ?? targets.first?.id
    )
  }
}

@MainActor
final class StatusMenuQuotaTrendState: ObservableObject {
  @Published private(set) var selectedTargetID: UUID?
  @Published private(set) var window = QuotaTrendWindow.day
  @Published private(set) var referenceDate: Date

  private let now: @MainActor () -> Date
  private var lastDefaultTargetID: UUID?

  init(now: @escaping @MainActor () -> Date = Date.init) {
    self.now = now
    referenceDate = now()
  }

  func prepareForPresentation(
    targetIDs: [UUID],
    defaultTargetID: UUID?
  ) {
    referenceDate = now()

    guard !targetIDs.isEmpty else {
      selectedTargetID = nil
      lastDefaultTargetID = nil
      return
    }

    let resolvedDefaultID = defaultTargetID ?? targetIDs[0]
    if resolvedDefaultID != lastDefaultTargetID {
      selectedTargetID = resolvedDefaultID
      lastDefaultTargetID = resolvedDefaultID
      return
    }
    if let selectedTargetID, targetIDs.contains(selectedTargetID) {
      return
    }
    selectedTargetID = resolvedDefaultID
  }

  func selectPrevious(targetIDs: [UUID]) {
    selectAdjacentTarget(offset: -1, targetIDs: targetIDs)
  }

  func selectNext(targetIDs: [UUID]) {
    selectAdjacentTarget(offset: 1, targetIDs: targetIDs)
  }

  func selectWindow(_ window: QuotaTrendWindow) {
    guard StatusMenuQuotaMetricsView.supportedWindows.contains(window), self.window != window else {
      return
    }
    self.window = window
  }

  private func selectAdjacentTarget(offset: Int, targetIDs: [UUID]) {
    guard targetIDs.count > 1 else {
      return
    }
    let currentIndex = selectedTargetID.flatMap(targetIDs.firstIndex(of:)) ?? 0
    let nextIndex = (currentIndex + offset + targetIDs.count) % targetIDs.count
    selectedTargetID = targetIDs[nextIndex]
  }
}
