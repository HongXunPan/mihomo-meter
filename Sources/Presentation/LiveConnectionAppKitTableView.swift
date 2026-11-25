import AppKit
import Dispatch
import SwiftUI

@MainActor
struct LiveConnectionAppKitTableView: NSViewRepresentable {
  private typealias Column = LiveConnectionTableColumn

  let connections: [LiveTrafficConnection]
  let sortResetGeneration: Int

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSScrollView {
    let tableView = NSTableView()
    tableView.usesAutomaticRowHeights = false
    tableView.rowHeight = 26
    tableView.intercellSpacing = NSSize(width: 0, height: 2)
    tableView.columnAutoresizingStyle = .noColumnAutoresizing
    tableView.allowsColumnReordering = false
    tableView.usesAlternatingRowBackgroundColors = true
    tableView.backgroundColor = .clear
    tableView.dataSource = context.coordinator
    tableView.delegate = context.coordinator

    for column in Column.allCases {
      let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
      tableColumn.title = column.title
      tableColumn.minWidth = column.minimumWidth
      tableColumn.width = column.width
      tableColumn.maxWidth = column.maximumWidth
      tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: false)
      tableView.addTableColumn(tableColumn)
    }

    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.documentView = tableView
    #if DEBUG
      if context.coordinator.measuresPerformance {
        LiveConnectionTablePerformanceRecorder.shared.recordMount()
      }
    #endif
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let tableView = scrollView.documentView as? NSTableView else {
      return
    }
    #if DEBUG
      if LiveConnectionTableFreezeExperiment.shared.shouldSkipUpdate(
        hasExistingRows: context.coordinator.numberOfRows(in: tableView) > 0
      ) {
        LiveConnectionTablePerformanceRecorder.shared.recordSkippedUpdate()
        return
      }
    #endif
    context.coordinator.update(
      connections,
      sortResetGeneration: sortResetGeneration,
      in: tableView
    )
  }

  #if DEBUG
    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
      if coordinator.measuresPerformance {
        LiveConnectionTablePerformanceRecorder.shared.recordUnmount()
      }
    }
  #endif

  @MainActor
  final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    #if DEBUG
      let measuresPerformance =
        ProcessInfo.processInfo.environment[ProcessPerformanceDiagnostics.enabledKey] == "1"
      let usesIncrementalUpdates = LiveConnectionTableRowUpdatePlan.isEnabled
    #endif
    private var connections: [LiveTrafficConnection] = []
    private var sourceConnections: [LiveTrafficConnection] = []
    private var appliedSortResetGeneration: Int?
    private var isResettingSort = false
    private var renderedSecond = -1

    func numberOfRows(in tableView: NSTableView) -> Int {
      connections.count
    }

    func tableView(
      _ tableView: NSTableView,
      viewFor tableColumn: NSTableColumn?,
      row: Int
    ) -> NSView? {
      guard
        connections.indices.contains(row),
        let tableColumn,
        let column = Column(rawValue: tableColumn.identifier.rawValue)
      else {
        return nil
      }

      let cell = makeCell(in: tableView, for: column)
      configure(cell, with: connections[row], column: column, now: Date())
      #if DEBUG
        if measuresPerformance {
          LiveConnectionTablePerformanceRecorder.shared.recordCellConfiguration()
        }
      #endif
      return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
      false
    }

    func tableView(
      _ tableView: NSTableView,
      sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]
    ) {
      guard !isResettingSort else {
        return
      }
      applySourceConnections(in: tableView)
    }

    func update(
      _ newConnections: [LiveTrafficConnection],
      sortResetGeneration: Int,
      in tableView: NSTableView
    ) {
      sourceConnections = newConnections
      if appliedSortResetGeneration != sortResetGeneration {
        appliedSortResetGeneration = sortResetGeneration
        if !tableView.sortDescriptors.isEmpty {
          isResettingSort = true
          tableView.sortDescriptors = []
          isResettingSort = false
        }
      }
      applySourceConnections(in: tableView)
    }

    private func applySourceConnections(in tableView: NSTableView) {
      let descriptor = tableView.sortDescriptors.first
      let column = descriptor?.key.flatMap(Column.init(rawValue:))
      let newConnections = LiveConnectionTableSorting.connections(
        sourceConnections,
        column: column,
        ascending: descriptor?.ascending ?? false
      )
      #if DEBUG
        let startedAt = measuresPerformance ? DispatchTime.now().uptimeNanoseconds : nil
      #endif
      let hasSameOrder =
        connections.count == newConnections.count
        && zip(connections, newConnections).allSatisfy { $0.0.id == $0.1.id }
      #if DEBUG
        let incrementalPlan =
          usesIncrementalUpdates && !hasSameOrder && tableView.numberOfRows == connections.count
          ? LiveConnectionTableRowUpdatePlan(
            previousIDs: connections.map(\.id),
            nextIDs: newConnections.map(\.id)
          ) : nil
        var didReload = false
        defer {
          if let startedAt {
            LiveConnectionTablePerformanceRecorder.shared.recordUpdate(
              rowCount: newConnections.count,
              didReload: didReload,
              elapsedNanoseconds: DispatchTime.now().uptimeNanoseconds - startedAt
            )
          }
        }
      #endif
      let hasChanged = connections != newConnections
      let now = Date()
      let second = Int(now.timeIntervalSince1970)
      connections = newConnections

      if !hasSameOrder {
        renderedSecond = second
        #if DEBUG
          if let incrementalPlan {
            incrementalPlan.apply(to: tableView)
            if measuresPerformance {
              LiveConnectionTablePerformanceRecorder.shared.recordIncrementalBatch(
                moveCount: incrementalPlan.moves.count,
                insertionCount: incrementalPlan.insertions.count,
                removalCount: incrementalPlan.removals.count
              )
            }
            updateVisibleCells(in: tableView, allColumns: true, now: now)
            return
          }
          didReload = true
        #endif
        tableView.reloadData()
        return
      }

      guard hasChanged || renderedSecond != second else {
        return
      }
      renderedSecond = second
      updateVisibleCells(in: tableView, allColumns: hasChanged, now: now)
    }

    private func updateVisibleCells(in tableView: NSTableView, allColumns: Bool, now: Date) {
      let visibleRows = tableView.rows(in: tableView.visibleRect)
      guard visibleRows.length > 0 else {
        return
      }

      #if DEBUG
        var updatedCellCount = 0
      #endif
      for row in visibleRows.location..<(visibleRows.location + visibleRows.length)
      where connections.indices.contains(row) {
        for (columnIndex, column) in Column.allCases.enumerated()
        where allColumns || column == .duration {
          guard
            let cell = tableView.view(
              atColumn: columnIndex,
              row: row,
              makeIfNecessary: false
            ) as? NSTableCellView
          else {
            continue
          }
          configure(cell, with: connections[row], column: column, now: now)
          #if DEBUG
            if measuresPerformance {
              updatedCellCount += 1
            }
          #endif
        }
      }
      #if DEBUG
        if measuresPerformance {
          LiveConnectionTablePerformanceRecorder.shared.recordVisibleCellUpdates(updatedCellCount)
        }
      #endif
    }

    private func makeCell(in tableView: NSTableView, for column: Column) -> NSTableCellView {
      let identifier = NSUserInterfaceItemIdentifier(column.rawValue)
      if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
        return cell
      }

      let cell = NSTableCellView()
      cell.identifier = identifier
      let label = NSTextField(labelWithString: "")
      label.translatesAutoresizingMaskIntoConstraints = false
      label.maximumNumberOfLines = 1
      label.cell?.lineBreakMode = column.isNumeric ? .byTruncatingTail : .byTruncatingMiddle
      cell.textField = label
      cell.addSubview(label)
      NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
        label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
        label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
      ])
      return cell
    }

    private func configure(
      _ cell: NSTableCellView,
      with connection: LiveTrafficConnection,
      column: Column,
      now: Date
    ) {
      guard let label = cell.textField else {
        return
      }
      let value = column.text(for: connection, now: now)
      label.stringValue = value
      label.toolTip = column.isNumeric ? nil : value
      label.alignment = column.isNumeric ? .right : .left
      label.font =
        column.isNumeric
        ? .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        : .systemFont(ofSize: NSFont.systemFontSize)
      label.textColor = column.textColor
    }
  }

}
