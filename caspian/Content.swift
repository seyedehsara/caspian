import Foundation

// MARK: - Models

/// A country as the game knows it. `id` matches countries.geojson (Scotland uses the UK id).
struct QuizCountry: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let flag: String
}

/// One photo question. The player sees `prompt` and `art`, then picks between two countries.
struct QuizQuestion: Identifiable, Hashable, Sendable {
    let id: String                  // also the photo's asset name, e.g. "q_kimono"
    let prompt: String
    let art: Illustration
    let answerID: String            // the country that gets unlocked
    let distractorID: String        // the wrong option
    let fact: String                // "Did you know?" after answering

    /// Both options in a fixed but varied order, so the answer isn't always first.
    var optionIDs: [String] {
        id.count.isMultiple(of: 2) ? [answerID, distractorID] : [distractorID, answerID]
    }
}

struct Landmark: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let description: String
    let art: Illustration
}

/// A set of questions the player plays in one go.
struct QuizSession: Identifiable {
    let id = UUID()
    let questions: [QuizQuestion]
}

// MARK: - Library

enum ContentLibrary {
    static let questionsPerSession = 5
    static let pointsPerCorrect = 10
    static let pointsPerUnlock = 50

    static func country(_ id: String) -> QuizCountry? { countries.first { $0.id == id } }

    /// Countries that can be unlocked (they have at least one question).
    static var answerCountries: [QuizCountry] {
        let ids = Set(questions.map(\.answerID))
        return countries.filter { ids.contains($0.id) }
    }

    static func questions(about countryID: String) -> [QuizQuestion] {
        questions.filter { $0.answerID == countryID }
    }

    /// The photo used to represent a country in the collection.
    static func signature(for countryID: String) -> Illustration? {
        questions(about: countryID).first?.art
    }

    /// Builds a random session. If `focus` is given, one question about that country goes first.
    static func makeSession(focus: String? = nil) -> QuizSession {
        var pool = questions.shuffled()
        var picked: [QuizQuestion] = []
        if let focus, let first = pool.first(where: { $0.answerID == focus }) {
            picked.append(first)
            pool.removeAll { $0.id == first.id }
        }
        // Avoid two questions about the same country in one session where possible.
        for q in pool where picked.count < questionsPerSession {
            if !picked.contains(where: { $0.answerID == q.answerID }) { picked.append(q) }
        }
        for q in pool where picked.count < questionsPerSession && !picked.contains(q) {
            picked.append(q)
        }
        return QuizSession(questions: picked)
    }

    // MARK: Countries (answers and distractors)

    static let countries: [QuizCountry] = [
        QuizCountry(id: "IRN", name: "Iran", flag: "🇮🇷"),
        QuizCountry(id: "JPN", name: "Japan", flag: "🇯🇵"),
        QuizCountry(id: "TUR", name: "Turkey", flag: "🇹🇷"),
        QuizCountry(id: "RUS", name: "Russia", flag: "🇷🇺"),
        QuizCountry(id: "IND", name: "India", flag: "🇮🇳"),
        QuizCountry(id: "KOR", name: "South Korea", flag: "🇰🇷"),
        QuizCountry(id: "THA", name: "Thailand", flag: "🇹🇭"),
        QuizCountry(id: "GBR", name: "Scotland", flag: "🏴󠁧󠁢󠁳󠁣󠁴󠁿"),
        QuizCountry(id: "ITA", name: "Italy", flag: "🇮🇹"),
        QuizCountry(id: "EGY", name: "Egypt", flag: "🇪🇬"),
        QuizCountry(id: "MEX", name: "Mexico", flag: "🇲🇽"),
        QuizCountry(id: "MAR", name: "Morocco", flag: "🇲🇦"),
        // Distractors only (for now)
        QuizCountry(id: "AZE", name: "Azerbaijan", flag: "🇦🇿"),
        QuizCountry(id: "GRC", name: "Greece", flag: "🇬🇷"),
        QuizCountry(id: "POL", name: "Poland", flag: "🇵🇱"),
        QuizCountry(id: "UKR", name: "Ukraine", flag: "🇺🇦"),
        QuizCountry(id: "PAK", name: "Pakistan", flag: "🇵🇰"),
        QuizCountry(id: "MYS", name: "Malaysia", flag: "🇲🇾"),
        QuizCountry(id: "CHN", name: "China", flag: "🇨🇳"),
        QuizCountry(id: "VNM", name: "Vietnam", flag: "🇻🇳"),
        QuizCountry(id: "KHM", name: "Cambodia", flag: "🇰🇭"),
        QuizCountry(id: "IRL", name: "Ireland", flag: "🇮🇪"),
        QuizCountry(id: "FRA", name: "France", flag: "🇫🇷"),
        QuizCountry(id: "LBN", name: "Lebanon", flag: "🇱🇧"),
        QuizCountry(id: "SDN", name: "Sudan", flag: "🇸🇩"),
        QuizCountry(id: "ESP", name: "Spain", flag: "🇪🇸"),
        QuizCountry(id: "COL", name: "Colombia", flag: "🇨🇴"),
        QuizCountry(id: "TUN", name: "Tunisia", flag: "🇹🇳"),
    ]

