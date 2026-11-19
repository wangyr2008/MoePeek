import AppKit
import MarkdownUI
import SwiftUI

/// Renders Markdown for a translation result or a rich source. Remote images are never fetched;
/// their placeholder links copy the original URL to the clipboard when clicked. Local attachments
/// captured with the source are drawn inline only when `showsAttachments` is set.
///
/// Uses MarkdownUI (macOS 12+) in place of Textual (macOS 15+); MarkdownUI carries the same
/// author as Textual and an equivalent block rendering model.
struct MarkdownResultView: View {
    let text: String
    let fontName: String
    let fontSize: CGFloat
    var attachments: [String: SourceImageAttachment] = [:]
    var showsAttachments = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(MarkdownSupport.renderingSegments(text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .markdown(let markdown):
                    Markdown(MarkdownSupport.hardenLineBreaks(MarkdownSupport.localizeRemoteImages(markdown)))
                        .markdownTheme(.gitHub)
                        .markdownImageProvider(.noRemote)
                        .markdownTextStyle {
                            if fontName.isEmpty {
                                FontFamily(.system())
                            } else {
                                FontFamily(.custom(fontName))
                            }
                            FontSize(fontSize)
                        }
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .image(let placeholder):
                    imageSegment(placeholder)
                }
            }
        }
    }

    @ViewBuilder
    private func imageSegment(_ placeholder: MarkdownImagePlaceholder) -> some View {
        if let id = SourceAttachmentReference.id(from: placeholder.url) {
            if let attachment = attachments[id] {
                if showsAttachments {
                    LocalAttachmentImageView(data: attachment.data, label: id)
                        .padding(.vertical, 2)
                } else {
                    Text(verbatim: "🖼 \(id)")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: "🖼 \(id) · \(String(localized: "Image omitted"))")
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(placeholder.url.absoluteString, forType: .string)
            } label: {
                Text(placeholder.label)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(placeholder.label)
        }
    }
}

/// Defense-in-depth: `renderingSegments` already pulls every image out before MarkdownUI
/// sees the text, and `localizeRemoteImages` demotes the rest to links. This provider
/// guarantees no network fetch even if an image URL still reaches the renderer.
private struct NoRemoteImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        Text(verbatim: url?.absoluteString ?? "")
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}

private extension ImageProvider where Self == NoRemoteImageProvider {
    static var noRemote: Self { .init() }
}
