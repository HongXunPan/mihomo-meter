import SwiftUI

struct PopoverDisclosureGroupStyle: DisclosureGroupStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      PopoverDisclosureLabel(
        isExpanded: configuration.$isExpanded,
        label: configuration.label
      )

      if configuration.isExpanded {
        configuration.content
      }
    }
  }
}

private enum PopoverDisclosureLayout {
  static let cornerRadius: CGFloat = 6
  static let horizontalPadding: CGFloat = 6
  static let verticalPadding: CGFloat = 4
}

private struct PopoverDisclosureLabel<Label: View>: View {
  @Binding var isExpanded: Bool
  let label: Label

  @FocusState private var isFocused: Bool

  @ViewBuilder
  var body: some View {
    if #available(macOS 14.0, *) {
      disclosureButton
        .focusEffectDisabled()
        .background(focusBackground)
        .overlay(focusBorder)
    } else {
      disclosureButton
    }
  }

  private var disclosureButton: some View {
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
      .padding(.horizontal, PopoverDisclosureLayout.horizontalPadding)
      .padding(.vertical, PopoverDisclosureLayout.verticalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focused($isFocused)
  }

  private var focusBackground: some View {
    RoundedRectangle(
      cornerRadius: PopoverDisclosureLayout.cornerRadius,
      style: .continuous
    )
    .fill(Color.accentColor.opacity(isFocused ? 0.08 : 0))
  }

  private var focusBorder: some View {
    RoundedRectangle(
      cornerRadius: PopoverDisclosureLayout.cornerRadius,
      style: .continuous
    )
    .strokeBorder(
      Color.accentColor.opacity(isFocused ? 0.75 : 0),
      lineWidth: 2
    )
  }
}