    // MARK: Questions
    // The photo for each question is an asset named exactly like its id (see PHOTOS.md).

    static let questions: [QuizQuestion] = [
        // Iran
        QuizQuestion(id: "q_persian_carpet", prompt: "Which country is famous for this traditional carpet pattern?",
                     art: Illustration(emoji: "🧶", imageName: "q_persian_carpet", tintIndex: 1),
                     answerID: "IRN", distractorID: "AZE",
                     fact: "Persian carpets have been woven for over 2,500 years. The oldest surviving knotted carpet in the world, the Pazyryk carpet from the 5th century BC, is believed to have been made in Persia."),
        QuizQuestion(id: "q_tar", prompt: "Which country does this long-necked instrument, the tar, come from?",
                     art: Illustration(emoji: "🪕", imageName: "q_tar", tintIndex: 4),
                     answerID: "IRN", distractorID: "GRC",
                     fact: "The tar's double-bowl body is carved from mulberry wood and covered with thin lamb skin. Its name simply means \"string\" in Persian, and it gave its name to the guitar and the sitar."),
        QuizQuestion(id: "q_ghalamzani", prompt: "Which culture crafted this hand-engraved copper vase, known as Ghalamzani?",
                     art: Illustration(emoji: "🏺", imageName: "q_ghalamzani", tintIndex: 4),
                     answerID: "IRN", distractorID: "EGY",
                     fact: "Ghalamzani is the Persian art of engraving metal with a chisel and small hammer. Isfahan is its heart, and engraved pieces in Iranian museums are up to 3,000 years old."),

        // Japan
        QuizQuestion(id: "q_kimono", prompt: "Guess the origin of this traditional outfit!",
                     art: Illustration(emoji: "👘", imageName: "q_kimono", tintIndex: 3),
                     answerID: "JPN", distractorID: "KOR",
                     fact: "Kimono means \"a thing to wear\". It is always wrapped left over right. Right over left is used only when dressing the dead, so getting it wrong is a real faux pas."),
        QuizQuestion(id: "q_matcha", prompt: "Which country hosts the traditional Chanoyu matcha tea ceremony?",
                     art: Illustration(emoji: "🍵", imageName: "q_matcha", tintIndex: 2),
                     answerID: "JPN", distractorID: "THA",
                     fact: "Chanoyu, \"the way of tea\", was shaped by tea master Sen no Rikyū in the 1500s around four ideals: harmony, respect, purity and tranquillity. A full ceremony can last four hours."),

        // Turkey
        QuizQuestion(id: "q_turkish_tea", prompt: "Which country uses this tulip-shaped glass for serving black tea?",
                     art: Illustration(emoji: "🫖", imageName: "q_turkish_tea", tintIndex: 1),
                     answerID: "TUR", distractorID: "JPN",
                     fact: "Turkey drinks more tea per person than any other country, around 3 kg a year each. The glass is called ince belli, \"slim-waisted\", and its shape keeps the tea hot while the rim stays cool."),
        QuizQuestion(id: "q_baklava", prompt: "Which country is famous for its sweet, layered baklava?",
                     art: Illustration(emoji: "🥐", imageName: "q_baklava", tintIndex: 4),
                     answerID: "TUR", distractorID: "MAR",
                     fact: "Baklava can have 40 or more paper-thin layers of filo. In 2013 pistachio baklava from Gaziantep became the first Turkish food protected by the EU as a regional speciality."),

        // Russia
        QuizQuestion(id: "q_matryoshka", prompt: "Where in the world are these hand-painted nesting dolls traditionally made?",
                     art: Illustration(emoji: "🪆", imageName: "q_matryoshka", tintIndex: 1),
                     answerID: "RUS", distractorID: "POL",
                     fact: "The first matryoshka set was carved near Moscow in 1890. The name comes from Matryona, a common peasant name at the time, and the largest sets nest more than 50 dolls."),
        QuizQuestion(id: "q_balalaika", prompt: "Which country does this triangular three-string instrument come from?",
                     art: Illustration(emoji: "🎸", imageName: "q_balalaika", tintIndex: 0),
                     answerID: "RUS", distractorID: "UKR",
                     fact: "The balalaika's triangular body makes it instantly recognisable. It was first mentioned in a 1688 police report, and it comes in six sizes, from a tiny piccolo to a contrabass taller than the player."),

        // India
        QuizQuestion(id: "q_butter_chicken", prompt: "Which country is renowned for its rich butter chicken?",
                     art: Illustration(emoji: "🍛", imageName: "q_butter_chicken", tintIndex: 1),
                     answerID: "IND", distractorID: "PAK",
                     fact: "Butter chicken was invented in the 1950s at the Moti Mahal restaurant in Delhi, where cooks simmered leftover tandoori chicken in a creamy tomato and butter sauce so it wouldn't go to waste."),
        QuizQuestion(id: "q_taj_mahal", prompt: "Which country is home to this white marble mausoleum?",
                     art: Illustration(emoji: "🕌", imageName: "q_taj_mahal", tintIndex: 0),
                     answerID: "IND", distractorID: "PAK",
                     fact: "The Taj Mahal was built by Emperor Shah Jahan in memory of his wife Mumtaz Mahal. About 20,000 workers spent 22 years on it, and its marble changes colour with the light of day."),

        // South Korea
        QuizQuestion(id: "q_hanbok", prompt: "Which country's iconic national dress is the elegant silk hanbok?",
                     art: Illustration(emoji: "👘", imageName: "q_hanbok", tintIndex: 3),
                     answerID: "KOR", distractorID: "MYS",
                     fact: "The hanbok's look, a short jacket over a full, flowing skirt, has barely changed since the Joseon dynasty 600 years ago. Colours once showed your rank: only royals wore gold."),
        QuizQuestion(id: "q_kimchi", prompt: "Which country's signature dish is this spicy fermented cabbage?",
                     art: Illustration(emoji: "🥬", imageName: "q_kimchi", tintIndex: 2),
                     answerID: "KOR", distractorID: "CHN",
                     fact: "Kimjang, the tradition of families gathering to make kimchi for the winter, is on UNESCO's heritage list. There are more than 200 kinds of kimchi, and Seoul even has a kimchi museum."),

        // Thailand
        QuizQuestion(id: "q_pad_thai", prompt: "Which country does this stir-fried noodle dish belong to?",
                     art: Illustration(emoji: "🍜", imageName: "q_pad_thai", tintIndex: 1),
                     answerID: "THA", distractorID: "VNM",
                     fact: "Pad thai is younger than it looks. In the late 1930s the Thai government promoted it as a national dish to build unity and to use noodles instead of rice during a shortage."),
        QuizQuestion(id: "q_muay_thai", prompt: "Which country's fighters practise this martial art, the \"art of eight limbs\"?",
                     art: Illustration(emoji: "🥊", imageName: "q_muay_thai", tintIndex: 4),
                     answerID: "THA", distractorID: "KHM",
                     fact: "Muay Thai uses fists, elbows, knees and shins, hence eight limbs. Before every fight the boxer performs the wai khru, a slow dance that honours their teacher."),

        // Scotland
        QuizQuestion(id: "q_kilt", prompt: "Which nation's traditional dress features men wearing tartan kilts?",
                     art: Illustration(emoji: "🏴󠁧󠁢󠁳󠁣󠁴󠁿", imageName: "q_kilt", tintIndex: 2),
                     answerID: "GBR", distractorID: "IRL",
                     fact: "Every tartan is a registered pattern, and the Scottish Register of Tartans lists thousands of them. The original 16th-century \"great kilt\" was a single huge cloth wrapped around the whole body."),
        QuizQuestion(id: "q_haggis", prompt: "Which country gives us haggis, a savoury pudding of oats and spices?",
                     art: Illustration(emoji: "🥘", imageName: "q_haggis", tintIndex: 4),
                     answerID: "GBR", distractorID: "IRL",
                     fact: "Haggis is the star of Burns Night on 25 January, served with neeps and tatties while someone recites Robert Burns' poem \"Address to a Haggis\" and stabs it with a knife."),

        // Italy
        QuizQuestion(id: "q_venetian_mask", prompt: "Which country is famous for these masks worn during Carnival?",
                     art: Illustration(emoji: "🎭", imageName: "q_venetian_mask", tintIndex: 3),
                     answerID: "ITA", distractorID: "FRA",
                     fact: "Venetian mask-makers had their own guild as early as 1436. Behind a mask, nobles and servants could mingle as equals, which is exactly why the Republic eventually restricted them."),
        QuizQuestion(id: "q_espresso", prompt: "Which country invented the espresso machine?",
                     art: Illustration(emoji: "☕", imageName: "q_espresso", tintIndex: 4),
                     answerID: "ITA", distractorID: "FRA",
                     fact: "The first espresso machine was patented in Turin in 1884. Italians drink it in seconds, standing at the bar, and ordering a cappuccino after lunch still raises eyebrows."),

        // Egypt
        QuizQuestion(id: "q_koshari", prompt: "Which country's favourite street food is this mix of rice, lentils and pasta?",
                     art: Illustration(emoji: "🍲", imageName: "q_koshari", tintIndex: 1),
                     answerID: "EGY", distractorID: "LBN",
                     fact: "Koshari piles rice, lentils, macaroni and chickpeas under spicy tomato sauce and crispy onions. It's cheap, filling and vegetarian, and Cairo has restaurants that serve nothing else."),
        QuizQuestion(id: "q_tutankhamun", prompt: "Which country is this golden pharaoh's mask from?",
                     art: Illustration(emoji: "👑", imageName: "q_tutankhamun", tintIndex: 4),
                     answerID: "EGY", distractorID: "SDN",
                     fact: "Tutankhamun's funeral mask is more than 3,300 years old and made of over 10 kg of solid gold. His tomb lay untouched until Howard Carter opened it in 1922."),

        // Mexico
        QuizQuestion(id: "q_sugar_skull", prompt: "Which country decorates these sugar skulls for the Day of the Dead?",
                     art: Illustration(emoji: "💀", imageName: "q_sugar_skull", tintIndex: 3),
                     answerID: "MEX", distractorID: "ESP",
                     fact: "On 1 and 2 November families build altars with marigolds, food and sugar skulls to welcome back the spirits of loved ones. It's a joyful celebration, not a sad one."),
        QuizQuestion(id: "q_mariachi", prompt: "Which country is home to mariachi music?",
                     art: Illustration(emoji: "🎺", imageName: "q_mariachi", tintIndex: 1),
                     answerID: "MEX", distractorID: "COL",
                     fact: "Mariachi began in the state of Jalisco and is now on UNESCO's heritage list. The musicians' silver-studded charro suits were originally the outfits of Mexican horsemen."),

        // Morocco
        QuizQuestion(id: "q_tagine", prompt: "Which country slow-cooks its stews in this cone-shaped clay pot?",
                     art: Illustration(emoji: "🫕", imageName: "q_tagine", tintIndex: 1),
                     answerID: "MAR", distractorID: "TUN",
                     fact: "The tagine's cone lid traps steam and drips it back down, so a stew can simmer for hours with almost no water. The word means both the pot and the dish cooked in it."),
    ]

