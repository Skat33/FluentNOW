import Foundation

/// One sense of an ambiguous word: how to search for it and what Vision should see.
struct WordImageSense: Sendable, Equatable {
    /// Topic files that select this sense.
    var topics: Set<String>
    /// Folded Polish substrings of the translation that select this sense („myszk”, „nietoperz”).
    var polishCues: [String]
    var query: String
    var subject: WordImageSubject
    /// Vision identifiers that confirm this sense.
    var labels: [String]
    /// Broader identifiers (accepted with a strong title/tag match).
    var related: [String]
    /// Title/tag words of the other senses.
    var avoid: [String]
    /// Query of the last attempt.
    var alternative: String?
    /// This sense cannot be photographed (Polish reason).
    var excluded: String?

    init(
        topics: [String] = [],
        polish: [String] = [],
        query: String,
        subject: WordImageSubject = .object,
        labels: [String] = [],
        related: [String] = [],
        avoid: [String] = [],
        alternative: String? = nil,
        excluded: String? = nil
    ) {
        self.topics = Set(topics)
        self.polishCues = polish
        self.query = query
        self.subject = subject
        self.labels = labels
        self.related = related
        self.avoid = avoid
        self.alternative = alternative
        self.excluded = excluded
    }
}

/// Ambiguous English nouns of the built-in topics (verified on live Openverse data on
/// 2026-10-18: „mouse” alone returns Mickey Mouse, „bat” the Hubble „Bat Shadow”, „apple” on
/// stock sources mostly Apple computers). Sense = topic file first, then a Polish cue, then the
/// first entry.
enum WordImageSenses {
    static func sense(for term: String, context: WordImageContext?) -> WordImageSense? {
        guard let senses = table[term], let first = senses.first else { return nil }
        if let topic = context?.topic?.lowercased(), !topic.isEmpty,
           let byTopic = senses.first(where: { (sense: WordImageSense) -> Bool in sense.topics.contains(topic) }) {
            return byTopic
        }
        let polish = WordImageText.foldPolish(context?.translation ?? "")
        if !polish.isEmpty {
            let byPolish = senses.first { (sense: WordImageSense) -> Bool in
                sense.polishCues.contains { (cue: String) -> Bool in polish.contains(cue) }
            }
            if let byPolish { return byPolish }
        }
        return first
    }

    private static let appleBrand = [
        "mac", "macbook", "macbookair", "macbookpro", "iphone", "ipad", "imac", "macintosh", "laptop",
        "computer", "keyboard", "logo", "store", "airpods", "ios", "fatmac", "watch"
    ]

    private static let personExcluded = "Osoba — na zdjęciu niejednoznaczna."

