import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją szybkim dodawaniem.
/// Wzorzec arkusza: własny `NavigationStack`, „Anuluj” po lewej, detenty średni/duży.
struct AddWordRootPlaceholder: View {
    let prefill: String?

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wpisz słowo po angielsku lub po polsku", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($isFieldFocused)
                } footer: {
                    Text("Propozycje znaczeń pojawią się od razu, także bez internetu.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Dodaj słowo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let prefill, text.isEmpty {
                text = prefill
            }
            isFieldFocused = true
        }
    }
}

#Preview("Dodawanie — zaślepka") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddWordRootPlaceholder(prefill: "borrow")
        }
}
