import SwiftUI

struct StatusMenuDisclosureGroupStyle: DisclosureGroupStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      StatusMenuDisclosureLabel(
        isExpanded: configuration.$isExpanded,
        label: configuration.label
      )

      if configuration.isExpanded {
        configuration.content
      }
    }
  }
}

private enum StatusMenuDisclosureLayout {
  static let horizontalPadding: CGFloat = 6
  static let verticalPadding: CGFloat = 4
}

private struct StatusMenuDisclosureLabel<Label: View>: View {
  @Binding var isExpanded: Bool
  let label: Label

  var body: some View {
    Button {
      isExpanded.toggle()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tertiary)
          .frame(width: 8)

        label
      }
      .padding(.horizontal, StatusMenuDisclosureLayout.horizontalPadding)
      .padding(.vertical, StatusMenuDisclosureLayout.verticalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
