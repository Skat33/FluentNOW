import SwiftUI
import FluentKit

/// Podsumowanie sesji łączonej przed startem — gdy część wybranych trybów nie ma gotowych zadań.
struct StudyCombinedDraftSheet: View {
    let draft: CombinedSession
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draft.modes, id: \.self) { mode in
                        let count = draft.tasks.filter { $0.mode == mode }.count
                        HStack {
                            Label(mode.namePl, systemImage: mode.studySystemImage)
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: Spacing.xs)
                            Text(count > 0 ? StudyFormat.tasks(count) : "Brak gotowych zadań — pominięte")
                                .font(FluentFont.subheadline)
                                .foregroundStyle(count > 0 ? Palette.inkSecondary : Palette.warning)
                                .multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text("\(StudyFormat.tasks(draft.tasks.count)) · około \(draft.minutes) minut. \(draft.random ? "Kolejność losowa, ustalona raz przy starcie." : "Zadania pogrupowane według rodzaju.")")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Twoja sesja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rozpocznij") { onStart() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("Szkic sesji łączonej") {
    StudyCombinedDraftSheet(
        draft: CombinedSession(id: "preview", modes: [.mixed, .reading], random: true, minutes: 10, tasks: [], updatedAt: 0)
    ) {}
    .fluentPreviewEnvironment()
}
