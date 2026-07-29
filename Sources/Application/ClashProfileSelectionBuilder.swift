import Foundation

struct ClashProfileSelectionBuilder {
  func build(
    catalog: ClashProfileCatalog?,
    subscriptions: [TrackedSubscription]
  ) -> [ClashProfileSelectionItem] {
    let subscriptionsByUID = subscriptions.reduce(into: [String: TrackedSubscription]()) {
      result, subscription in
      if let uid = subscription.identity.clashProfileUID {
        result[uid] = subscription
      }
    }
    var rows = (catalog?.profiles ?? []).map { profile in
      selectionItem(
        profile: profile,
        currentUID: catalog?.currentUID,
        subscription: subscriptionsByUID[profile.uid]
      )
    }

    let visibleUIDs = Set(rows.map(\.uid))
    rows.append(
      contentsOf: missingSelectionItems(
        subscriptions: subscriptions,
        visibleUIDs: visibleUIDs
      )
    )
    return rows.sorted(by: shouldSortBefore)
  }

  private func selectionItem(
    profile: ClashProfile,
    currentUID: String?,
    subscription: TrackedSubscription?
  ) -> ClashProfileSelectionItem {
    ClashProfileSelectionItem(
      uid: profile.uid,
      name: profile.name,
      subscriptionDomain: profile.subscriptionDomain,
      isCurrent: profile.uid == currentUID,
      isSelected: subscription.map { $0.status != .archived } ?? false,
      refreshIntervalMinutes: subscription?.refreshIntervalMinutes,
      availability: profile.supportsActiveQuery ? .available : .unsupportedURL
    )
  }

  private func missingSelectionItems(
    subscriptions: [TrackedSubscription],
    visibleUIDs: Set<String>
  ) -> [ClashProfileSelectionItem] {
    subscriptions.compactMap { subscription in
      guard
        let uid = subscription.identity.clashProfileUID,
        !visibleUIDs.contains(uid),
        subscription.status != .archived
      else {
        return nil
      }
      return ClashProfileSelectionItem(
        uid: uid,
        name: subscription.name,
        subscriptionDomain: nil,
        isCurrent: false,
        isSelected: true,
        refreshIntervalMinutes: subscription.refreshIntervalMinutes,
        availability: .missing
      )
    }
  }

  private func shouldSortBefore(
    _ left: ClashProfileSelectionItem,
    _ right: ClashProfileSelectionItem
  ) -> Bool {
    if left.isCurrent != right.isCurrent {
      return left.isCurrent
    }
    if left.isSelected != right.isSelected {
      return left.isSelected
    }
    return left.name.localizedStandardCompare(right.name) == .orderedAscending
  }
}
