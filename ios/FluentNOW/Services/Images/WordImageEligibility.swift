import Foundation
import FluentKit

/// Stricter app-side filter on top of FluentKit's `PictureExercise.isPicturable`: words that
/// pass the noun/topic heuristic but cannot be recognised on one photo (voucher, spreadsheet,
/// birthday, cashier, dose…). Excluded meanings are stored as „bez zdjęcia” and never searched.
///
/// The lists come from running `isPicturable` over all built-in topics (2 810 meanings,
/// 2026-10-18) and reading the result: events, time, digital things, documents and cards that
/// all look alike, measures, people by role (four photos of people cannot be told apart),
/// music/book genres, sport situations, medical states.
enum WordImageEligibility {
    /// Polish reason when the term must not get a photo, `nil` when it may.
    static func exclusionReason(term: String) -> String? {
        let phrase = PictureExercise.searchQuery(term: term).lowercased()
        let words = WordImageText.tokens(phrase)
        guard let head = words.last else { return "Puste hasło." }
        let normalized = words.joined(separator: " ")
        if excludedTerms.contains(phrase) || excludedTerms.contains(normalized) {
            return "Pojęcie, którego nie da się jednoznacznie pokazać na zdjęciu."
        }
        if personRoles.contains(phrase) || personRoles.contains(normalized) || (words.count > 1 && personHeads.contains(head)) {
            return "Osoba (zawód lub rola) — zdjęcia ludzi byłyby nie do odróżnienia."
        }
        if words.count > 1 && abstractHeads.contains(head) {
            return "Wydarzenie lub pojęcie („\(head)”) — nie przedmiot."
        }
        if let suffix = abstractSuffix(of: head) {
            return "Rzeczownik odczasownikowy lub osoba (-\(suffix))."
        }
        return nil
    }

    /// Gerunds (`-ing`), people (`-ist`, `-ian`, `-ee`) — with the concrete exceptions.
    static func abstractSuffix(of head: String) -> String? {
        guard !suffixExceptions.contains(head) else { return nil }
        if head.count >= 6 && head.hasSuffix("ing") { return "ing" }
        if head.count >= 6 && head.hasSuffix("ist") { return "ist" }
        if head.count >= 7 && head.hasSuffix("ian") { return "ian" }
        if head.count >= 6 && head.hasSuffix("ee") { return "ee" }
        return nil
    }

    static let suffixExceptions: Set<String> = entries("""
        building, ceiling, painting, earring, string, spring, clothing, stuffing, pudding, dumpling,
        frosting, filling, railing, awning, bedding, stocking, herring, whiting, lightning, duckling,
        seedling, sapling, flooring, siding, piping, icing, coffee, toffee, settee, puree, marquee,
        lychee, jamboree, chimpanzee, dungaree
        """)

    /// Last words that make a phrase an event or an idea („garage sale”, „rain check”).
    static let abstractHeads: Set<String> = entries("""
        party, parties, rights, period, hours, spirit, shock, fright, rage, order, pricing, policy,
        call, check, sale, therapy, sprawl, maneuver, compressions, costs, notice, alert, toll, waiver,
        coverage, delivery, shipping, service, services, chat, shortcut, music, novel, story, life,
        plan, permit, form, rules, gathering, ceremony, rehearsal, ovation, comedy, relief, route,
        mileage, scan, dance, tour, signing, sweeping, prep, label, league, spree, list
        """)

    /// Last words that name a person in any phrase („bus driver”, „flight attendant”) — only
    /// heads that never name a device („record player”, „baby carrier” stay allowed).
    static let personHeads: Set<String> = entries("""
        driver, girl, boy, man, woman, lady, guy, kid, kids, artist, teacher, officer, guard, clerk,
        worker, sitter, ranger, attendant, assistant, agent, counselor, trainer, singer, student,
        owner, manager, vendor, performer, hunter, snob, eater, freak, nurse, doctor, chef, cop,
        parents, couple, family
        """)

