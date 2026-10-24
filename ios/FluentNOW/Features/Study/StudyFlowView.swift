import SwiftUI
import FluentKit

/// Pełny ekran sesji (tryb skupienia, bez paska kart). Zamknięcie = przerwa:
/// stan sesji jest już zapisany w `LearningStore`, więc można ją wznowić z ekranu Nauka.
struct StudyFlowView: View {
    let flow: StudyFlow

    @Environment(\.dismiss) private var dismiss
    @Environment(SpeechService.self) private var speech

    var body: some View {
        NavigationStack {
            content
                .background(Palette.background.ignoresSafeArea())
                .navigationTitle(flow.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            speech.stop()
                            dismiss()
                        } label: {
                            Label("Zrób przerwę", systemImage: "xmark")
                        }
                        .accessibilityHint(Text("Postęp jest zapisany — możesz wrócić do sesji później."))
                    }
                }
        }
        .onDisappear {
            speech.stop()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch flow {
        case .vocabulary:
            VocabSessionView()
        case .combined:
            CombinedSessionView()
        case .reading(let autoStart):
            ReadingPracticeView(autoStart: autoStart)
        case .practice(let kind, let autoStart):
            PracticeSetView(kind: kind, autoStart: autoStart)
        case .production(let autoStart):
            ProductionPracticeView(autoStart: autoStart)
        case .flashcards(let collection):
            FlashcardDeckScreen(collection: collection)
        case .resumedFlashcards(let paused):
            FlashcardDeckScreen(collection: paused.collection, resume: paused)
        }
    }
}

#Preview("Pełny ekran sesji") {
    StudyFlowView(flow: .vocabulary)
        .fluentPreviewEnvironment()
}
