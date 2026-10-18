import Foundation

/// Mapping between dictionary nouns and the identifiers of Vision's image classifier
/// (`VNClassifyImageRequest`, revisions 1–2 share one taxonomy of 1 303 identifiers such as
/// `phone`, `computer_mouse`, `baseball_bat`, `crane_construction`, `insect`, `people`).
/// Every identifier below was checked against a dump of `supportedIdentifiers()`; at run time
/// only identifiers present in the device taxonomy count (`WordImageVerifier`).
enum WordImageVisionLabels {
    // MARK: Term → identifiers

    private static let mapSource = """
        phone: phone, payphone
        telephone: phone, payphone
        cell phone: phone
        cellphone: phone
        mobile phone: phone
        smartphone: phone
        mobile: phone
        payphone: payphone, phone
        laptop: laptop, computer
        computer: computer, laptop, computer_monitor, computer_tower
        desktop computer: computer, computer_monitor, computer_tower
        computer mouse: computer_mouse
        keyboard: computer_keyboard
        monitor: computer_monitor
        tablet: computer, consumer_electronics
        printer: printer
        headphones: headphones
        earphones: headphones
        speaker: speakers_music
        speakers: speakers_music
        camera: camera
        television: television
        tv: television
        tv set: television
        remote control: consumer_electronics
        microphone: microphone
        calculator: calculator
        joystick: joystick, gamepad
        game controller: gamepad, joystick
        charger: cord, consumer_electronics
        cable: cord
        flash drive: consumer_electronics
        light bulb: light_bulb
        lamp: lamp, light
        flashlight: flashlight
        torch: flashlight
        battery: consumer_electronics
        drone: drone_machine
        typewriter: typewriter
        chair: chair, armchair, folding_chair, swivel_chair, chair_other, high_chair
        armchair: armchair, chair
        stool: stool
        bench: bench
        sofa: sofa
        couch: sofa
        table: table, desk
        desk: desk, table
        bed: bed, bedding
        pillow: pillow
        blanket: bedding
        duvet: bedding
        wardrobe: closet, cabinet
        closet: closet
        cupboard: cabinet
        cabinet: cabinet
        bookshelf: bookshelf
        bookcase: bookshelf
        shelf: bookshelf, cabinet
        curtain: curtain
        curtains: curtain
        door: door
        window: window
        stairs: stairs
        staircase: stairs
        elevator: elevator
        lift: elevator
        escalator: escalator
        roof: roof
        chimney: chimney
        fireplace: fireplace
        garage: garage
        balcony: balcony
        fence: fence
        mailbox: mailbox
        vase: vase
        candle: candle
        clock: clock, timepiece
        mirror: frame
        picture frame: frame
        chandelier: chandelier
        rug: textile
        carpet: textile
        toilet: toilet_seat
        bathtub: bath
        bath: bath
        tub: bath
        shower: shower
        sink: kitchen_sink, washbasin
        washbasin: washbasin
        faucet: bathroom_faucet, kitchen_faucet
        fridge: refrigerator
        refrigerator: refrigerator
        oven: oven, kitchen_oven
        stove: stove, kitchen_oven
        microwave: microwave
        toaster: toaster, toaster_oven
        kettle: kettle
        blender: blender
        dishwasher: dishwasher
        washing machine: laundry_machine
        dryer: laundry_machine
        vacuum cleaner: vacuum
        vacuum: vacuum
        broom: broom
        mop: mop
        bucket: bucket
        iron: iron_clothing
        ironing board: iron_clothing
        electric fan: electric_fan
        trash can: trash_can
        garbage can: trash_can
        bin: trash_can
        thermostat: thermostat
        smoke detector: appliance
        fire extinguisher: extinguisher
        extinguisher: extinguisher
        ladder: tool
        hammer: hammer
        screwdriver: screwdriver
        wrench: wrench
        pliers: pliers
        saw: power_saw, tool
        drill: tool
        toolbox: toolbox
        tape measure: measuring_tape
        measuring tape: measuring_tape
        axe: axe
        rake: rake
        shovel: tool
        wheelbarrow: wheelbarrow
        watering can: watering_can
        lawn mower: mower
        hose: sprinkler
        rope: rope
        scissors: scissors
        cup: cup, mug
        mug: mug, cup
        plate: plate, tableware
        bowl: bowl
        fork: fork, utensil
        spoon: spoon, utensil
        knife: knife, utensil
        chopsticks: chopsticks
        pan: pan, cookware
        frying pan: pan, cookware
        pot: pot_cooking, cookware
        saucepan: pot_cooking, cookware
        teapot: teapot
        jug: jug
        bottle: bottle, wine_bottle
        jar: jar
        glass: drinking_glass
        wine glass: drinking_glass
        cutting board: cutting_board
        rolling pin: rolling_pin
        whisk: whisk
        ladle: ladle
        spatula: spatula
        grater: grater
        corkscrew: corkscrew
        thermos: thermos
        napkin: tableware
        tray: tableware
        bag: bag, purse
        handbag: purse, bag
        purse: purse, wallet
        wallet: wallet
        backpack: backpack
        rucksack: backpack
        suitcase: suitcase, luggage
        luggage: luggage, suitcase
        briefcase: briefcase
        umbrella: umbrella
        glasses: eyeglasses
        eyeglasses: eyeglasses
        sunglasses: sunglasses
        watch: watch, timepiece
        wristwatch: watch, timepiece
        ring: jewelry
        necklace: jewelry
        earrings: jewelry
        bracelet: jewelry
        jewelry: jewelry
        hat: hat, fedora, sunhat, cowboy_hat
        cap: baseball_hat
        beanie: beanie
        helmet: helmet, hardhat
        scarf: scarf
        gloves: glove
        glove: glove
        mittens: mitten
        tie: necktie
        necktie: necktie
        bow tie: bowtie
        jacket: jacket
        coat: jacket
        hoodie: hoodie
        jeans: jeans
        suit: suit
        dress: gown
        gown: gown
        wedding dress: wedding_dress
        swimsuit: swimsuit
        bathrobe: bathrobe
        apron: apron
        kimono: kimono
        shoes: shoes, footwear, sneaker
        shoe: shoes, footwear
        sneakers: sneaker, footwear
        boots: boot, footwear
        sandals: sandal, footwear
        high heels: high_heel, footwear
        slippers: footwear, moccasin
        socks: sock
        sock: sock
        tuxedo: tuxedo
        lipstick: cosmetic_tool
        hairbrush: cosmetic_tool
        comb: cosmetic_tool
        toothbrush: cosmetic_tool
        razor: cosmetic_tool
        passport: passport
        credit card: credit_card
        ticket: ticket
        boarding pass: ticket
        receipt: receipt
        coin: coin, currency
        coins: coin, currency
        banknote: currency, money
        cash: money, currency
        money: money, currency
        envelope: envelope
        stamp: envelope
        postcard: printed_page
        newspaper: newspaper
        magazine: magazine
        book: book
        notebook: book, office_supplies
        pen: pen
        pencil: pen, office_supplies
        map: map
        calendar: calendar
        key: tool
        lighter: lighter
        matches: matches
        syringe: syringe
        thermometer: thermometer
        stethoscope: stethoscope
        crutches: crutch
        wheelchair: wheelchair
        stretcher: stretcher
        pills: medicine
        medicine: medicine
        bandage: medicine
        mask: mask, gas_mask
        car: car, automobile
        taxi: car, automobile
        cab: car, automobile
        bus: bus
        train: train_real, train
        tram: streetcar, tramway
        streetcar: streetcar
        subway: train_real, train
        bike: bicycle
        bicycle: bicycle
        motorcycle: motorcycle
        motorbike: motorcycle
        scooter: scooter
        plane: airplane, aircraft
        airplane: airplane, aircraft
        aircraft: aircraft, airplane
        helicopter: helicopter
        ship: cruise_ship, warship, boat, watercraft
        boat: boat, watercraft, sailboat, rowboat, speedboat, yacht
        ferry: boat, watercraft, cruise_ship
        cruise ship: cruise_ship
        sailboat: sailboat
        yacht: yacht, sailboat
        canoe: canoe
        kayak: kayak
        truck: truck, semi_truck
        van: van
        ambulance: ambulance
        fire truck: firetruck
        police car: police_car
        tractor: tractor
        tire: tire, wheel
        wheel: wheel, tire
        steering wheel: wheel, dashboard
        dashboard: dashboard
        license plate: license_plate
        traffic light: traffic_light
        stroller: stroller
        pram: stroller
        car seat: car_seat
        crib: crib
        trolley: shopping_cart, cart
        shopping cart: shopping_cart
        cart: cart, shopping_cart
        parachute: parachute
        rocket: rocket
        telescope: telescope
        apple: apple
        banana: banana
        orange: oranges, citrus_fruit
        lemon: lemon, citrus_fruit
        lime: lime, citrus_fruit
        grapefruit: grapefruit
        grapes: grape
        grape: grape
        strawberry: strawberry
        raspberry: raspberry
        blueberry: blueberry
        cherry: cherry
        peach: peach
        pear: pear
        plum: plum
        apricot: apricot
        pineapple: pineapple
        watermelon: watermelon
        melon: melon, cantaloupe, honeydew
        mango: mango
        kiwi: kiwi
        coconut: coconut
        avocado: avocado
        pomegranate: pomegranate
        tomato: tomato
        potato: potato
        carrot: carrot
        onion: onion
        garlic: garlic
        cucumber: cucumber
        lettuce: lettuce
        broccoli: broccoli
        cauliflower: cauliflower
        bell pepper: bell_pepper, pepper_veggie
        corn: corn
        mushroom: mushroom
        pumpkin: pumpkin
        zucchini: zucchini
        eggplant: eggplant
        spinach: spinach
        celery: celery
        beet: beet
        radish: radish
        leek: leek
        peas: pea
        beans: bean, green_beans
        asparagus: asparagus
        artichoke: artichoke
        bread: bread, white_bread
        bagel: bagel
        croissant: croissant
        muffin: muffin
        donut: donut
        doughnut: donut
        cake: cake, cake_regular
        cupcake: cupcake
        cookie: cookie, biscuit
        biscuit: biscuit, cookie
        pie: pie
        pastry: pastry
        waffle: waffle
        pancake: pancake
        pancakes: pancake
        cheese: cheese
        butter: butter
        egg: egg
        eggs: egg
        yogurt: yogurt
        honey: honey
        chocolate: chocolate
        candy: candy
        ice cream: ice_cream
        popcorn: popcorn
        pizza: pizza
        hamburger: hamburger
        burger: hamburger
        hot dog: hotdog
        sandwich: sandwich
        french fries: fries
        fries: fries
        salad: salad
        soup: soup
        pasta: pasta, spaghetti
        spaghetti: spaghetti, pasta
        rice: rice
        steak: steak
        sausage: sausage
        bacon: bacon
        ham: ham
        meat: meat, beef
        beef: beef, steak
        salmon: salmon
        tuna: tuna
        shrimp: seafood, shellfish
        lobster: lobster
        crab: crab
        sushi: sushi
        taco: taco
        burrito: burrito
        pretzel: pretzel
        omelet: omelet
        dumplings: dumpling
        cereal: cereal
        oatmeal: oatmeal
        nuts: nut
        peanut: peanut
        almond: almond
        coffee: coffee
        tea: tea_drink
        juice: juice
        wine: wine, red_wine, white_wine
        beer: beer
        cocktail: cocktail
        milkshake: milkshake
        smoothie: smoothie
        soda: soda
        lemonade: juice, drink
        dog: dog, canine
        puppy: dog, canine
        cat: cat, feline, adult_cat, kitten
        kitten: kitten, cat, feline
        horse: horse
        cow: cow
        pig: pig
        sheep: sheep
        goat: goat
        donkey: donkey
        rabbit: rabbit
        hamster: hamster
        guinea pig: rodent
        rat: rat, rodent
        squirrel: squirrel
        hedgehog: hedgehog
        fox: fox
        wolf: coyote_wolf
        bear: bear
        deer: deer
        elk: elk
        moose: moose
        lion: lion
        tiger: tiger
        leopard: leopard
        cheetah: cheetah
        elephant: elephant
        giraffe: giraffe
        zebra: zebra
        camel: camel
        kangaroo: kangaroo
        koala: koala
        panda: panda
        hippo: hippopotamus
        rhino: rhinoceros
        bird: bird
        parrot: parrot
        owl: owl
        eagle: eagle
        pigeon: pigeon
        dove: dove
        swan: swan
        penguin: penguin
        flamingo: flamingo
        peacock: peacock
        ostrich: ostrich
        seagull: gull
        gull: gull
        hen: poultry
        rooster: poultry
        goldfish: goldfish
        shark: shark
        whale: whale, cetacean
        dolphin: dolphin
        octopus: cephalopod
        jellyfish: jellyfish
        starfish: starfish
        turtle: turtle, tortoise
        tortoise: tortoise, turtle
        frog: frog
        toad: toad
        snake: snake
        lizard: lizard
        crocodile: alligator_crocodile
        bee: bee
        butterfly: butterfly
        ant: ant
        spider: spider
        ladybug: ladybug
        dragonfly: dragonfly
        snail: snail
        worm: worm
        caterpillar: caterpillar
        mosquito: insect
        bridge: bridge
        tower: tower
        castle: castle
        lighthouse: lighthouse
        skyscraper: skyscraper
        house: house_single, domicile
        apartment: apartment
        building: building
        barn: barn
        windmill: windmill
        fountain: fountain
        tent: tent
        beach: beach
        mountain: mountain
        mountains: mountain
        hill: hill
        forest: forest
        lake: lake
        river: river
        waterfall: waterfall
        ocean: ocean
        sea: ocean
        island: island
        desert: desert
        volcano: volcano
        glacier: glacier
        iceberg: iceberg
        cave: cave
        canyon: canyon
        cliff: cliff
        rainbow: rainbow
        lightning: lightning
        tornado: tornado
        snow: snow
        moon: moon
        sun: sun
        star: night_sky, celestial_body
        planet: celestial_body
        tree: tree
        flower: flower
        rose: rose
        tulip: tulip
        sunflower: sunflower
        daisy: daisy
        cactus: cactus
        grass: grass
        leaf: foliage
        leaves: foliage
        garden: garden
        park: park
        playground: playground
        stadium: stadium
        road: road, street
        street: street, road
        crosswalk: crosswalk
        sidewalk: sidewalk
        tunnel: tunnel
        airport: airport
        train station: train_station
        harbor: harbour
        pier: pier
        dock: dock
        kitchen: kitchen, kitchen_room
        bathroom: bathroom, bathroom_room
        bedroom: bedroom
        living room: living_room
        dining room: dining_room
        library: library
        classroom: classroom
        museum: museum
        theater: theater
        restaurant: restaurant
        bar: bar
        pool: pool
        swimming pool: pool
        ball: ball
        football: football, ball
        soccer ball: soccer, ball
        basketball: basketball
        baseball: baseball
        baseball bat: baseball_bat
        golf ball: golf_ball
        golf club: golf_club
        racket: racquet
        tennis racket: racquet
        skateboard: skateboard
        surfboard: surfboard
        skis: ski_equipment
        snowboard: snowboard
        ice skates: ice_skates
        dumbbell: dumbbell
        barbell: barbell
        treadmill: treadmill
        trophy: trophy
        medal: medal
        guitar: guitar
        piano: piano
        violin: violin
        cello: cello
        drum: drum
        drums: drum
        trumpet: trumpet
        saxophone: saxophone
        flute: flute
        harp: harp
        accordion: accordion
        ukulele: ukulele
        chess: chess
        dice: dice
        playing cards: play_card
        jigsaw puzzle: jigsaw, puzzles
        puzzle: jigsaw, puzzles
        kite: kite
        balloon: balloon
        doll: doll
        teddy bear: stuffed_animals
        yarn: yarn
        paintbrush: paintbrush
        easel: easel
        painting: painting
        sculpture: statue
        statue: statue
        tripod: tripod
        binoculars: binoculars
        compass: compass
        christmas tree: christmas_tree
        gift: gift
        present: gift
        wedding cake: wedding_cake
        birthday cake: birthday_cake
        fireworks: fireworks
        """

