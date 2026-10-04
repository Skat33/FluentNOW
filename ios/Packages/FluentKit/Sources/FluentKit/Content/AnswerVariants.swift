import Foundation

/// Reviewed answer variants (`answer-variants.json`, web `lib/answer-variants.ts` + aliases from
/// `tutor-local.ts`). Inject the decoded file into grading; `AnswerVariants.builtIn` is a complete
/// copy of the web v42 data so grading works without content files (tests, first launch).
public struct AnswerVariants: Codable, Sendable, Hashable {
    /// Polish variants of one specific sense of an English term.
    public struct SenseVariants: Codable, Sendable, Hashable {
        public var term: String
        public var variants: [String]

        public init(term: String, variants: [String]) {
            self.term = term
            self.variants = variants
        }
    }

    public var schemaVersion: Int
    public var polishSenseVariants: [SenseVariants]
    /// Perfective / imperfective pairs, e.g. `["kupić", "kupować"]`.
    public var polishAspectPairs: [[String]]
    /// Accepted English recall variants for starter senses (e.g. `lend` → `lend someone`).
    public var englishAliases: [String: [String]]

    public init(schemaVersion: Int = 1, polishSenseVariants: [SenseVariants] = [], polishAspectPairs: [[String]] = [], englishAliases: [String: [String]] = [:]) {
        self.schemaVersion = schemaVersion
        self.polishSenseVariants = polishSenseVariants
        self.polishAspectPairs = polishAspectPairs
        self.englishAliases = englishAliases
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, polishSenseVariants, polishAspectPairs, englishAliases
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        polishSenseVariants = c.lossyArray(SenseVariants.self, forKey: .polishSenseVariants)
        polishAspectPairs = c.lossyArray([String].self, forKey: .polishAspectPairs)
        englishAliases = (try? c.decodeIfPresent([String: [String]].self, forKey: .englishAliases)) ?? [:]
    }

