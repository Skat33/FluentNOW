import SwiftUI

/// Alert z polem nazwy kolekcji (tworzenie i zmiana nazwy) z walidacją.
struct CollectionNameAlert: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let initialName: String
    let existing: [String]
    let current: String?
    let confirmTitle: String
    let onSave: (String) -> Void

    @State private var name = ""

    private var issue: String? {
        CollectionMutations.nameIssue(name, existing: existing, current: current)
    }

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField("Nazwa kolekcji", text: $name)
                Button(confirmTitle) {
                    if issue == nil {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .disabled(issue != nil)
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text(issue ?? "Słowa możesz przenosić między kolekcjami w edycji słowa.")
            }
            .onChange(of: isPresented) { _, presented in
                if presented { name = initialName }
            }
    }
}

extension View {
    func collectionNameAlert(
        isPresented: Binding<Bool>,
        title: String,
        initialName: String = "",
        existing: [String],
        current: String? = nil,
        confirmTitle: String,
        onSave: @escaping (String) -> Void
    ) -> some View {
        modifier(CollectionNameAlert(
            isPresented: isPresented,
            title: title,
            initialName: initialName,
            existing: existing,
            current: current,
            confirmTitle: confirmTitle,
            onSave: onSave
        ))
    }
}