    /// Whole terms that pass `isPicturable` but are not one recognisable thing.
    static let excludedTerms: Set<String> = entries("""
        911, act, address, address bar, affordable housing, after-work drinks, aftershock,
        air conditioning, all clear, alterations, anesthesia, angle, anniversary, applause, app,
        app store, aroma, arrivals, art, art class, assist, atmosphere, auction, audio guide,
        audiobook, automatic, background, backpacking, bad breath, bag check, bag drop, balance,
        bargain, beat, beginner, behavior, belongings, bestseller, big bang, bike ride, bike share,
        bike rental, birdsong, birth weight, birthday, blend, blind spot, blowout, bluetooth,
        boarding group, bogo, book club, book signing, bragging rights, brain teaser, breed, browser,
        brushstroke, building permit, bump, burn, business casual, business class, buzz cut,
        caffeine, camera roll, caption, car rental company, carryout, cash back, cast, character,
        charades, cheap eats, checklist, checkmate, chore, chore chart, christmas, christmas eve,
        circuit, city life, class, classic, classical music, close-up, clue, clutter,
        collision damage waiver, colic, combo meal, comeback, comedy, comfort food,
        community theater, compact, concert, contactless delivery, continental breakfast, copy, core,
        corner, corner kick, countdown, country, county fair, cpr, craft, crack, cradle cap, crowd,
        crowd crush, cruise, crunch, ct scan, culture shock, cure-all, current, cursor, custom, cut,
        dark matter, day pass, dead battery, death toll, debris, deductible, defense, delivery app,
        departures, descent, destination wedding, detail, detour, device, dialogue, diaper rash,
        dimensions, dinner party, directions, disaster relief, district, diy, dmv, donations,
        doorbuster, dosage, dose, dozen, drainage, dress code, dress rehearsal, drive-thru, drizzle,
        drunk driving, due date, e-book, earworm, easter, easy read, echo, economy, edge, edition,
        electric shock, electronic music, emergency alert, emergency services, emoji, encore, ending,
        entrée, epicenter, essay, essentials, estimate, eta, evacuation order, evacuation route,
        exercise, exhibit, exit, expiration date, extra charges, extra cheese, fade, fahrenheit,
        false alarm, family gathering, fare, fast food, fault line, feast, fiction, final, fine,
        fine dining, fine print, first aid, first class, first dance, first half, first person,
        first-time parents, fitness center, fixer-upper, flash, folk music, food poisoning, forgery,
        forward, foul, fourth of july, free kick, free refills, free sample, freezer burn, fresh air,
        fresh start, front row, full coverage, gadget, gap, garage sale, gear, general store, genre,
        getaway, gift receipt, gift wrapping, gig, good samaritan, gpa, grace period, grade,
        graduation party, grand opening, gratuities, ground shipping, group chat, group photo,
        guest list, guided tour, habitat, halftime, halloween, hangout, hangover, hazard, headcount,
        header, headquarters, heart attack, heat, heat wave, heating, heatstroke, heavy lifting,
        heavy metal, heimlich maneuver, heirloom, hiccups, high voltage, hike, hint, hip-hop, hit,
        hobby, hold, hole-in-the-wall, holiday spirit, holidays, home, home run, home screen,
        home team, homework, honeymoon, honor roll, hot spot, house rules, house specialty,
        household items, housekeeping, housework, icon, id, impulse buy, improv, inch, ingredient,
        injury, inner city, instructions, international driving permit, item, jazz, joint, junk,
        keyboard shortcut, kickoff, labor, landscape, last call, launch, layers, lead, lead role,
        lesson, light show, light-year, lightweight, limited-time offer, line, lines, lineup, link,
        listing, live music, load, local anesthetic, lock screen, lockdown, lost and found,
        loyalty card, lullaby, lyrics, magnitude, markdown, marriage, marriage license,
        married life, martial arts, masterpiece, material, math, meal, meal prep, merch, mess,
        midnight, midnight mass, missed call, missed delivery notice, missing piece, mission,
        mixed breed, mobile order, modern art, monologue, monthly pass, moving costs, moving sale,
        music, musical, mystery, naked eye, nap, natural disaster, natural light, new address,
        new chapter, new year's eve, night feeding, night out, nightcap, nightlife,
        non-emergency line, novel, object, off-season, offense, opening, opening act, opening hours,
        opera, operating system, order, original, outfit, ounce, pace, pack, package insert, page,
        page-turner, paperwork, parade, part, parts, party, passcode, passion, pastime, pat-down, pdf,
        peace, penalty, penalty shootout, people-watching, perennial, period, personal item,
        perspective, photo, photo shoot, piece, piece of junk, pinch, pint, play, playlist, plus-one,
        poem, poetry, poison control, pop, portion, pound, practice, prank call, predator, prenup,
        presale, price check, priority seating, progress, prohibited item, project, proposal, props,
        protagonist, quality of life, quick fix, quiz, quote, r&b, race, rain check, rap, recall,
        recess, recipe, record label, recovery, regular, rehearsal, relatives, relocation package,
        rematch, report card, rep, retail therapy, retirement party, reunion, rewards card, riddle,
        ride, rideshare, rip current, rip-off, road rage, roast, roll, romance novel, room,
        root canal, round-trip ticket, one-way ticket, route, routine, row, rulebook, rules, run,
        sale, sample, save, save the date, scene, scenery, science, score sheet, scratch, scrimmage,
        search and rescue, search engine, season ticket, seating chart, secret santa, section,
        selfie, separate checks, serving, set, setlist, setting, shade, shadow, shared drive,
        shared ride, shopping list, shopping spree, short circuit, short story, shot, shots, show,
        shuffle, side, side order, silhouette, single, skincare, small town, smooth sailing, snack,
        snacks, solids, solitaire, solo, song, sore loser, sound check, soul, special, species,
        speech, spelling, spf, sphere, sport, spring cleaning, square, square feet, stage fright,
        staging, stalemate, stand-up comedy, standing ovation, still life, stop, storage unit,
        store brand, store credit, store hours, strategy, strength, stuff, subject, summary,
        surge pricing, surgery, tab, take, takeout, talent, tan, taste in music, tasting menu, team,
        team spirit, team sport, tech support, tender, test, thanksgiving, theme, thing, thingy,
        thunder, tide, tiebreaker, time zone, timeout, tip, title, to-do list, toll, total, tour,
        track and field, tragedy, traffic, traffic jam, transfer, treat, triage, triangle, trivia,
        tryout, tune, tune-up, twins, u-turn, underdog, unlimited mileage, urban sprawl, urgent care,
        vacation rental, vibe, video, video call, visiting hours, vitamin, voice, voicemail, vows,
        wait, wake-up call, weekly ad, whatchamacallit, wi-fi, wild card, wind chill,
        window-shopping, wine list, wine tasting, wiring, word search, workout, worksheet, wound,
        wrong address, wrong order, yield, youth league, zip code, zoom, website, voucher,
        gift voucher, coupon, spreadsheet, form, customs form, library card, key card, fare card,
        toll pass, rail pass, parking ticket, invoice, certificate, prescription, document, contract,
        statement, oval, rectangle, circle, cube, pyramid, polka dot, star, hearts, spades, bleeding,
        bleeding gums, blister, bruise, scar, sunburn, rash, tooth decay, toothache, cavity, blood,
        kidney, liver, lung, brain, nerve, nerves, vein, spine, muscle, hamstring, skin, enamel,
        tartar, molar, baby tooth, front tooth, wisdom tooth, first tooth, split ends, dusk, dawn,
        emergency room, delivery room, red card, yellow card, shooting star, northern lights,
        solar system, universe, galaxy, black hole, supernova, exoplanet, dwarf planet, elevation,
        temperature, humidity, breeze, gust, cold snap, heat index, visibility, weather alert,
        storm surge, flash flood, evacuee, baby shower, bridal shower, fire drill, muster drill,
        curtain call, sound system, sheet music, ace, acre, airline, airmail, alcohol, alien,
        anchor store, back, band, bass, bay, beverage, bishop, bite, bob, body, break room, bunch,
        cardio, carol, carrier, case, ceremony, chant, chapter, check, chord, chorus, city, club,
        clutch, combine, concourse, connecting flight, connecting gate, cookout, corner piece, cot,
        counter, countryside, court, cover, coverage, cowlick, cream, crops, cross, cross street,
        crossword, cruise control, cruise line, crumb, crust, curbside pickup, customer service desk,
        dairy, decor, decorations, desktop, dew, diesel, directory, double room, drink, drought,
        e-reader, earth, edge piece, egg hunt, egg white, engine, equipment, exhaust, express lane,
        extensions, facial, fall foliage, farm animal, festival, fillet, flashers, flood, foreground,
        fountain drink, fuse, gallon, game piece, gas, gas leak, gift, golf, grain, groceries, gym,
        hair dye, hairball, half-and-half, hand-me-downs, handle, hardware, hazard lights, head,
        heart, help desk, herd, highlights, holiday card, horizon, house wine, housewarming gift,
        icu, iv, jack, joker, junk mail, kids' menu, king, knickknack, label, lane, lash extensions,
        laundry, leftovers, legroom, light, linen, liquids, liquor, livestock, loaner car,
        local train, lost luggage, lounge, low heat, lunge, machine, mail, main course, makeup,
        marinade, mars, master bedroom, meteor shower, meter, microchip, mileage, mist, mold,
        moving company, nicu, note, nursery, nylon, office, oil leak, one-way rental, open bar,
        open office, outlet, outlet mall, outskirts, packing paper, panorama, paper jam, peak, perm,
        pet, pit, plains, plaque, plastic, platform gap, plaza, port, port side, portrait, postage,
        potluck, power button, prey, print, produce, publisher, punch, quiet car, record, red-eye,
        refill, register, registry, rental car, replacement car, rest stop, return address,
        ringtone, root rot, rust, scale, scrape, screenshot, security line, self-checkout, sheet,
        shelter, single room, six-pack, sketch, slope, smile, smoke, snowstorm, soil, souvenir,
        spacewalk, splashdown, stage, stain, stand, starboard, stern, stitch, store, chain store,
        pop-up shop, street fair, strip mall, studio, suburbs, suite, summit, sunlight, sunshine,
        switchbacks, tag, tandem, tap water, terminal, thin crust, throw-in, token, top, track,
        trail, trash, trim, tube, updo, upholstery, vaccine, valley, venue, verse, vet bill, village,
        waiting room, walk-in, warning light, water, water station, wave, waves, wedding gift,
        wedding photos, wet floor, wild animal, wildlife, wrap, yard, antacid, aspirin, ibuprofen,
        painkiller, decongestant, fever reducer, allergy medicine, cough syrup, cough drop,
        eye drops, nasal spray, implant, fluoride, toner, moisturizer, conditioner, concealer, pill
        """)

