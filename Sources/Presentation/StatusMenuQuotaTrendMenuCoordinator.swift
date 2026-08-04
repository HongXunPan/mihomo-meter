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

  let hoverState = StatusMenuQuotaTrendHoverState()
  private(set) var hoverContext: StatusMenuQuotaTrendHoverContext?

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
    defer { synchronizeHoverContext() }

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
    synchronizeHoverContext()
  }

  private func selectAdjacentTarget(offset: Int, targetIDs: [UUID]) {
    guard targetIDs.count > 1 else {
      return
    }
    let currentIndex = selectedTargetID.flatMap(targetIDs.firstIndex(of:)) ?? 0
    let nextIndex = (currentIndex + offset + targetIDs.count) % targetIDs.count
    selectedTargetID = targetIDs[nextIndex]
    synchronizeHoverContext()
  }

  private func synchronizeHoverContext() {
    guard let selectedTargetID else {
      hoverContext = nil
      hoverState.deactivate()
      return
    }
    hoverContext = hoverState.activate(
      targetID: selectedTargetID,
      window: window
    )
  }
}

struct StatusMenuQuotaTrendHoverContext: Equatable {
  let targetID: UUID
  let window: QuotaTrendWindow
  let generation: UInt64
}

@MainActor
final class StatusMenuQuotaTrendHoverState: ObservableObject {
  @Published private(set) var selectedPointID: UUID?

  private var activeContext: StatusMenuQuotaTrendHoverContext?
  private var generation: UInt64 = 0

  func activate(
    targetID: UUID,
    window: QuotaTrendWindow
  ) -> StatusMenuQuotaTrendHoverContext {
    generation &+= 1
    let context = StatusMenuQuotaTrendHoverContext(
      targetID: targetID,
      window: window,
      generation: generation
    )
    activeContext = context
    updateSelectedPoint(nil)
    return context
  }

  func deactivate() {
    generation &+= 1
    activeContext = nil
    updateSelectedPoint(nil)
  }

  func select(
    _ pointID: UUID?,
    in context: StatusMenuQuotaTrendHoverContext
  ) {
    guard context == activeContext else {
      return
    }
    updateSelectedPoint(pointID)
  }

  private func updateSelectedPoint(_ pointID: UUID?) {
    guard selectedPointID != pointID else {
      return
    }
    selectedPointID = pointID
  }
}
