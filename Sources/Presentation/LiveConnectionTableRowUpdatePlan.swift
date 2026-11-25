import AppKit

struct LiveConnectionTableRowUpdatePlan {
  struct Move: Equatable {
    let from: Int
    let to: Int
  }

  let removals: IndexSet
  let insertions: IndexSet
  let moves: [Move]

  init?(previousIDs: [String], nextIDs: [String]) {
    let previousSet = Set(previousIDs)
    let nextSet = Set(nextIDs)
    guard previousSet.count == previousIDs.count, nextSet.count == nextIDs.count else {
      return nil
    }

    var removals = IndexSet()
    for (index, id) in previousIDs.enumerated() where !nextSet.contains(id) {
      removals.insert(index)
    }
    var insertions = IndexSet()
    for (index, id) in nextIDs.enumerated() where !previousSet.contains(id) {
      insertions.insert(index)
    }

    var intermediate = previousIDs.filter(nextSet.contains)
    for index in insertions {
      intermediate.insert(nextIDs[index], at: index)
    }
    guard
      let forward = Self.moves(from: intermediate, to: nextIDs, reversed: false),
      let backward = Self.moves(from: intermediate, to: nextIDs, reversed: true)
    else {
      return nil
    }

    self.removals = removals
    self.insertions = insertions
    moves = forward.count <= backward.count ? forward : backward
  }

  @MainActor
  func apply(to tableView: NSTableView) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0
      context.allowsImplicitAnimation = false
      tableView.beginUpdates()
      if !removals.isEmpty {
        tableView.removeRows(at: removals, withAnimation: [])
      }
      if !insertions.isEmpty {
        tableView.insertRows(at: insertions, withAnimation: [])
      }
      for move in moves {
        tableView.moveRow(at: move.from, to: move.to)
      }
      tableView.endUpdates()
    }
  }

  private static func moves(from initial: [String], to target: [String], reversed: Bool)
    -> [Move]?
  {
    var current = initial
    var result: [Move] = []
    let indexes = reversed ? Array(target.indices.reversed()) : Array(target.indices)
    for destination in indexes where current[destination] != target[destination] {
      guard let source = current.firstIndex(of: target[destination]) else {
        return nil
      }
      let id = current.remove(at: source)
      current.insert(id, at: destination)
      result.append(Move(from: source, to: destination))
    }
    return current == target ? result : nil
  }
}
