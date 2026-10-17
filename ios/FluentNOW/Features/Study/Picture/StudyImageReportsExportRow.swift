import SwiftUI
import FluentKit

/// Wiersz eksportu zgłoszeń „Zdjęcie nie pasuje” (G2) — osadzany w Ustawieniach → Eksport,
/// w sekcji „Zgłoszenia”. Sam przygotowuje plik `image-reports` (JSON) do `ShareLink`.
struct StudyImageReportsExportRow: View {
    @Environment(AppEnvironment.self) private var env
    @State private var file: URL?
    @State private var failed = false

    var body: some View {
        let count = env.imageReports.reports.count
        Group {
            if count == 0 {
                Text("Brak zgłoszonych zdjęć.")
                    .foregroundStyle(Palette.inkSecondary)
            } else if let file {
                ShareLink(item: file) {
                    StudyImageReportsLabel(count: count, trailing: "square.and.arrow.up")
                }
            } else {
                HStack {
                    StudyImageReportsLabel(count: count, trailing: nil)
                    if !failed { ProgressView() }
                }
                .foregroundStyle(Palette.inkSecondary)
            }
        }
        .task(id: count) {
            guard count > 0 else {
                file = nil
                return
            }
            do {
                file = try env.imageReports.exportFile()
                failed = false
            } catch {
                file = nil
                failed = true
            }
        }
    }
}

private struct StudyImageReportsLabel: View {
    let count: Int
    let trailing: String?

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zgłoszone zdjęcia (\(count))")
                    Text("Plik JSON: słowo, znaczenie, adres i źródło zdjęcia, komentarz")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            } icon: {
                Image(systemName: "photo.badge.exclamationmark")
            }
            Spacer(minLength: 0)
            if let trailing {
                Image(systemName: trailing)
                    .accessibilityHidden(true)
            }
        }
    }
}
