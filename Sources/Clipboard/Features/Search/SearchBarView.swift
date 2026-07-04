import SwiftUI

public struct SearchBarView: View {
    @Binding public var text: String
    public var placeholder: String = String(localized: "panel.searchPlaceholder", defaultValue: "Search clipboard…")
    @FocusState private var focused: Bool

    public init(text: Binding<String>, placeholder: String? = nil) {
        self._text = text
        if let placeholder { self.placeholder = placeholder }
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .regular))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($focused)
                .onAppear { focused = true }
                .onSubmit { }   // handled by outer key monitor
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
