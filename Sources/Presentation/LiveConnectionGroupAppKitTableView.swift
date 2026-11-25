import AppKit
import SwiftUI

@MainActor
struct LiveConnectionGroupAppKitTableView: NSViewRepresentable {
  private typealias Column = LiveConnectionGroupTableColumn

  let mode: LiveConnectionViewMode
  let rows: [LiveConnectionGroupRow]
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

    for column in Column.allCases {
      let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
      tableColumn.title = column.title(for: mode)
      tableColumn.minWidth = column.minimumWidth
      tableColumn.width = column.width
      tableColumn.maxWidth = column.maximumWidth
      tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: false)
      tableView.addTableColumn(tableColumn)
    }
    tableView.dataSource = context.coordinator
    tableView.delegate = context.coordinator

    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.documentView = tableView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let tableView = scrollView.documentView as? NSTableView else {
      return
    }
    context.coordinator.update(
      rows,
      sortResetGeneration: sortResetGeneration,
      in: tableView
    )
  }

  @MainActor
  final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    #if DEBUG
      private let usesIncrementalUpdates = LiveConnectionTableRowUpdatePlan.isEnabled
    #endif
    private var sourceRows: [LiveConnectionGroupRow] = []
    private var displayedRows: [LiveConnectionGroupRow] = []
    private var appliedSortResetGeneration: Int?
    private var shouldResetSort = false
    private var isResettingSort = false
    private var isUpdateScheduled = false

    func numberOfRows(in tableView: NSTableView) -> Int {
      displayedRows.count
    }

    func tableView(
      _ tableView: NSTableView,
      viewFor tableColumn: NSTableColumn?,
      row: Int
    ) -> NSView? {
      guard
        displayedRows.indices.contains(row),
        let tableColumn,
        let column = Column(rawValue: tableColumn.identifier.rawValue)
      else {
        return nil
      }

      let cell = makeCell(in: tableView, for: column)
      configure(cell, with: displayedRows[row], column: column)
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
      scheduleUpdate(in: tableView)
    }

    func update(
      _ newRows: [LiveConnectionGroupRow],
      sortResetGeneration: Int,
      in tableView: NSTableView
    ) {
      sourceRows = newRows
      if appliedSortResetGeneration != sortResetGeneration {
        appliedSortResetGeneration = sortResetGeneration
        shouldResetSort = true
      }
      scheduleUpdate(in: tableView)
    }

    private func scheduleUpdate(in tableView: NSTableView) {
      guard !isUpdateScheduled else {
        return
      }
      isUpdateScheduled = true
      Task { @MainActor [weak self, weak tableView] in
        await Task.yield()
        guard let self else {
          return
        }
        self.isUpdateScheduled = false
        guard let tableView else {
          return
        }
        self.applyRows(in: tableView)
      }
    }

    private func applyRows(in tableView: NSTableView) {
      if shouldResetSort {
        shouldResetSort = false
        if !tableView.sortDescriptors.isEmpty {
          isResettingSort = true
          tableView.sortDescriptors = []
          isResettingSort = false
        }
      }
      let descriptor = tableView.sortDescriptors.first
      let column = descriptor?.key.flatMap(Column.init(rawValue:))
      let nextRows = LiveConnectionTableSorting.groups(
        sourceRows,
        column: column,
        ascending: descriptor?.ascending ?? false
      )
      let hasSameOrder =
        displayedRows.count == nextRows.count
        && zip(displayedRows, nextRows).allSatisfy { $0.0.id == $0.1.id }
      #if DEBUG
        let incrementalPlan =
          usesIncrementalUpdates && !hasSameOrder && tableView.numberOfRows == displayedRows.count
          ? LiveConnectionTableRowUpdatePlan(
            previousIDs: displayedRows.map(\.id),
            nextIDs: nextRows.map(\.id)
          ) : nil
      #endif
      let hasChanged = displayedRows != nextRows
      displayedRows = nextRows

      if !hasSameOrder {
        #if DEBUG
          if let incrementalPlan {
            incrementalPlan.apply(to: tableView)
            updateVisibleCells(in: tableView)
            return
          }
        #endif
        tableView.reloadData()
        return
      }
      if hasChanged {
        updateVisibleCells(in: tableView)
      }
    }

    private func updateVisibleCells(in tableView: NSTableView) {
      let visibleRows = tableView.rows(in: tableView.visibleRect)
      guard visibleRows.length > 0 else {
        return
      }
      for row in visibleRows.location..<(visibleRows.location + visibleRows.length)
      where displayedRows.indices.contains(row) {
        for (columnIndex, column) in Column.allCases.enumerated() {
          guard
            let cell = tableView.view(
              atColumn: columnIndex,
              row: row,
              makeIfNecessary: false
            ) as? NSTableCellView
          else {
            continue
          }
          configure(cell, with: displayedRows[row], column: column)
        }
      }
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
      with row: LiveConnectionGroupRow,
      column: Column
    ) {
      guard let label = cell.textField else {
        return
      }
      let value = column.text(for: row)
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