    private static let entries: [(String, [WordImageSense])] = [
        ("apple", [
            WordImageSense(query: "apple fruit", subject: .food, labels: ["apple"], related: ["fruit", "food"], avoid: appleBrand, alternative: "red apple")
        ]),
        ("mouse", [
            WordImageSense(topics: ["computers-internet", "office-work", "smartphones-apps", "school"], polish: ["komputer", "myszk"], query: "computer mouse", labels: ["computer_mouse"], related: ["computer", "consumer_electronics"], avoid: ["mickey", "minnie", "disney", "lemur", "rodent", "rat", "wildlife", "animal", "whisker", "fur", "pest"], alternative: "mouse computer"),
            WordImageSense(topics: ["animals", "pets", "farming-countryside"], polish: ["mysz", "gryzon"], query: "mouse rodent", subject: .animal, labels: ["rodent", "rat", "hamster", "gerbil"], related: ["mammal", "animal"], avoid: ["mickey", "minnie", "disney", "computer", "keyboard", "laptop", "lemur", "bird"], alternative: "field mouse")
        ]),
        ("bat", [
            WordImageSense(topics: ["sports", "fitness-gym", "football"], polish: ["kij"], query: "baseball bat", labels: ["baseball_bat"], related: ["baseball", "sports_equipment"], avoid: ["cactus", "shadow", "nebula", "hubble", "animal"]),
            WordImageSense(topics: ["animals", "pets", "nature-landscape", "holidays-traditions"], polish: ["nietoperz"], query: "bat", subject: .animal, related: ["mammal", "animal"], avoid: ["baseball", "cactus", "shadow", "nebula", "hubble", "batman", "toy", "ikea", "halloween"], alternative: "fruit bat")
        ]),
        ("crane", [
            WordImageSense(topics: ["repairs-diy", "city-life", "moving-house", "natural-disasters"], polish: ["dzwig"], query: "construction crane", labels: ["crane_construction"], related: ["machine", "structure", "vehicle"], avoid: ["bird", "paper", "origami"], alternative: "tower crane"),
            WordImageSense(topics: ["animals", "farming-countryside", "nature-landscape"], polish: ["zuraw"], query: "crane bird", subject: .animal, related: ["bird", "heron", "stork"], avoid: ["construction", "industrial", "tower", "harbor", "paper", "origami"], alternative: "common crane")
        ]),
        ("pen", [
            WordImageSense(polish: ["dlugopis", "pioro"], query: "pen", labels: ["pen"], related: ["office_supplies"], avoid: ["olympus", "camera", "penee", "llyn", "snowdonia"], alternative: "ballpoint pen"),
            WordImageSense(topics: ["farming-countryside", "animals"], polish: ["kojec", "zagrod"], query: "animal pen enclosure", subject: .place, related: ["fence", "farm"])
        ]),
        ("phone", [
            WordImageSense(query: "phone", labels: ["phone", "payphone"], related: ["consumer_electronics"], alternative: "telephone")
        ]),
        ("glasses", [
            WordImageSense(topics: ["clothes-fashion", "shopping-clothes", "body-parts"], polish: ["okular"], query: "eyeglasses", subject: .wearable, labels: ["eyeglasses", "sunglasses"], alternative: "spectacles"),
            WordImageSense(topics: ["drinks-bar", "restaurant", "cafe-bakery", "parties-celebrations"], polish: ["szklank", "kieliszk"], query: "drinking glasses", labels: ["drinking_glass"], related: ["tableware"])
        ]),
        ("glass", [
            WordImageSense(polish: ["szklank", "kieliszk"], query: "drinking glass", labels: ["drinking_glass"], related: ["tableware"]),
            WordImageSense(topics: ["materials-objects"], polish: ["szklo"], query: "glass material", labels: ["raw_glass"])
        ]),
        ("nail", [
            WordImageSense(topics: ["repairs-diy", "materials-objects"], polish: ["gwozdz"], query: "metal nails hardware", related: ["tool"]),
            WordImageSense(topics: ["beauty-hairdresser", "body-parts"], polish: ["paznok"], query: "fingernails manicure", subject: .person)
        ]),
        ("keyboard", [
            WordImageSense(topics: ["computers-internet", "office-work", "smartphones-apps"], polish: ["klawiatur"], query: "computer keyboard", labels: ["computer_keyboard"], related: ["computer"]),
            WordImageSense(topics: ["music", "concerts-festivals"], polish: ["instrument", "syntezator"], query: "electronic keyboard instrument", subject: .artwork, labels: ["piano", "organ_instrument", "musical_instrument"])
        ]),
        ("seal", [
            WordImageSense(topics: ["animals", "beach-vacation"], polish: ["foka"], query: "seal animal", subject: .animal, labels: ["seal", "sealion"], related: ["mammal", "animal"]),
            WordImageSense(polish: ["pieczec", "uszczel"], query: "seal", excluded: "Pieczęć / uszczelka — trudno pokazać jednoznacznie.")
        ]),
        ("trunk", [
            WordImageSense(topics: ["car-problems", "car-rental", "driving"], polish: ["bagaznik"], query: "car trunk open", related: ["car", "automobile"]),
            WordImageSense(topics: ["garden-plants", "nature-landscape", "camping-hiking"], polish: ["pien"], query: "tree trunk", subject: .plant, related: ["tree", "wood_natural"]),
            WordImageSense(polish: ["kufer", "skrzyni"], query: "trunk luggage chest", labels: ["luggage", "suitcase", "crate"]),
            WordImageSense(topics: ["animals"], polish: ["traba"], query: "elephant trunk", subject: .animal, labels: ["elephant"])
        ]),
        ("ring", [
            WordImageSense(topics: ["wedding", "clothes-fashion", "shopping-mall", "shopping-clothes"], polish: ["pierscion", "obraczk"], query: "ring jewelry", subject: .wearable, labels: ["jewelry"]),
            WordImageSense(topics: ["sports"], polish: ["ring"], query: "boxing ring", subject: .place, labels: ["boxing"])
        ]),
        ("fan", [
            WordImageSense(topics: ["furniture-household", "house-rooms", "weather"], polish: ["wentylator", "wiatrak"], query: "electric fan", labels: ["electric_fan"], related: ["appliance"]),
            WordImageSense(topics: ["sports", "football", "concerts-festivals"], polish: ["kibic", "fan", "wielbiciel"], query: "fan", excluded: personExcluded)
        ]),
        ("jam", [
            WordImageSense(polish: ["dzem", "konfitur", "powidl"], query: "jam jar", subject: .food, related: ["jar", "food"]),
            WordImageSense(topics: ["driving", "city-life"], polish: ["korek"], query: "traffic jam", excluded: "Korek uliczny — nie jest przedmiotem.")
        ]),
        ("pepper", [
            WordImageSense(topics: ["fruits-vegetables"], polish: ["papryk"], query: "bell pepper", subject: .food, labels: ["bell_pepper", "pepper_veggie"], related: ["vegetable", "food"]),
            WordImageSense(polish: ["pieprz"], query: "black pepper spice", subject: .food, labels: ["spice", "seasonings"], related: ["food"])
        ]),
        ("orange", [
            WordImageSense(topics: ["fruits-vegetables", "grocery-shopping", "drinks-bar"], polish: ["pomarancza", "pomarancze", "pomaranczy"], query: "orange fruit", subject: .food, labels: ["oranges", "citrus_fruit", "mandarine"], related: ["fruit", "food"]),
            WordImageSense(topics: ["colors-shapes-sizes"], polish: ["pomaranczow", "kolor"], query: "orange", excluded: "Kolor — nie da się pokazać jednym zdjęciem.")
        ]),
        ("kiwi", [
            WordImageSense(topics: ["fruits-vegetables", "grocery-shopping"], polish: ["owoc"], query: "kiwi fruit", subject: .food, labels: ["kiwi"], related: ["fruit", "food"]),
            WordImageSense(topics: ["animals"], polish: ["ptak"], query: "kiwi bird", subject: .animal, related: ["bird", "animal"])
        ]),
        ("date", [
            WordImageSense(topics: ["fruits-vegetables", "grocery-shopping"], polish: ["daktyl"], query: "dates fruit", subject: .food, related: ["fruit", "food"]),
            WordImageSense(polish: ["randk", "data"], query: "date", excluded: "Data / randka — abstrakcja.")
        ]),
        ("fly", [
            WordImageSense(polish: ["much"], query: "housefly insect", subject: .animal, related: ["insect", "animal"])
        ]),
        ("letter", [
            WordImageSense(topics: ["post-office"], polish: ["list"], query: "letter envelope mail", labels: ["envelope"], related: ["document"]),
            WordImageSense(polish: ["liter"], query: "letter", excluded: "Litera — abstrakcja.")
        ]),
        ("chips", [
            WordImageSense(polish: ["czips", "chips"], query: "potato chips", subject: .food, related: ["food"]),
            WordImageSense(polish: ["frytk"], query: "french fries", subject: .food, labels: ["fries"], related: ["food"])
        ]),
        ("boot", [
            WordImageSense(topics: ["clothes-fashion", "shopping-clothes", "camping-hiking"], polish: ["but", "kozak", "kalosz"], query: "boot footwear", subject: .wearable, labels: ["boot", "footwear"], related: ["shoes"]),
            WordImageSense(topics: ["car-problems", "car-rental", "driving"], polish: ["bagaznik"], query: "car trunk open", related: ["car", "automobile"])
        ]),
        ("coach", [
            WordImageSense(topics: ["public-transport", "train-travel", "airport"], polish: ["autokar"], query: "coach bus", labels: ["bus"], related: ["vehicle"]),
            WordImageSense(topics: ["sports", "football", "fitness-gym"], polish: ["trener"], query: "coach", excluded: personExcluded)
        ]),
        ("pitcher", [
            WordImageSense(polish: ["dzban"], query: "water pitcher jug", labels: ["jug", "decanter"], related: ["container"]),
            WordImageSense(topics: ["sports"], polish: ["miotacz"], query: "pitcher", excluded: personExcluded)
        ]),
        ("palm", [
            WordImageSense(topics: ["garden-plants", "beach-vacation", "nature-landscape"], polish: ["palm"], query: "palm tree", subject: .plant, labels: ["palm_tree"], related: ["tree", "plant"]),
            WordImageSense(topics: ["body-parts"], polish: ["dlon"], query: "palm of hand", subject: .person)
        ]),
        ("pool", [
            WordImageSense(polish: ["basen"], query: "swimming pool", subject: .place, labels: ["pool"], related: ["water"]),
            WordImageSense(polish: ["bilard"], query: "pool table billiards", labels: ["billiards"])
        ]),
        ("tap", [
            WordImageSense(polish: ["kran"], query: "water tap faucet", labels: ["bathroom_faucet", "kitchen_faucet"], related: ["washbasin", "kitchen_sink"])
        ]),
        ("iron", [
            WordImageSense(polish: ["zelazko"], query: "clothes iron", labels: ["iron_clothing"], related: ["appliance"]),
            WordImageSense(topics: ["materials-objects"], polish: ["zelazo"], query: "iron", excluded: "Materiał (żelazo) — trudno pokazać jednoznacznie.")
        ]),
        ("organ", [
            WordImageSense(topics: ["music", "concerts-festivals", "wedding"], polish: ["organy"], query: "pipe organ", subject: .artwork, labels: ["organ_instrument"], related: ["musical_instrument"]),
            WordImageSense(polish: ["narzad"], query: "organ", excluded: "Narząd — zdjęcie byłoby niejednoznaczne.")
        ]),
        ("deck", [
            WordImageSense(topics: ["board-games-puzzles", "hobbies-crafts"], polish: ["talia"], query: "deck of playing cards", labels: ["play_card"], related: ["games"]),
            WordImageSense(polish: ["poklad", "taras"], query: "wooden deck", subject: .place, labels: ["deck"], related: ["patio", "porch"])
        ]),
        ("club", [
            WordImageSense(topics: ["sports"], polish: ["kij"], query: "golf club", labels: ["golf_club"], related: ["golf"]),
            WordImageSense(polish: ["klub"], query: "club", excluded: "Klub — miejsce/organizacja, abstrakcja.")
        ]),
        ("bill", [
            WordImageSense(polish: ["rachun", "banknot", "faktur"], query: "bill", excluded: "Rachunek — wygląda jak każda kartka."),
            WordImageSense(topics: ["animals"], polish: ["dziob"], query: "bird beak", subject: .animal, related: ["bird"])
        ]),
        ("cloud", [
            WordImageSense(topics: ["computers-internet", "smartphones-apps", "office-work"], query: "cloud", excluded: "Chmura obliczeniowa — abstrakcja."),
            WordImageSense(polish: ["chmur"], query: "clouds sky", subject: .place, labels: ["cloudy"], related: ["sky", "blue_sky"])
        ]),
        ("bulb", [
            WordImageSense(topics: ["garden-plants"], polish: ["cebul"], query: "flower bulbs", subject: .plant, related: ["plant", "vegetable"]),
            WordImageSense(polish: ["zarow"], query: "light bulb", labels: ["light_bulb"], related: ["light", "lamp"])
        ]),
        ("spring", [
            WordImageSense(topics: ["weather", "holidays-traditions", "garden-plants"], polish: ["wiosn"], query: "spring", excluded: "Pora roku — abstrakcja."),
            WordImageSense(polish: ["sprezyn"], query: "metal coil spring", related: ["tool"]),
            WordImageSense(polish: ["zrodl"], query: "water spring source", subject: .place, related: ["water", "creek"])
        ]),
        ("squash", [
            WordImageSense(topics: ["sports", "fitness-gym"], polish: ["squash"], query: "squash racket court", labels: ["squash_sport"], related: ["sport"]),
            WordImageSense(topics: ["fruits-vegetables"], polish: ["dyni", "kabacz"], query: "squash vegetable", subject: .food, labels: ["pumpkin", "zucchini"], related: ["vegetable", "food"])
        ]),
        ("bank", [
            WordImageSense(topics: ["nature-landscape", "camping-hiking", "farming-countryside"], polish: ["brzeg"], query: "river bank", subject: .place, related: ["river", "water_body"]),
            WordImageSense(polish: ["bank"], query: "bank building", subject: .place, related: ["building", "structure"])
        ]),
        ("plant", [
            WordImageSense(polish: ["rosli", "kwiat"], query: "potted plant", subject: .plant, labels: ["plant", "decorative_plant"], related: ["flower", "vegetation"]),
            WordImageSense(polish: ["fabryk", "zaklad"], query: "industrial plant factory", subject: .place, related: ["building", "smokestack"])
        ]),
        ("chest", [
            WordImageSense(polish: ["skrzyn", "kufer"], query: "wooden chest box", labels: ["crate"], related: ["furniture", "container"]),
            WordImageSense(polish: ["komod"], query: "chest of drawers", labels: ["cabinet"], related: ["furniture"]),
            WordImageSense(topics: ["body-parts", "hospital-emergency"], polish: ["klatk", "piers"], query: "chest", excluded: "Część ciała — zdjęcie byłoby niejednoznaczne.")
        ]),
        ("mole", [
            WordImageSense(topics: ["animals", "garden-plants"], polish: ["kret"], query: "mole animal", subject: .animal, related: ["mammal", "animal"]),
            WordImageSense(polish: ["pieprzyk", "znamie"], query: "mole", excluded: "Znamię — nie pokazujemy zdjęć skóry.")
        ]),
        ("bark", [
            WordImageSense(polish: ["kora"], query: "tree bark", subject: .plant, related: ["tree", "wood_natural"]),
            WordImageSense(polish: ["szczek"], query: "bark", excluded: "Dźwięk — nie da się pokazać.")
        ]),
        ("can", [
            WordImageSense(polish: ["puszk"], query: "tin can", related: ["container"])
        ]),
        ("rubber", [
            WordImageSense(polish: ["gumk"], query: "pencil eraser", related: ["office_supplies"]),
            WordImageSense(polish: ["guma"], query: "rubber", excluded: "Materiał — trudno pokazać jednoznacznie.")
        ]),
        ("cap", [
            WordImageSense(polish: ["czapk"], query: "baseball cap", subject: .wearable, labels: ["baseball_hat"], related: ["headgear", "hat"]),
            WordImageSense(polish: ["nakretk", "kapsel", "zakretk"], query: "bottle cap", related: ["bottle"])
        ]),
        ("hood", [
            WordImageSense(topics: ["clothes-fashion", "shopping-clothes"], polish: ["kaptur"], query: "hooded sweatshirt hood", subject: .wearable, labels: ["hoodie"], related: ["clothing"]),
            WordImageSense(topics: ["car-problems", "driving", "car-rental"], polish: ["maska"], query: "car hood open", related: ["car", "automobile", "engine_vehicle"])
        ]),
        ("chicken", [
            WordImageSense(topics: ["meat-fish-dairy", "cooking", "fast-food-takeaway", "restaurant", "grocery-shopping"], polish: ["kurczak", "drob"], query: "roast chicken", subject: .food, labels: ["grilled_chicken", "fried_chicken", "poultry", "rotisserie"], related: ["meat", "food"]),
            WordImageSense(topics: ["animals", "farming-countryside", "pets"], polish: ["kura", "kogut"], query: "chicken hen", subject: .animal, labels: ["poultry"], related: ["bird", "animal"])
        ]),
        ("fish", [
            WordImageSense(topics: ["animals", "pets", "beach-vacation"], query: "fish swimming", subject: .animal, labels: ["fish", "goldfish", "koi", "guppy"], related: ["animal", "underwater"]),
            WordImageSense(topics: ["meat-fish-dairy", "cooking", "restaurant", "grocery-shopping", "fast-food-takeaway"], query: "fish fillet food", subject: .food, labels: ["seafood", "fish", "salmon"], related: ["food", "meat"])
        ]),
        ("lamb", [
            WordImageSense(topics: ["animals", "farming-countryside"], polish: ["owiecz", "jagni"], query: "lamb animal", subject: .animal, labels: ["sheep"], related: ["animal", "mammal"]),
            WordImageSense(topics: ["meat-fish-dairy", "cooking", "restaurant"], polish: ["baranin", "jagniecin"], query: "lamb meat", subject: .food, labels: ["meat", "steak"], related: ["food"])
        ]),
        ("turkey", [
            WordImageSense(topics: ["animals", "farming-countryside"], query: "turkey bird", subject: .animal, labels: ["poultry"], related: ["bird", "animal"]),
            WordImageSense(topics: ["meat-fish-dairy", "cooking", "holidays-traditions", "restaurant"], query: "roast turkey", subject: .food, labels: ["poultry", "rotisserie"], related: ["meat", "food"])
        ]),
        ("watch", [
            WordImageSense(query: "wristwatch", subject: .wearable, labels: ["watch", "timepiece"], related: ["jewelry"])
        ]),
        ("screen", [
            WordImageSense(query: "computer screen", labels: ["computer_monitor", "television"], related: ["computer", "consumer_electronics"])
        ]),
        ("monitor", [
            WordImageSense(query: "computer monitor", labels: ["computer_monitor"], related: ["computer", "consumer_electronics"])
        ]),
        ("remote", [
            WordImageSense(query: "remote control", related: ["consumer_electronics"])
        ]),
        ("pants", [
            WordImageSense(query: "pants trousers", subject: .wearable, labels: ["jeans"], related: ["clothing"])
        ]),
        ("jumper", [
            WordImageSense(query: "sweater jumper", subject: .wearable, related: ["clothing"])
        ]),
        ("cooker", [
            WordImageSense(query: "kitchen stove", labels: ["stove", "kitchen_oven"], related: ["appliance", "kitchen"])
        ]),
        ("trainers", [
            WordImageSense(query: "sneakers", subject: .wearable, labels: ["sneaker", "footwear", "shoes"])
        ])
    ]

    static let table: [String: [WordImageSense]] = Dictionary(
        entries,
        uniquingKeysWith: { (first: [WordImageSense], _: [WordImageSense]) -> [WordImageSense] in first }
    )
}
