import Foundation
import MachO

/// Bezpieczne sprawdzenie, czy aplikacja została podpisana z uprawnieniem CloudKit.
///
/// `CKContainer(identifier:)` bez uprawnienia `com.apple.developer.icloud-services` kończy się
/// wyjątkiem Objective-C (crash), a projekt da się zbudować bez niego (darmowe konto — README).
/// Dlatego zanim dotkniemy CloudKit, sprawdzamy uprawnienia:
/// - urządzenie, build deweloperski/ad hoc: `embedded.mobileprovision` w bundlu,
/// - symulator: sekcja `__TEXT,__entitlements` pliku wykonywalnego (Xcode wkleja tam uprawnienia),
/// - build z App Store / TestFlight (brak profilu w bundlu): uprawnienia są zawsze obecne.
enum CloudKitAvailability {
    static let containerIdentifier = "iCloud.pl.fluentnow.app"
    static let servicesKey = "com.apple.developer.icloud-services"

    /// Wynik jest liczony raz (odczyt pliku profilu / sekcji binarki).
    static let hasCloudKitEntitlement: Bool = computeEntitlement()

    private static func computeEntitlement() -> Bool {
        #if targetEnvironment(simulator)
        guard let entitlements = simulatorEntitlements() else { return false }
        return containsCloudKit(entitlements)
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            // App Store / TestFlight: profil nie jest dołączany, a build ma uprawnienia z project.yml.
            return true
        }
        guard let data = try? Data(contentsOf: url),
              let profile = provisioningPlist(from: data),
              let entitlements = profile["Entitlements"] as? [String: Any] else {
            return false
        }
        return containsCloudKit(entitlements)
        #endif
    }

    static func containsCloudKit(_ entitlements: [String: Any]) -> Bool {
        if let services = entitlements[servicesKey] as? [String] {
            return services.contains("CloudKit") || services.contains("*")
        }
        if let service = entitlements[servicesKey] as? String {
            return service == "*" || service == "CloudKit"
        }
        return false
    }

    /// Wyciąga plist z podpisanego (CMS) pliku profilu.
    static func provisioningPlist(from data: Data) -> [String: Any]? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else {
            return nil
        }
        let slice = data.subdata(in: start.lowerBound..<end.upperBound)
        return (try? PropertyListSerialization.propertyList(from: slice, options: [], format: nil)) as? [String: Any]
    }

    #if targetEnvironment(simulator)
    private static func simulatorEntitlements() -> [String: Any]? {
        guard let header = _dyld_get_image_header(0) else { return nil }
        var size: UInt = 0
        let raw = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        guard let bytes = getsectiondata(raw, "__TEXT", "__entitlements", &size), size > 0 else { return nil }
        let data = Data(bytes: bytes, count: Int(size))
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }
    #endif
}
