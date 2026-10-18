import SwiftUI
import UIKit
import FluentKit

/// „Słowo i zdjęcie” (G2): angielskie słowo z odsłuchem i cztery zdjęcia — wskaż właściwe.
struct VocabPicturePrompt: View {
    let model: VocabExerciseModel

    @Environment(SpeechService.self) private var speech

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Które zdjęcie pokazuje to słowo?")
            HStack(alignment: .center, spacing: Spacing.s) {
                Text(model.content.word.en)
                    .font(FluentFont.flashcardTerm)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(model.content.word.en) }
            }
            if !model.content.word.ipa.isEmpty {
                Text(model.content.word.ipa)
                    .font(FluentFont.ipa)
                    .foregroundStyle(Palette.inkSecondary)
            }
            VocabPictureGrid(model: model)
            Text(model.isFinished ? "Źródło zdjęć: Openverse (licencje Creative Commons)." : "Dotknij zdjęcia. Liczy się pierwszy wybór.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Siatka 2 × 2 (skróty 1–4 na klawiaturze sprzętowej).
private struct VocabPictureGrid: View {
    let model: VocabExerciseModel

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.s),
        GridItem(.flexible(), spacing: Spacing.s)
    ]

    var body: some View {
        if model.pictures.isEmpty {
            VocabPicturePlaceholderGrid(columns: columns)
        } else {
            LazyVGrid(columns: columns, spacing: Spacing.s) {
                ForEach(model.pictures.indices, id: \.self) { (index: Int) in
                    if let option = model.pictures.studyItem(at: index) {
                        StudyPictureTile(
                            option: option,
                            index: index,
                            state: tileState(index: index, option: option),
                            isEnabled: !model.isFinished
                        ) {
                            model.choosePicture(at: index)
                        }
                    }
                }
            }
        }
    }

    private func tileState(index: Int, option: StudyPictureOption) -> StudyPictureTile.TileState {
        guard model.isFinished else { return .neutral }
        if option.isCorrect { return .correct }
        if model.selectedPicture == index { return .wrong }
        return .dimmed
    }
}

/// Zastępczy układ, zanim zdjęcia (z dysku) się wczytają — zwykle ułamek sekundy.
private struct VocabPicturePlaceholderGrid: View {
    let columns: [GridItem]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(0..<4, id: \.self) { (_: Int) in
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(Palette.surfaceMuted)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(ProgressView().tint(Palette.accent))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Wczytywanie zdjęć"))
    }
}

/// Jedno zdjęcie-przycisk. Plik czytany i dekodowany poza głównym wątkiem.
struct StudyPictureTile: View {
    enum TileState: Equatable {
        case neutral, correct, wrong, dimmed
    }

    let option: StudyPictureOption
    let index: Int
    let state: TileState
    let isEnabled: Bool
    let action: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                photo
                if state != .neutral {
                    Text("\(option.term) — \(option.translation)")
                        .font(FluentFont.caption.weight(.semibold))
                        .foregroundStyle(captionColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(state == .dimmed ? 0.55 : 1)
        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(traits)
        .task(id: option.image.fileURL) {
            image = await StudyPictureTile.load(option.image.fileURL)
        }
    }

    private var photo: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .background(Palette.surfaceMuted)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                } else {
                    ProgressView().tint(Palette.accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: state == .correct || state == .wrong ? 3 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if let symbol = badgeSymbol {
                    Image(systemName: symbol)
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.onAccent, borderColor)
                        .symbolRenderingMode(.palette)
                        .padding(Spacing.xs)
                        .accessibilityHidden(true)
                }
            }
    }

    private var traits: AccessibilityTraits {
        if state == .correct {
            return [.isButton, .isSelected]
        }
        return [.isButton]
    }

    private var borderColor: Color {
        switch state {
        case .correct: return Palette.success
        case .wrong: return Palette.danger
        case .neutral, .dimmed: return Palette.separator
        }
    }

    private var captionColor: Color {
        switch state {
        case .correct: return Palette.success
        case .wrong: return Palette.danger
        case .neutral, .dimmed: return Palette.inkSecondary
        }
    }

    private var badgeSymbol: String? {
        switch state {
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        case .neutral, .dimmed: return nil
        }
    }

    private var accessibilityText: String {
        switch state {
        case .neutral: return "Zdjęcie \(index + 1)"
        case .correct: return "Zdjęcie \(index + 1): \(option.term), poprawne"
        case .wrong: return "Zdjęcie \(index + 1): \(option.term), Twój wybór"
        case .dimmed: return "Zdjęcie \(index + 1): \(option.term)"
        }
    }

    /// Wczytanie i dekodowanie JPEG/PNG w tle (bez przycięć przewijania).
    nonisolated static func load(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url), let decoded = UIImage(data: data) else { return nil }
            return decoded.preparingForDisplay() ?? decoded
        }.value
    }
}