    /// People by role (also checked as the head: „bus driver”, „dog walker”, „flower girl”).
    static let personRoles: Set<String> = entries("""
        actor, actress, artist, astronaut, astronomer, athlete, author, baker, barber, barista,
        bartender, bellhop, best man, bouncer, bride, bridesmaid, bully, busser, butcher, bystander,
        captain, carpenter, cashier, caterer, chef, collector, commuter, composer, concierge,
        conductor, contractor, cook, courier, crew, crew member, curator, defender, director,
        dispatcher, dj, doorman, driver, electrician, employee, emt, esthetician, farmer, farmhand,
        firefighter, first responder, first responders, flower girl, gardener, goalie, goalkeeper,
        groom, groomer, groomsman, guest, hairdresser, headliner, hoarder, host, hostess, hygienist,
        librarian, lifeguard, maid of honor, mail carrier, makeup artist, mall cop, mall rat,
        mall walker, manager, mechanic, meteorologist, midfielder, movers, musician, narrator,
        neat freak, neighbor, newlyweds, officiant, opponent, orthodontist, owner, painter,
        park ranger, passenger, pedestrian, personal trainer, pet sitter, pharmacist, photographer,
        picky eater, pilot, player, plumber, postal clerk, principal, receptionist, referee,
        ring bearer, rival, runner-up, sales associate, salesperson, santa, santa claus, scalper,
        school counselor, security guard, security officer, sender, server, singer, slob, songwriter,
        staff, striker, student, substitute, substitute teacher, surgeon, survivor, teacher,
        teammate, umpire, understudy, usher, waiter, waitress, winner, writer, zookeeper,
        coffee snob, bookworm, preemie, lead singer, bargain hunter, mr. fix-it, walker, girl, boy,
        man, woman, lady, guy, kid, kids, parent, parents, mom, dad, mother, father, grandma, grandpa,
        grandmother, grandfather, sister, brother, cousin, friend, boyfriend, girlfriend, husband,
        wife, fiancé, fiancée, tourist, traveler, customer, client, patient, doctor, nurse, dentist,
        vet, paramedic, officer, cop, police officer, detective, lawyer, judge, boss, colleague,
        coworker, intern, volunteer, coach, fan, fans, audience, spectator, spectators, visitor,
        visitors, resident, residents, roommate, landlord, tenant, buyer, seller, vendor,
        street vendor, street performer, performer, dancer, comedian, magician, clown, model,
        cyclist, runner, swimmer, hiker, climber, skier, surfer, newborn, toddler,
        teenager, adult, senior, babysitter, nanny, dog walker, wedding planner, city dweller,
        foot passenger, cabin steward, bagger, classmate
        """)

    /// Parses a comma-separated table (entries may span lines; spaces inside an entry are kept).
    static func entries(_ text: String) -> Set<String> {
        var result = Set<String>()
        for line in text.split(separator: "\n") {
            for part in line.split(separator: ",") {
                let entry = part.trimmingCharacters(in: .whitespaces).lowercased()
                if !entry.isEmpty {
                    result.insert(entry)
                }
            }
        }
        return result
    }
}
