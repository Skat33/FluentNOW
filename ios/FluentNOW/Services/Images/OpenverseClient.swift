import Foundation

/// Errors of the photo service (never shown as a blocking error — the exercise just does not
/// appear).
enum WordImageError: Error, LocalizedError, Equatable {
    case offline
    case rateLimited(retryAfter: TimeInterval)
    case http(Int)
    case invalidResponse
    case notAnImage
    case timedOut

    var errorDescription: String? {
        switch self {
        case .offline:
            return "Brak połączenia z internetem — zdjęcia pobierzemy później."
        case .timedOut:
            return "Serwis zdjęć odpowiada zbyt wolno — spróbujemy później."
        case .rateLimited:
            return "Serwis zdjęć prosi o chwilę przerwy. Spróbujemy później."
        case .http(let code):
            return "Serwis zdjęć odpowiedział błędem (\(code))."
        case .invalidResponse:
            return "Serwis zdjęć zwrócił nieczytelną odpowiedź."
        case .notAnImage:
            return "Pobrany plik nie jest zdjęciem."
        }
    }
}

/// Openverse API (https://api.openverse.org/v1/, anonymous, no key).
///
/// Verified 2026-10-15 and again 2026-10-17 (FEEDBACK-3 H2: search 200 with 240 results for
/// „apple” / „cutting board”, `/thumb/` 200 `image/jpeg` with exactly our headers): `GET /v1/images/?q=…&license=cc0,by,by-sa&category=photograph&extension=jpg,png&mature=false&page_size=…`
/// returns `results[]` with `id, title, url, thumbnail, foreign_landing_url, creator, creator_url,
/// license, license_version, license_url, provider, source, width, height, filetype, mature`.
/// Anonymous limits (response headers): searches 20/min and 200/day, thumbnails 1000/day;
/// `GET /v1/images/{id}/thumb/` returns a scaled JPEG (~600 px, ~80 KB).
/// Terms: attribute CC works, respect rate limits, no scraping, say the app uses Openverse
/// without being endorsed by it.
struct OpenverseClient: Sendable {
    static let baseURL = "https://api.openverse.org/v1/images/"
    static let allowedLicenses: Set<String> = ["cc0", "by", "by-sa"]
    /// Identifies the app to the API (good practice; the API documents no mandatory format).
    static let userAgent = "FluentNOW/1.0 (iOS; aplikacja do nauki angielskiego; https://github.com/Skat33/FluentNOW)"
    static let pageSize = 12
    /// Largest accepted image file (thumbnails are ~50–150 KB).
    static let maxImageBytes = 2_500_000

    let session: URLSession

