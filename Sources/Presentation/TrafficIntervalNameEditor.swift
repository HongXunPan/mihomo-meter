import SwiftUI

struct TrafficIntervalNameEditor: View {
  let title: String
  let actionTitle: String
  let cancel: () -> Void
  let submit: (String) async -> Bool

  @State private var name: String
  @State private var isSubmitting = false
  @FocusState private var isNameFocused: Bool

  init(
    title: String,
    initialName: String,
    actionTitle: String,
    cancel: @escaping () -> Void,
    submit: @escaping (String) async -> Bool
  ) {
    self.title = title
    self.actionTitle = actionTitle
    self.cancel = cancel
    self.submit = submit
    _name = State(initialValue: initialName)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))

      HStack(spacing: 8) {
        TextField("任务名称", text: $name)
          .textFieldStyle(.roundedBorder)
          .focused($isNameFocused)
          .onSubmit(performSubmit)

        Button("取消", action: cancel)
          .keyboardShortcut(.cancelAction)
          .disabled(isSubmitting)

        Button(actionTitle, action: performSubmit)
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(trimmedName.isEmpty || isSubmitting)

        if isSubmitting {
          ProgressView()
            .controlSize(.small)
        }
      }
    }
    .padding(10)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
    .onAppear {
      isNameFocused = true
    }
    .onExitCommand {
      guard !isSubmitting else {
        return
      }
      cancel()
    }
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func performSubmit() {
    guard !trimmedName.isEmpty, !isSubmitting else {
      return
    }

    Task { @MainActor in
      isSubmitting = true
      let succeeded = await submit(trimmedName)
      isSubmitting = false
      if succeeded {
        cancel()
      }
    }
  }
}
