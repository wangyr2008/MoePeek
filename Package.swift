// swift-tools-version: 6.0
@preconcurrency import PackageDescription

let package = Package(
    name: "MoePeek",
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "2.3.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.0"),
        // MarkdownUI 2.x is the last line supporting macOS 12; Textual requires macOS 15.
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", exact: "2.4.1"),
    ]
)