    // MARK: Landmarks (shown when you visit an unlocked country)

    static let landmarks: [String: [Landmark]] = [
        "IRN": [
            Landmark(name: "Azadi Tower", description: "A symbol of Tehran, built in 1971 and now the city's best known landmark.", art: Illustration(emoji: "🏙️", imageName: "l_iran_azadi", tintIndex: 0)),
            Landmark(name: "Persepolis", description: "The ceremonial capital of the Persian Empire, founded by Darius the Great around 518 BC.", art: Illustration(emoji: "🏛️", imageName: "l_iran_persepolis", tintIndex: 4)),
            Landmark(name: "Naqsh-e Jahan Square", description: "A vast 17th-century square in Isfahan, ringed by mosques, palaces and a bazaar.", art: Illustration(emoji: "🕌", imageName: "l_iran_isfahan", tintIndex: 3)),
        ],
        "JPN": [
            Landmark(name: "Mount Fuji", description: "Japan's highest peak at 3,776 m, and still an active volcano. It last erupted in 1707.", art: Illustration(emoji: "🗻", imageName: "l_japan_fuji", tintIndex: 0)),
            Landmark(name: "Fushimi Inari", description: "A shrine in Kyoto famous for its paths lined with thousands of bright red torii gates.", art: Illustration(emoji: "⛩️", imageName: "l_japan_inari", tintIndex: 1)),
        ],
        "TUR": [
            Landmark(name: "Hagia Sophia", description: "Built in 537 as a cathedral, later a mosque, then a museum, and a mosque again. Its dome amazed architects for a thousand years.", art: Illustration(emoji: "🕌", imageName: "l_turkey_hagia_sophia", tintIndex: 0)),
            Landmark(name: "Cappadocia", description: "A landscape of \"fairy chimney\" rock towers and cave homes, best seen from a hot-air balloon at sunrise.", art: Illustration(emoji: "🎈", imageName: "l_turkey_cappadocia", tintIndex: 1)),
        ],
        "RUS": [
            Landmark(name: "Saint Basil's Cathedral", description: "The candy-coloured onion domes on Red Square were completed in 1561 to celebrate a military victory.", art: Illustration(emoji: "⛪", imageName: "l_russia_st_basils", tintIndex: 3)),
            Landmark(name: "Lake Baikal", description: "The deepest lake on Earth, holding about a fifth of the world's unfrozen fresh water.", art: Illustration(emoji: "🏞️", imageName: "l_russia_baikal", tintIndex: 0)),
        ],
        "IND": [
            Landmark(name: "Taj Mahal", description: "A white marble mausoleum in Agra, built in the 1600s and visited by millions every year.", art: Illustration(emoji: "🕌", imageName: "q_taj_mahal", tintIndex: 0)),
            Landmark(name: "Hawa Mahal", description: "Jaipur's \"Palace of Winds\" has 953 small windows so royal women could watch the street unseen.", art: Illustration(emoji: "🏰", imageName: "l_india_hawa_mahal", tintIndex: 1)),
        ],
        "KOR": [
            Landmark(name: "Gyeongbokgung Palace", description: "The main royal palace of the Joseon dynasty, built in 1395 in the heart of Seoul.", art: Illustration(emoji: "🏯", imageName: "l_korea_gyeongbokgung", tintIndex: 2)),
            Landmark(name: "Jeju Island", description: "A volcanic island famous for its haenyeo, women divers who harvest seafood without breathing gear.", art: Illustration(emoji: "🌋", imageName: "l_korea_jeju", tintIndex: 0)),
        ],
        "THA": [
            Landmark(name: "Grand Palace", description: "Bangkok's dazzling royal complex, built in 1782, home of the Emerald Buddha.", art: Illustration(emoji: "🛕", imageName: "l_thailand_grand_palace", tintIndex: 4)),
            Landmark(name: "Wat Arun", description: "The Temple of Dawn on the Chao Phraya river, covered in colourful porcelain pieces.", art: Illustration(emoji: "🛕", imageName: "l_thailand_wat_arun", tintIndex: 0)),
        ],
        "GBR": [
            Landmark(name: "Edinburgh Castle", description: "A fortress on top of an extinct volcano that has watched over Edinburgh for 900 years.", art: Illustration(emoji: "🏰", imageName: "l_scotland_edinburgh_castle", tintIndex: 2)),
            Landmark(name: "Loch Ness", description: "A deep, dark lake in the Highlands, and the home of a monster that nobody has quite managed to photograph.", art: Illustration(emoji: "🦕", imageName: "l_scotland_loch_ness", tintIndex: 0)),
        ],
        "ITA": [
            Landmark(name: "Colosseum", description: "Rome's giant amphitheatre, completed in AD 80, once held more than 50,000 spectators.", art: Illustration(emoji: "🏛️", imageName: "l_italy_colosseum", tintIndex: 4)),
            Landmark(name: "Canals of Venice", description: "A city without roads, where boats are the taxis, buses and ambulances.", art: Illustration(emoji: "🛶", imageName: "l_italy_venice", tintIndex: 2)),
        ],
        "EGY": [
            Landmark(name: "Great Pyramid of Giza", description: "About 4,500 years old and the only surviving Wonder of the Ancient World.", art: Illustration(emoji: "🏜️", imageName: "l_egypt_pyramids", tintIndex: 4)),
            Landmark(name: "Luxor Temple", description: "A temple on the Nile built around 1400 BC, lit up beautifully at night.", art: Illustration(emoji: "🏛️", imageName: "l_egypt_luxor", tintIndex: 1)),
        ],
        "MEX": [
            Landmark(name: "Chichén Itzá", description: "A great Maya city. At the equinox, the pyramid's shadow looks like a serpent sliding down the steps.", art: Illustration(emoji: "🛕", imageName: "l_mexico_chichen", tintIndex: 2)),
            Landmark(name: "Casa Azul", description: "The bright blue house in Mexico City where painter Frida Kahlo was born and lived.", art: Illustration(emoji: "🏠", imageName: "l_mexico_casa_azul", tintIndex: 0)),
        ],
        "MAR": [
            Landmark(name: "Jemaa el-Fnaa", description: "Marrakesh's main square turns into an open-air theatre every evening, with storytellers, musicians and food stalls.", art: Illustration(emoji: "🎪", imageName: "l_morocco_jemaa", tintIndex: 1)),
            Landmark(name: "Chefchaouen", description: "A mountain town where almost every wall, step and doorway is painted blue.", art: Illustration(emoji: "🏘️", imageName: "l_morocco_chefchaouen", tintIndex: 0)),
        ],
    ]
}