    private static let labelMap: [String: [String]] = parseTable(mapSource)

    /// Parses `term: value, value` lines (the first line of a repeated term wins).
    static func parseTable(_ source: String) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for line in source.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let values = parts[1]
                .split(separator: ",")
                .map { (value: Substring) -> String in value.trimmingCharacters(in: .whitespaces) }
                .filter { (value: String) -> Bool in !value.isEmpty }
            guard !key.isEmpty, !values.isEmpty, map[key] == nil else { continue }
            map[key] = values
        }
        return map
    }

    /// Hand-mapped identifiers of a term (whole term first, then its singular/plural forms).
    static func mappedLabels(for words: [String]) -> [String] {
        let phrase = words.joined(separator: " ")
        if let direct = labelMap[phrase] { return direct }
        guard let last = words.last else { return [] }
        let prefix = words.dropLast().joined(separator: " ")
        for form in WordImageText.forms(of: last).sorted() {
            let candidate = prefix.isEmpty ? form : prefix + " " + form
            if let found = labelMap[candidate] { return found }
        }
        return []
    }

    /// Identifiers guessed from the term itself (`ice cream` → `ice_cream`, `bookshelves` →
    /// `bookshelf`, and the head noun: `kitchen sink` → `sink`). Only those that really exist in
    /// the device taxonomy are used.
    static func derivedLabels(for words: [String]) -> [String] {
        guard let last = words.last else { return [] }
        var result: [String] = []
        let prefix = words.dropLast()
        for form in WordImageText.forms(of: last).sorted() {
            let joined = (Array(prefix) + [form]).joined(separator: "_")
            if !result.contains(joined) { result.append(joined) }
        }
        if words.count > 1 {
            for form in WordImageText.forms(of: last).sorted() where !result.contains(form) {
                result.append(form)
            }
            if let head = labelMap[last] {
                for label in head where !result.contains(label) {
                    result.append(label)
                }
            }
        }
        return result
    }

    // MARK: Synonyms and other senses

    private static let synonymSource = """
        phone: telephone, cellphone, smartphone, mobile phone, cell phone, iphone
        cell phone: cellphone, smartphone, mobile phone, phone
        cellphone: cell phone, smartphone, mobile phone, phone
        mobile phone: smartphone, cellphone, cell phone, phone
        smartphone: mobile phone, cellphone, iphone, phone
        telephone: phone, landline
        tv: television
        television: tv
        sofa: couch
        couch: sofa
        fridge: refrigerator
        refrigerator: fridge
        bike: bicycle
        bicycle: bike
        motorbike: motorcycle
        motorcycle: motorbike
        plane: airplane, aircraft
        airplane: plane, aircraft
        cab: taxi
        taxi: cab
        subway: metro, underground
        sneakers: trainers, sneaker
        trainers: sneakers
        fries: french fries
        french fries: fries, chips
        cookie: biscuit
        biscuit: cookie
        donut: doughnut
        doughnut: donut
        trash can: garbage can, bin
        garbage can: trash can, bin
        faucet: tap
        closet: wardrobe
        wardrobe: closet
        backpack: rucksack
        rucksack: backpack
        glasses: eyeglasses, spectacles
        eyeglasses: glasses, spectacles
        hamburger: burger
        burger: hamburger
        puppy: dog
        kitten: cat
        stroller: pram, buggy
        pram: stroller
        luggage: suitcase, baggage
        suitcase: luggage
        """

    private static let synonymMap: [String: [String]] = parseTable(synonymSource)

    /// Other phrasings of a term (also used as the query of the last search attempt).
    static func synonyms(for term: String) -> [String] {
        synonymMap[term] ?? []
    }

    /// Title/tag words that point to another sense of an unambiguous-looking term.
    static func avoidWords(for term: String) -> [String] {
        switch term {
        case "phone", "telephone": return ["favourites", "favorites", "wallpaper", "phonebackground", "screenshot"]
        case "pen": return ["olympus", "camera", "llyn", "snowdonia"]
        default: return []
        }
    }

    // MARK: Groups

    /// Animals: parents plus common specific identifiers (Vision reports both).
    static let living: Set<String> = Set([
        "animal", "mammal", "insect", "arthropods", "arachnid", "bird", "reptile", "fish", "rodent", "canine",
        "feline", "ungulates", "marsupial", "cetacean", "mollusk", "gastropod", "cephalopod", "spider", "ant", "bee",
        "moth", "butterfly", "caterpillar", "worm", "centipede", "millipede", "ladybug", "dragonfly", "scarab",
        "snail", "cat", "adult_cat", "kitten", "dog", "horse", "cow", "pig", "sheep", "goat", "rabbit", "deer",
        "bear", "raptor", "poultry", "frog", "lizard", "snake", "turtle", "rat", "squirrel"
    ] as [String])

    /// People.
    static let people: Set<String> = Set(["people", "adult", "child", "baby", "teen", "crowd"] as [String])

    /// Landscapes (`sky` is left out: every outdoor object has it).
    static let scenery: Set<String> = Set([
        "mountain", "hill", "forest", "ocean", "lake", "river", "desert", "canyon", "cliff", "waterfall",
        "glacier", "beach", "shore", "sunset_sunrise", "night_sky", "land", "jungle", "volcano", "wetland"
    ] as [String])

    /// Not a photo of a thing: text, screens, drawings, maps.
    static let textual: Set<String> = Set([
        "document", "printed_page", "screenshot", "handwriting", "illustrations", "diagram", "chart", "map",
        "painting", "graffiti", "chalkboard", "whiteboard"
    ] as [String])

    /// Fire and flames (the photo „2021-phone-favourites” for „phone” is a fireplace).
    static let fire: Set<String> = Set(["fire", "flame", "fireplace", "embers", "fireworks", "firecracker", "pyrotechnics"] as [String])

    /// Food and drinks.
    static let food: Set<String> = Set([
        "food", "fruit", "vegetable", "baked_goods", "dessert", "meat", "seafood", "drink", "citrus_fruit",
        "bread", "cake", "salad", "pizza", "sandwich", "pastry", "candy", "liquid"
    ] as [String])

    /// Subject implied by hand-mapped identifiers (`dog` → animal, `apple` → food).
    static func subject(forLabels labels: [String]) -> WordImageSubject? {
        guard !labels.isEmpty else { return nil }
        if labels.contains(where: { (label: String) -> Bool in living.contains(label) || animalLabels.contains(label) }) {
            return .animal
        }
        if labels.contains(where: { (label: String) -> Bool in food.contains(label) || foodLabels.contains(label) }) {
            return .food
        }
        return nil
    }

    /// Specific animal identifiers of the label map (not parents).
    private static let animalLabels: Set<String> = Set([
        "hamster", "hedgehog", "fox", "coyote_wolf", "elk", "moose", "lion", "tiger", "leopard", "cheetah",
        "elephant", "giraffe", "zebra", "camel", "kangaroo", "koala", "panda", "hippopotamus", "rhinoceros",
        "parrot", "owl", "eagle", "pigeon", "dove", "swan", "penguin", "flamingo", "peacock", "ostrich", "gull",
        "goldfish", "shark", "whale", "dolphin", "jellyfish", "starfish", "tortoise", "toad", "alligator_crocodile",
        "donkey", "koi", "guppy", "seal", "sealion"
    ] as [String])

    /// Specific food identifiers of the label map.
    private static let foodLabels: Set<String> = Set([
        "apple", "banana", "oranges", "lemon", "lime", "grapefruit", "grape", "strawberry", "raspberry",
        "blueberry", "cherry", "peach", "pear", "plum", "apricot", "pineapple", "watermelon", "melon", "mango",
        "kiwi", "coconut", "avocado", "pomegranate", "tomato", "potato", "carrot", "onion", "garlic", "cucumber",
        "lettuce", "broccoli", "cauliflower", "bell_pepper", "corn", "mushroom", "pumpkin", "zucchini",
        "eggplant", "cheese", "butter", "egg", "honey", "chocolate", "coffee", "tea_drink", "juice", "wine",
        "beer", "hamburger", "fries", "soup", "pasta", "rice", "steak", "sausage", "sushi", "donut", "cookie"
    ] as [String])

    /// Broader identifiers accepted with a strong title/tag match when the term has no own
    /// identifier (e.g. „bat” → `mammal`).
    static func defaultRelated(for subject: WordImageSubject) -> [String] {
        switch subject {
        case .animal: return ["animal", "mammal", "bird", "fish", "insect", "reptile"]
        case .food: return ["food", "fruit", "vegetable", "dessert", "baked_goods", "meat", "seafood", "drink"]
        case .plant: return ["plant", "flower", "tree", "vegetation", "foliage", "decorative_plant"]
        case .wearable: return ["clothing", "footwear", "headgear", "jewelry"]
        case .place: return ["structure", "building", "interior_room", "outdoor"]
        case .object, .person, .artwork: return []
        }
    }
}