/// Po odpowiedzi: „Info o zdjęciu” (autorzy, licencje) i „Zdjęcie nie pasuje” (zgłoszenie).
struct VocabPictureFeedbackActions: View {
    let model: VocabExerciseModel

    @State private var showsInfo = false
    @State private var showsReport = false
    @State private var reported = false

    var body: some View {
        if !model.pictures.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.m) { buttons }
                VStack(alignment: .leading, spacing: 0) { buttons }
            }
            .sheet(isPresented: $showsInfo) {
                StudyPictureInfoSheet(options: model.pictures)
            }
            .sheet(isPresented: $showsReport) {
                StudyPictureReportSheet(model: model) {
                    reported = true
                }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            showsInfo = true
        } label: {
            Label("Info o zdjęciu", systemImage: "info.circle")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Button {
            showsReport = true
        } label: {
            Label(reported ? "Zgłoszono — dziękujemy" : "Zdjęcie nie pasuje", systemImage: reported ? "checkmark" : "photo.badge.exclamationmark")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(reported)
    }
}

/// Autorzy i licencje czterech zdjęć (wymóg CC BY / BY-SA) + informacja o Openverse.
struct StudyPictureInfoSheet: View {
    let options: [StudyPictureOption]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(options) { (option: StudyPictureOption) in
                    StudyPictureInfoRow(option: option)
                }
                Section {
                    Text("Zdjęcia pochodzą z serwisu Openverse i są udostępniane na licencjach Creative Commons (CC0, CC BY, CC BY-SA). Aplikacja korzysta z Openverse, ale nie jest przez nie wspierana ani certyfikowana.")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Info o zdjęciach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct StudyPictureInfoRow: View {
    let option: StudyPictureOption

    var body: some View {
        let record = option.image.record
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("\(option.term) — \(option.translation)")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            if !record.title.isEmpty {
                Text("„\(record.title)”")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(record.attributionLine)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
            StudyPictureLinks(record: record)
        }
        .padding(.vertical, Spacing.xxs)
    }
}

private struct StudyPictureLinks: View {
    let record: WordImageRecord

    var body: some View {
        HStack(spacing: Spacing.m) {
            if let url = URL(string: record.landingURL), url.scheme == "https" {
                Link("Źródło", destination: url)
            }
            if let url = URL(string: record.licenseURL), url.scheme == "https" {
                Link("Licencja", destination: url)
            }
        }
        .font(FluentFont.footnote.weight(.semibold))
        .tint(Palette.accent)
    }
}

/// „Zdjęcie nie pasuje”: które zdjęcie + opcjonalny komentarz → `image-reports.json`;
/// zgłoszone zdjęcie nie wraca dla tego słowa (bierzemy następne).
struct StudyPictureReportSheet: View {
    let model: VocabExerciseModel
    let onSent: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String = ""
    @State private var comment = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Które zdjęcie nie pasuje?") {
                    Picker("Zdjęcie", selection: $selectedID) {
                        ForEach(model.pictures) { (option: StudyPictureOption) in
                            Text("\(option.term) — \(option.translation)").tag(option.meaningId)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    TextField("Co jest nie tak? (np. pokazuje inny przedmiot)", text: $comment, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Komentarz (opcjonalnie)")
                } footer: {
                    Text("Zgłoszenie zapisujemy na tym urządzeniu (eksport w Ustawieniach). To zdjęcie nie pojawi się już przy tym słowie.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Zdjęcie nie pasuje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zgłoś", action: send)
                        .disabled(sent || selectedOption == nil)
                }
            }
            .onAppear {
                if selectedID.isEmpty {
                    selectedID = model.correctPicture?.meaningId ?? model.pictures.first?.meaningId ?? ""
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var selectedOption: StudyPictureOption? {
        model.pictures.first { (option: StudyPictureOption) -> Bool in option.meaningId == selectedID }
    }

    private func send() {
        guard !sent, let option = selectedOption else { return }
        sent = true
        let report = ImageReport(
            createdAt: store.now(),
            term: option.term,
            meaning: option.translation,
            wordId: option.wordId,
            meaningId: option.meaningId,
            record: option.image.record,
            verification: option.image.verification,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        env.imageReports.add(report)
        let images = env.images
        let meaningID = option.meaningId
        let imageID = option.image.record.id
        Task {
            await images.reject(meaningID: meaningID, imageID: imageID)
        }
        onSent()
        dismiss()
    }
}
