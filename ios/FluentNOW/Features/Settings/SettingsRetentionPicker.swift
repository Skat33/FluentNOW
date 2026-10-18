import SwiftUI
import FluentKit

/// „Docelowa skuteczność powtórek” (I1): docelowa retencja algorytmu FSRS (85 / 90 / 95%).
/// Wyższa wartość = częstsze powtórki, niższa = rzadsze. Zmiana działa od następnej odpowiedzi.
struct SettingsRetentionPicker: View {
    @Environment(LearningStore.self) private var store

    private var options: [Double] {
        let current = store.settings.effectiveRetention
        let choices = FSRS.retentionChoices
        return choices.contains(current) ? choices : (choices + [current]).sorted()
    }

    private var selection: Binding<Double> {
        Binding(
            get: { store.settings.effectiveRetention },
            set: { value in
                let retention = FSRS.clampedRetention(value)
                store.update(.edit) { $0.settings.desiredRetention = retention }
            }
        )
    }

    var body: some View {
        Picker(selection: selection) {
            ForEach(options, id: \.self) { (value: Double) in
                Text(SettingsRetentionPicker.title(value)).tag(value)
            }
        } label: {
            Label("Docelowa skuteczność powtórek", systemImage: "brain.head.profile")
        }
        .accessibilityHint("Wyższa wartość oznacza częstsze powtórki")
    }

    static func title(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        switch percent {
        case 85: return "85% · mniej powtórek"
        case 90: return "90% · zalecane"
        case 95: return "95% · więcej powtórek"
        default: return "\(percent)%"
        }
    }
}
