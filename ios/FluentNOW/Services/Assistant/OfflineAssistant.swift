import Foundation
import FluentKit

/// Domyślny „asystent” bez AI: wbudowana baza słów i lokalne ocenianie FluentKit.
/// Zawsze działa, bez internetu.
struct OfflineAssistant: LanguageAssistant {
    let content: ContentLibrary

    func lookup(term: String) async throws -> Lookup {
        if let found = await content.lookup(term: term) {
            return found
        }
        throw AssistantError.notFound(term)
    }

    /// Lokalna ocena jest już wykonana przez UI (`VocabularyGrader.localGrade`) — brak drugiej opinii.
    func grade(_ request: GradeRequest) async throws -> Grade? {
        nil
    }
}
