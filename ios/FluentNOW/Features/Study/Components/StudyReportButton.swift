import SwiftUI

/// Dane zgłaszanego zadania (bez komentarza — ten dopisuje użytkownik).
struct StudyReportDraft: Identifiable, Hashable {
    var id = UUID().uuidString.lowercased()
    var mode: String
    var question: String
    var answer: String
    var expected: [String]
    var wordId: String? = nil
    var meaningId: String? = nil
}

/// „Zgłoś błąd w zadaniu” — zapis lokalny w `ExerciseReportStore` (eksport z Ustawień).
struct StudyReportButton: View {
    let draft: StudyReportDraft

    @State private var presented: StudyReportDraft?

    var body: some View {
        Button {
            presented = draft
        } label: {
            Label("Zgłoś błąd w zadaniu", systemImage: "flag")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(item: $presented) { item in
            StudyReportSheet(draft: item)
        }
    }
}

/// Arkusz zgłoszenia: podgląd zadania + komentarz.
struct StudyReportSheet: View {
    let draft: StudyReportDraft

    @Environment(ExerciseReportStore.self) private var reports
    @Environment(LearningStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Zadanie") {
                    LabeledContent("Rodzaj", value: draft.mode)
                    Text(draft.question)
                        .font(FluentFont.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    if !draft.answer.isEmpty {
                        LabeledContent("Twoja odpowiedź", value: draft.answer)
                    }
                    if let first = draft.expected.first, !first.isEmpty {
                        LabeledContent("Oczekiwano", value: draft.expected.prefix(4).joined(separator: ", "))
                    }
                }
                Section {
                    TextField("Co jest nie tak? (np. brakuje poprawnego wariantu)", text: $comment, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Komentarz")
                } footer: {
                    Text("Zgłoszenie zapisujemy na tym urządzeniu. Możesz je wyeksportować w Ustawieniach.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Zgłoś błąd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz", action: save)
                        .disabled(sent)
                }
            }
            .fluentSensoryFeedback(FluentHaptic.answerCorrect, trigger: sent)
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard !sent else { return }
        sent = true
        let report = ExerciseReport(
            id: UUID().uuidString.lowercased(),
            createdAt: store.now(),
            mode: draft.mode,
            question: draft.question,
            answer: draft.answer,
            expected: draft.expected,
            wordId: draft.wordId,
            meaningId: draft.meaningId,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        reports.add(report)
        dismiss()
    }
}

#Preview("Zgłoś błąd") {
    StudyReportButton(draft: StudyReportDraft(mode: "Uzupełnij zdanie", question: "Can I ________ your pen?", answer: "lend", expected: ["borrow"]))
        .padding(Spacing.screen)
        .background(Palette.background)
        .fluentPreviewEnvironment()
}