    /// Session with short timeouts, no cookies, no waiting for connectivity (offline = fail fast).
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        // Searches measured on 2026-10-17 took 0.05–7 s; thumbnails 0.05–1 s.
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.waitsForConnectivity = false
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept": "application/json, image/jpeg, image/png"
        ]
        return URLSession(configuration: configuration)
    }

    /// Search URL for a query.
    static func searchURL(query: String) -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "q", value: String(query.prefix(200))),
            URLQueryItem(name: "license", value: "cc0,by,by-sa"),
            URLQueryItem(name: "category", value: "photograph"),
            URLQueryItem(name: "extension", value: "jpg,png"),
            URLQueryItem(name: "mature", value: "false"),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        return components.url
    }

    /// Searches photos and returns usable records in relevance order.
    func search(query: String) async throws -> [WordImageRecord] {
        guard let url = Self.searchURL(query: query) else { throw WordImageError.invalidResponse }
        let data = try await fetch(url)
        return try Self.parseSearch(data, query: query)
    }

    /// Downloads image bytes (thumbnail) and checks they really are a JPEG/PNG of sane size.
    func downloadImage(from address: String) async throws -> Data {
        guard let url = URL(string: address), url.scheme == "https" else { throw WordImageError.invalidResponse }
        let data = try await fetch(url)
        guard data.count > 512, data.count <= Self.maxImageBytes, Self.isImageData(data) else {
            throw WordImageError.notAnImage
        }
        return data
    }

    // MARK: Parsing (pure, testable)

    private struct SearchResponse: Decodable {
        var results: [Item]?
    }

    private struct Item: Decodable {
        var id: String?
        var title: String?
        var url: String?
        var thumbnail: String?
        var foreign_landing_url: String?
        var creator: String?
        var creator_url: String?
        var license: String?
        var license_version: String?
        var license_url: String?
        var provider: String?
        var source: String?
        var width: Int?
        var height: Int?
        var filetype: String?
        var mature: Bool?
        var tags: [Tag]?
    }

    private struct Tag: Decodable {
        var name: String?
    }

    /// Keeps CC0 / BY / BY-SA photos with a thumbnail, a sane size and aspect ratio, never mature;
    /// results whose title or tags mention the searched word come first.
    static func parseSearch(_ data: Data, query: String) throws -> [WordImageRecord] {
        let response: SearchResponse
        do {
            response = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw WordImageError.invalidResponse
        }
        let words = query.lowercased().split(separator: " ").map { String($0) }
        var strong: [WordImageRecord] = []
        var weak: [WordImageRecord] = []
        for item in response.results ?? [] {
            guard let record = record(from: item) else { continue }
            let title = (item.title ?? "").lowercased()
            let tags = (item.tags ?? []).compactMap { $0.name?.lowercased() }
            let mentioned = words.allSatisfy { (word: String) -> Bool in
                title.contains(word) || tags.contains { (tag: String) -> Bool in tag.contains(word) }
            }
            if mentioned {
                strong.append(record)
            } else {
                weak.append(record)
            }
        }
        return strong + weak
    }

    private static func record(from item: Item) -> WordImageRecord? {
        guard let id = item.id, !id.isEmpty,
              let thumbnail = item.thumbnail, thumbnail.hasPrefix("https://"),
              let license = item.license?.lowercased(), allowedLicenses.contains(license),
              item.mature != true else { return nil }
        if let type = item.filetype?.lowercased(), !type.isEmpty, type != "jpg", type != "jpeg", type != "png" {
            return nil
        }
        if let width = item.width, let height = item.height, width > 0, height > 0 {
            guard min(width, height) >= 160 else { return nil }
            let ratio = Double(max(width, height)) / Double(min(width, height))
            guard ratio <= 2.4 else { return nil }
        }
        return WordImageRecord(
            id: id,
            title: item.title ?? "",
            thumbnailURL: thumbnail,
            originalURL: item.url ?? "",
            landingURL: item.foreign_landing_url ?? "",
            creator: item.creator ?? "",
            creatorURL: item.creator_url,
            license: license,
            licenseVersion: item.license_version ?? "",
            licenseURL: item.license_url ?? "",
            provider: item.provider ?? item.source ?? "",
            service: "openverse"
        )
    }

    /// JPEG (`FF D8 FF`) or PNG (`89 50 4E 47`) signature.
    static func isImageData(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(4))
        guard bytes.count == 4 else { return false }
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF { return true }
        return bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47
    }

    // MARK: Network

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                // The prefetch task was cancelled (app in the background) — not an error.
                throw CancellationError()
            case .timedOut:
                // One slow answer (searches sometimes take 4–7 s) skips the word, not the whole run.
                throw WordImageError.timedOut
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw WordImageError.offline
            default:
                throw WordImageError.invalidResponse
            }
        }
        let data = result.0
        guard let http = result.1 as? HTTPURLResponse else { throw WordImageError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return data
        case 429:
            let header = http.value(forHTTPHeaderField: "Retry-After") ?? ""
            let seconds = TimeInterval(header) ?? 3_600
            throw WordImageError.rateLimited(retryAfter: max(60, min(seconds, 86_400)))
        default:
            throw WordImageError.http(http.statusCode)
        }
    }
}
