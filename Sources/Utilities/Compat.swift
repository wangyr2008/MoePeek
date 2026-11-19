import AppKit
import SwiftUI

/// Minimal lock-protected value standing in for `OSAllocatedUnfairLock` (macOS 13+).
/// All callers in this codebase store `Bool` flags, which are trivially Sendable.
final class UnfairLockBox<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(initialState: Value) {
        self.value = initialState
    }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

/// macOS 12/13 compatibility helpers. The upstream project targets macOS 15 and freely uses
/// newer SwiftUI APIs; this fork keeps the deployment target at 12.0, so newer styling
/// modifiers degrade gracefully here instead of failing to compile.
enum Compat {
    /// Wraps `NSHostingView` usage so the popup panel does not auto-resize its window.
    ///
    /// On macOS 13+ the upstream code sets `hostingView.sizingOptions = []` for this.
    /// On macOS 12 that API does not exist; nesting the hosting view inside a fixed
    /// container prevents it from driving the window's content size.
    @MainActor
    static func hostingView<Content: View>(_ content: Content) -> NSView {
        let hosting = NSHostingView(rootView: content)
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = []
            return hosting
        }
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = true
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }
}

extension View {
    /// `.formStyle(.grouped)` is macOS 13+; on 12 the form keeps its default grouped look.
    @ViewBuilder
    func compatFormStyleGrouped() -> some View {
        if #available(macOS 13.0, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }

    /// `.scrollContentBackground(.hidden)` is macOS 13+; on 12 the default list
    /// background is kept, which is visually acceptable.
    @ViewBuilder
    func compatScrollContentBackgroundHidden() -> some View {
        if #available(macOS 13.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

/// Stand-in for `LabeledContent` (macOS 13+): a plain leading label with trailing content.
struct CompatLabeledContent<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
    }
}

/// Stand-in for `ContentUnavailableView` (macOS 14+).
struct CompatUnavailableView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
