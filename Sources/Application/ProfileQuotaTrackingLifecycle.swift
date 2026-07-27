import Foundation

struct ProfileQuotaTarget: Equatable, Sendable {
  let subscription: TrackedSubscription
  let profileUID: String
  let subscriptionURL: URL?
  let isCurrent: Bool
  let availability: ClashProfileAvailability
}

struct ProfileQuotaTargetBuilder {
  func build(
    catalog: ClashProfileCatalog?,
    subscriptions: [TrackedSubscription]
  ) -> [ProfileQuotaTarget] {
    let profilesByUID = Dictionary(
      uniqueKeysWithValues: (catalog?.profiles ?? []).map { ($0.uid, $0) }
    )
    return subscriptions.compactMap { subscription in
      guard
        let profileUID = subscription.identity.clashProfileUID,
        subscription.status != .archived
      else {
        return nil
      }
      let profile = profilesByUID[profileUID]
      let availability = availability(for: profile)
      return ProfileQuotaTarget(
        subscription: subscription,
        profileUID: profileUID,
        subscriptionURL: availability == .available ? profile?.subscriptionURL : nil,
        isCurrent: catalog?.currentUID == profileUID,
        availability: availability
      )
    }
    .sorted(by: shouldSortBefore)
  }

  private func availability(for profile: ClashProfile?) -> ClashProfileAvailability {
    guard let profile else {
      return .missing
    }
    return profile.supportsActiveQuery ? .available : .unsupportedURL
  }

  private func shouldSortBefore(_ left: ProfileQuotaTarget, _ right: ProfileQuotaTarget) -> Bool {
    if left.isCurrent != right.isCurrent {
      return left.isCurrent
    }
    return left.subscription.name.localizedStandardCompare(right.subscription.name)
      == .orderedAscending
  }
}

@MainActor
protocol ProfileQuotaTrackingLifecycle: AnyObject {
  func updateTargets(_ targets: [ProfileQuotaTarget])
  func controllerValidated(
    endpoint: ControllerEndpoint,
    runtimeConfiguration: MihomoRuntimeConfiguration
  )
  func controllerUnavailable()
}

@MainActor
final class NoOpProfileQuotaTrackingLifecycle: ProfileQuotaTrackingLifecycle {
  static let shared = NoOpProfileQuotaTrackingLifecycle()

  private init() {}

  func updateTargets(_ targets: [ProfileQuotaTarget]) {}

  func controllerValidated(
    endpoint: ControllerEndpoint,
    runtimeConfiguration: MihomoRuntimeConfiguration
  ) {}

  func controllerUnavailable() {}
}
