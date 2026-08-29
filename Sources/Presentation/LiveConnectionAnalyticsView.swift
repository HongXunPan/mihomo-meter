import SwiftUI

struct LiveConnectionAnalyticsView: View {
  @ObservedObject var monitor: TrafficMonitor

  @Binding var selectedRoute: LiveConnectionRoute
  @State private var selectedMode = LiveConnectionViewMode.connection
  @State private var searchText = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      LiveConnectionAnalyticsContextView(
        selectedRoute: $selectedRoute,
        connectionCount: selectedConnections.count,
        coverage: monitor.attributionCoverage,
        processMatchingMode: monitor.runtimeConfiguration?.processMatchingMode
      )

      LiveConnectionAnalyticsTableView(
        selectedRoute: selectedRoute,
        selectedMode: $selectedMode,
        searchText: $searchText,
        connections: filteredConnections,
        groupRows: groupRows
      )
    }
  }

  private var filteredConnections: [LiveTrafficConnection] {
    LiveConnectionAnalyticsPresentation.connections(
      from: selectedConnections,
      searchText: searchText
    )
  }

  private var groupRows: [LiveConnectionGroupRow] {
    LiveConnectionAnalyticsPresentation.groups(
      from: selectedConnections,
      mode: selectedMode,
      searchText: searchText
    )
  }

  private var selectedConnections: [LiveTrafficConnection] {
    LiveConnectionAnalyticsPresentation.sourceConnections(
      for: selectedRoute,
      proxyConnections: monitor.liveProxyConnections,
      directConnections: monitor.liveDirectConnections
    )
  }
}
