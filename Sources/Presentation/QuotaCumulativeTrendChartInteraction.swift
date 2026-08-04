import AppKit
import Charts
import SwiftUI

struct QuotaCumulativeTrendExternalInteraction {
  let selectedPointID: UUID?
  let onSelectedPointChange: (UUID?) -> Void
}

struct QuotaCumulativeTrendChartInteractionOverlay: View {
  let proxy: ChartProxy
  let model: QuotaCumulativeTrendChartModel
  let selectedPoint: QuotaCumulativeTrendDisplayPoint?
  let externalInteraction: QuotaCumulativeTrendExternalInteraction?
  let onInternalSelectedPointChange: (UUID?) -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        if let externalInteraction,
          let plotFrame = resolvedPlotFrame(geometry: geometry)
        {
          StatusMenuTrendTrackingView(
            onMove: { position in
              externalInteraction.onSelectedPointChange(
                model.nearestPoint(atNormalizedPosition: Double(position))?.id
              )
            },
            onExit: {
              externalInteraction.onSelectedPointChange(nil)
            }
          )
          .frame(width: plotFrame.width, height: plotFrame.height)
          .offset(x: plotFrame.minX, y: plotFrame.minY)
        } else {
          Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
              updateContinuousHover(phase, geometry: geometry)
            }

          if let selectedPoint,
            let plotFrame = resolvedPlotFrame(geometry: geometry),
            let xPosition = proxy.position(forX: selectedPoint.point.date)
          {
            QuotaCumulativeTrendHoverOverlay(
              displayPoint: selectedPoint,
              breakReason: breakReason(for: selectedPoint.id),
              selectedX: plotFrame.minX + xPosition,
              plotFrame: plotFrame
            )
          }
        }
      }
    }
  }

  private func updateContinuousHover(
    _ phase: HoverPhase,
    geometry: GeometryProxy
  ) {
    switch phase {
    case .active(let location):
      guard let plotFrame = resolvedPlotFrame(geometry: geometry),
        plotFrame.contains(location),
        let date = proxy.value(
          atX: location.x - plotFrame.minX,
          as: Date.self
        )
      else {
        onInternalSelectedPointChange(nil)
        return
      }
      onInternalSelectedPointChange(model.nearestPoint(to: date)?.id)
    case .ended:
      onInternalSelectedPointChange(nil)
    }
  }

  private func resolvedPlotFrame(geometry: GeometryProxy) -> CGRect? {
    guard let anchor = proxy.plotFrame else {
      return nil
    }
    return geometry[anchor]
  }

  private func breakReason(
    for pointID: UUID
  ) -> QuotaCumulativeTrendDisplaySegment.BreakReason? {
    model.segments.first(where: { $0.points.first?.id == pointID })?.breakReason
  }
}

private struct StatusMenuTrendTrackingView: NSViewRepresentable {
  let onMove: (CGFloat) -> Void
  let onExit: () -> Void

  func makeNSView(context: Context) -> StatusMenuTrendTrackingNSView {
    StatusMenuTrendTrackingNSView(onMove: onMove, onExit: onExit)
  }

  func updateNSView(
    _ nsView: StatusMenuTrendTrackingNSView,
    context: Context
  ) {
    nsView.onMove = onMove
    nsView.onExit = onExit
  }
}

private final class StatusMenuTrendTrackingNSView: NSView {
  var onMove: (CGFloat) -> Void
  var onExit: () -> Void

  private var pointerTrackingArea: NSTrackingArea?

  init(
    onMove: @escaping (CGFloat) -> Void,
    onExit: @escaping () -> Void
  ) {
    self.onMove = onMove
    self.onExit = onExit
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    return nil
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let pointerTrackingArea {
      removeTrackingArea(pointerTrackingArea)
    }
    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [
        .mouseEnteredAndExited,
        .mouseMoved,
        .activeAlways,
        .inVisibleRect,
      ],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    pointerTrackingArea = trackingArea
  }

  override func mouseEntered(with event: NSEvent) {
    updatePointerPosition(with: event)
  }

  override func mouseMoved(with event: NSEvent) {
    updatePointerPosition(with: event)
  }

  override func mouseExited(with event: NSEvent) {
    onExit()
  }

  private func updatePointerPosition(with event: NSEvent) {
    guard bounds.width > 0 else {
      onExit()
      return
    }
    let location = convert(event.locationInWindow, from: nil)
    onMove(min(max(location.x / bounds.width, 0), 1))
  }
}