    /// Complete built-in copy of the web v42 lists.
    public static let builtIn = AnswerVariants(
        polishSenseVariants: [
            SenseVariants(term: "borrow", variants: ["pożyczyć od kogoś", "pożyczać od kogoś", "pożyczyć", "pożyczać", "wypożyczyć", "wypożyczać"]),
            SenseVariants(term: "lend", variants: ["pożyczyć komuś", "pożyczać komuś", "pożyczyć", "pożyczać", "udzielić pożyczki", "udzielać pożyczki"]),
            SenseVariants(term: "bank", variants: ["brzeg rzeki", "brzeg", "brzeg rzeczny"]),
            SenseVariants(term: "bank", variants: ["bank", "bank finansowy", "instytucja finansowa"]),
            SenseVariants(term: "say", variants: ["powiedzieć coś", "mówić coś", "powiedzieć", "mówić"]),
            SenseVariants(term: "tell", variants: ["powiedzieć", "powiedzieć coś", "mówić", "powiedzieć komuś", "powiedzieć komuś coś", "powiedzieć coś komuś", "mówić komuś", "mówić komuś coś", "poinformować", "poinformować kogoś"]),
            SenseVariants(term: "tell", variants: ["opowiedzieć", "opowiadać", "opowiedzieć historię", "opowiadać historię"]),
            SenseVariants(term: "do", variants: ["robić", "zrobić", "wykonywać", "wykonać"]),
            SenseVariants(term: "do", variants: ["wystarczyć", "wystarczać", "nadawać się"]),
            SenseVariants(term: "make", variants: ["robić", "zrobić", "tworzyć", "stworzyć", "wytwarzać", "wytworzyć"]),
            SenseVariants(term: "recommend", variants: ["polecić", "polecać", "rekomendować", "zalecać", "zalecić"]),
            SenseVariants(term: "accomplish", variants: ["osiągnąć", "osiągać", "dokonać", "zrealizować", "realizować"]),
            SenseVariants(term: "achieve", variants: ["osiągnąć", "osiągać", "zrealizować", "realizować"]),
            SenseVariants(term: "reservation", variants: ["rezerwacja", "zarezerwowanie"]),
            SenseVariants(term: "appointment", variants: ["umówiona wizyta", "umówiona wizyta u lekarza", "wizyta", "termin wizyty"]),
            SenseVariants(term: "appointment", variants: ["umówione spotkanie", "spotkanie", "termin spotkania"]),
            SenseVariants(term: "deadline", variants: ["termin", "termin wykonania", "termin końcowy", "ostateczny termin", "termin ostateczny"]),
            SenseVariants(term: "boarding pass", variants: ["karta pokładowa", "bilet pokładowy"]),
            SenseVariants(term: "luggage", variants: ["bagaż", "bagaże"]),
            SenseVariants(term: "baggage", variants: ["bagaż", "bagaże"]),
            SenseVariants(term: "gate", variants: ["bramka", "bramka do wejścia na pokład", "wyjście do samolotu", "bramka wejściowa"]),
            SenseVariants(term: "check-in", variants: ["odprawa", "odprawa pasażerska", "odprawa na lotnisku"]),
            SenseVariants(term: "bill", variants: ["rachunek", "rachunek do zapłaty"]),
            SenseVariants(term: "check", variants: ["rachunek", "rachunek do zapłaty"]),
            SenseVariants(term: "check", variants: ["sprawdzić", "sprawdzać", "skontrolować", "kontrolować"]),
            SenseVariants(term: "receipt", variants: ["paragon", "potwierdzenie zapłaty", "pokwitowanie"]),
            SenseVariants(term: "cutlery", variants: ["sztućce"]),
            SenseVariants(term: "silverware", variants: ["sztućce", "srebrne sztućce"]),
            SenseVariants(term: "get the hang of", variants: ["załapać, jak to działa", "załapać jak to działa", "załapać", "nabrać wprawy", "opanować", "załapać o co chodzi"]),
            SenseVariants(term: "take your time", variants: ["nie spiesz się", "nie spieszyć się", "bez pośpiechu", "nie śpiesz się", "nie śpieszyć się"]),
            SenseVariants(term: "it depends", variants: ["to zależy", "zależy"]),
            SenseVariants(term: "figure out", variants: ["rozgryźć", "rozgryzać", "zrozumieć", "ustalić", "dojść do czegoś"]),
            SenseVariants(term: "look for", variants: ["szukać", "poszukiwać"]),
            SenseVariants(term: "look after", variants: ["opiekować się", "zaopiekować się", "dbać o", "troszczyć się o"]),
            SenseVariants(term: "give up", variants: ["poddać się", "poddawać się", "zrezygnować", "rezygnować"]),
            SenseVariants(term: "turn down", variants: ["odrzucić", "odrzucać", "odmówić", "odmawiać"]),
            SenseVariants(term: "turn down", variants: ["ściszyć", "ściszać", "zmniejszyć głośność", "zmniejszać głośność"]),
            SenseVariants(term: "break the ice", variants: ["przełamać lody", "przełamywać lody"]),
            SenseVariants(term: "once in a blue moon", variants: ["bardzo rzadko", "od wielkiego dzwonu", "raz na ruski rok"]),
            SenseVariants(term: "under the weather", variants: ["czuć się niewyraźnie", "źle się czuć", "czuć się źle", "nie czuć się dobrze"]),
            SenseVariants(term: "a piece of cake", variants: ["bułka z masłem", "łatwizna", "coś bardzo łatwego", "bardzo łatwe"])
        ],
        polishAspectPairs: [
            ["kupić", "kupować"], ["sprzedać", "sprzedawać"], ["zapłacić", "płacić"], ["pomóc", "pomagać"],
            ["przybyć", "przybywać"], ["przyjechać", "przyjeżdżać"], ["wyjść", "wychodzić"], ["opuścić", "opuszczać"],
            ["wejść", "wchodzić"], ["wrócić", "wracać"], ["otworzyć", "otwierać"], ["zamknąć", "zamykać"],
            ["przeczytać", "czytać"], ["napisać", "pisać"], ["odpowiedzieć", "odpowiadać"], ["zapytać", "pytać"],
            ["zrozumieć", "rozumieć"], ["zapomnieć", "zapominać"], ["nauczyć się", "uczyć się"],
            ["wybrać", "wybierać"], ["zdecydować", "decydować"], ["zdecydować się", "decydować się"],
            ["zarezerwować", "rezerwować"], ["zamówić", "zamawiać"], ["odwołać", "odwoływać"], ["potwierdzić", "potwierdzać"],
            ["sprawdzić", "sprawdzać"], ["wyjaśnić", "wyjaśniać"], ["zmienić", "zmieniać"], ["poprawić", "poprawiać"],
            ["przygotować", "przygotowywać"], ["skończyć", "kończyć"], ["rozpocząć", "rozpoczynać"], ["zacząć", "zaczynać"],
            ["otrzymać", "otrzymywać"], ["dostać", "dostawać"], ["wysłać", "wysyłać"], ["przynieść", "przynosić"],
            ["zabrać", "zabierać"], ["oddać", "oddawać"], ["zwrócić", "zwracać"], ["zgubić", "gubić"],
            ["zjeść", "jeść"], ["wypić", "pić"], ["ugotować", "gotować"], ["upiec", "piec"],
            ["posprzątać", "sprzątać"], ["umyć", "myć"], ["naprawić", "naprawiać"], ["zepsuć", "psuć"],
            ["odwiedzić", "odwiedzać"], ["spotkać", "spotykać"], ["poczekać", "czekać"], ["spróbować", "próbować"],
            ["uniknąć", "unikać"], ["osiągnąć", "osiągać"], ["zaoferować", "oferować"], ["zgodzić się", "zgadzać się"],
            ["odmówić", "odmawiać"], ["zauważyć", "zauważać"], ["zaprosić", "zapraszać"], ["przeprosić", "przepraszać"]
        ],
        englishAliases: [
            "lend": ["lend someone", "lend somebody", "lend something to someone", "lend something to somebody"],
            "borrow": ["borrow something", "borrow something from someone", "borrow from someone"],
            "tell": ["tell someone", "tell somebody", "tell someone something"],
            "say": ["say something"],
            "do": ["to do"],
            "make": ["to make"]
        ]
    )
}
