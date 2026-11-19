import SwiftUI

/// Speaker glyph that tracks TTS playback state. A separate view holding
/// `@ObservedObject` so playback state changes re-render the icon; the parent views
/// access the coordinator through an environment key that cannot observe it
/// (the macOS 12 build uses ObservableObject instead of the @Observable macro).
struct TTSSpeakerIcon: View {
    @ObservedObject var tts: TTSCoordinator
    let text: String

    var body: some View {
        Image(systemName: tts.isPlaying(text) ? "speaker.wave.3.fill" : "speaker.wave.2")
    }
}
