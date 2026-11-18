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

/// A question of any kind, as the quiz screen sees it. Options can be countries (with a flag)
/// or plain text answers.
struct Question: Identifiable, Hashable, Sendable {
    struct Option: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        var flag: String? = nil
        var countryID: String? = nil
    }

    let id: String
    let countryID: String           // the country this question is about
    let prompt: String
    let art: Illustration?
    let options: [Option]
    let correctID: String
    let fact: String
}

/// A text question about one country (food, festivals, places, words...). Max 4 options.
struct CountryQuizQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let countryID: String
    let prompt: String
    var art: Illustration? = nil
    let options: [String]
    let correct: Int                // index into options
    let fact: String

    /// Options are shuffled here, once per session, so the right answer moves around.
    var asQuestion: Question {
        Question(id: id, countryID: countryID, prompt: prompt, art: art,
                 options: options.enumerated().shuffled().map { Question.Option(id: "\(id)-\($0.offset)", title: $0.element) },
                 correctID: "\(id)-\(correct)",
                 fact: fact)
    }
}

extension QuizQuestion {
    var asQuestion: Question {
        Question(id: id, countryID: answerID, prompt: prompt, art: art,
                 options: optionIDs.map { cid in
                     let c = ContentLibrary.country(cid)
                     return Question.Option(id: cid, title: c?.name ?? cid, flag: c?.flag, countryID: cid)
                 },
                 correctID: answerID,
                 fact: fact)
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
    enum Mode: Hashable {
        case world                      // photo questions, every right answer unlocks a country
        case country(QuizCountry)       // questions about one country, unlock by scoring enough
    }
    let id = UUID()
    let mode: Mode
    let questions: [Question]
}

// MARK: - Library

enum ContentLibrary {
    /// Countries whose flag is drawn from an image in Assets instead of the emoji.
    static let flagImages: [String: String] = [
        "IRN": "flag_iran",
    ]

    static let questionsPerSession = 5
    static let countryQuizLength = 4
    static let countryUnlockThreshold = 3   // correct answers needed in a country quiz to unlock it
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
        return QuizSession(mode: .world, questions: picked.map(\.asQuestion))
    }

    /// Builds a quiz about one country: four varied questions in random order.
    static func makeCountrySession(for country: QuizCountry) -> QuizSession {
        let qs = countryQuestions.filter { $0.countryID == country.id }.shuffled()
        return QuizSession(mode: .country(country),
                           questions: Array(qs.prefix(countryQuizLength)).map(\.asQuestion))
    }

    static func hasCountryQuiz(_ countryID: String) -> Bool {
        countryQuestions.contains { $0.countryID == countryID }
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
        QuizCountry(id: "KHM", name: "Cambodia", flag: "🇰🇭"),
        QuizCountry(id: "JOR", name: "Jordan", flag: "🇯🇴"),
        // Distractors only (for now)
        QuizCountry(id: "AZE", name: "Azerbaijan", flag: "🇦🇿"),
        QuizCountry(id: "GRC", name: "Greece", flag: "🇬🇷"),
        QuizCountry(id: "POL", name: "Poland", flag: "🇵🇱"),
        QuizCountry(id: "UKR", name: "Ukraine", flag: "🇺🇦"),
        QuizCountry(id: "PAK", name: "Pakistan", flag: "🇵🇰"),
        QuizCountry(id: "MYS", name: "Malaysia", flag: "🇲🇾"),
        QuizCountry(id: "CHN", name: "China", flag: "🇨🇳"),
        QuizCountry(id: "VNM", name: "Vietnam", flag: "🇻🇳"),
        QuizCountry(id: "IRL", name: "Ireland", flag: "🇮🇪"),
        QuizCountry(id: "SAU", name: "Saudi Arabia", flag: "🇸🇦"),
        QuizCountry(id: "LAO", name: "Laos", flag: "🇱🇦"),
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

        QuizQuestion(id: "q_sombrero", prompt: "Which country is this wide-brimmed hat from?",
                     art: Illustration(emoji: "👒", imageName: "q_sombrero", tintIndex: 4),
                     answerID: "MEX", distractorID: "ESP",
                     fact: "Sombrero simply means \"shade-maker\" in Spanish. The wide brim was designed for horsemen working under the Mexican sun, and mariachi musicians still wear the fancy embroidered version."),

        QuizQuestion(id: "q_badgir", prompt: "Which country cooled its houses with these wind towers, centuries before air conditioning?",
                     art: Illustration(emoji: "🏯", imageName: "q_badgir", tintIndex: 1),
                     answerID: "IRN", distractorID: "MAR",
                     fact: "A badgir, or windcatcher, catches the breeze high above the roof and pushes it down into the house, often over a pool of water. The city of Yazd has hundreds of them."),

        // Cambodia
        QuizQuestion(id: "q_angkor_wat", prompt: "Which country is home to this vast temple, the largest religious monument on Earth?",
                     art: Illustration(emoji: "🛕", imageName: "q_angkor_wat", tintIndex: 2),
                     answerID: "KHM", distractorID: "THA",
                     fact: "Angkor Wat was built in the 12th century and covers about 160 hectares. It's the only building in the world that appears on a national flag."),

        // Jordan
        QuizQuestion(id: "q_petra", prompt: "Which country hides this city carved straight into the rock?",
                     art: Illustration(emoji: "🏜️", imageName: "q_petra", tintIndex: 1),
                     answerID: "JOR", distractorID: "EGY",
                     fact: "Petra was carved by the Nabataeans more than 2,000 years ago and forgotten by the outside world until 1812. This building, the Monastery, is reached by climbing about 800 steps."),

        // Morocco
        QuizQuestion(id: "q_tagine", prompt: "Which country slow-cooks its stews in this cone-shaped clay pot?",
                     art: Illustration(emoji: "🫕", imageName: "q_tagine", tintIndex: 1),
                     answerID: "MAR", distractorID: "TUN",
                     fact: "The tagine's cone lid traps steam and drips it back down, so a stew can simmer for hours with almost no water. The word means both the pot and the dish cooked in it."),
    ]

    // MARK: Country briefs (shown above the monuments)

    static let briefs: [String: String] = [
        "IRN": "Home of one of the world's oldest civilisations, Iran gave us Persian poetry, saffron rice, intricate carpets and gardens so beautiful they inspired the word \"paradise\".",
        "JPN": "An island nation where ancient temples sit beside neon cities. Japan is known for sushi, cherry blossoms, bullet trains and a deep respect for craft and detail.",
        "TUR": "Turkey bridges Europe and Asia. Expect endless cups of tea, bazaars, hammams, baklava and a history that runs from the Byzantines to the Ottomans.",
        "RUS": "The largest country on Earth, stretching across eleven time zones. Russia is famous for ballet, onion-domed churches, long winters and even longer novels.",
        "IND": "A land of a thousand flavours and festivals. India gave the world chess, yoga, the Taj Mahal and some of the most colourful celebrations anywhere.",
        "KOR": "South Korea mixes 600-year-old palaces with K-pop and super-fast internet. Kimchi is on every table and the hanbok is worn with pride on holidays.",
        "THA": "Known as the Land of Smiles, Thailand offers golden temples, floating markets, street food on every corner and a water festival that soaks the whole country.",
        "GBR": "Scotland is castles on crags, misty lochs, bagpipes and tartan. Its national animal is a unicorn and its New Year party, Hogmanay, lasts for days.",
        "ITA": "Italy is where pizza, espresso and the Renaissance were born. Every town has a piazza, a church and a strong opinion about how to cook pasta.",
        "EGY": "The gift of the Nile. Egypt's pyramids are 4,500 years old and still standing, and its street food, koshari, is as beloved as its pharaohs.",
        "MEX": "Mexico is colour, music and chilli. From Maya pyramids to Frida Kahlo, from mariachi to the Day of the Dead, it celebrates life loudly.",
        "KHM": "Cambodia is the land of the Khmer, whose ancient empire built Angkor, the largest temple complex on Earth. Today it's known for its warm people, floating villages and the Mekong river.",
        "JOR": "Jordan is a desert kingdom with Petra carved into its red cliffs, the salty Dead Sea at the lowest point on Earth, and some of the most welcoming hospitality in the Middle East.",
        "MAR": "Morocco is a feast for the senses: blue-washed Chefchaouen, the spice markets of Marrakesh, Friday couscous and tagines bubbling on every stove.",
    ]

    // MARK: Country quizzes (four varied questions per country, the country is never the answer)

    static let countryQuestions: [CountryQuizQuestion] = [
        // Iran
        CountryQuizQuestion(id: "c_irn_1", countryID: "IRN", prompt: "What is the Persian New Year called?",
                            art: Illustration(emoji: "🌱", imageName: "c_irn_nowruz", tintIndex: 2),
                            options: ["Nowruz", "Diwali", "Songkran"], correct: 0,
                            fact: "Nowruz begins at the exact moment of the spring equinox and has been celebrated for more than 3,000 years."),
        CountryQuizQuestion(id: "c_irn_2", countryID: "IRN", prompt: "Iran grows about 90% of the world's supply of which spice?",
                            art: Illustration(emoji: "🌼", imageName: "c_irn_saffron", tintIndex: 4),
                            options: ["Saffron", "Vanilla", "Cinnamon"], correct: 0,
                            fact: "Saffron threads are picked by hand from crocus flowers, which is why it's the most expensive spice on Earth."),
        CountryQuizQuestion(id: "c_irn_3", countryID: "IRN", prompt: "What is the capital of Iran?",
                            art: Illustration(emoji: "🏙️", imageName: "l_iran_azadi", tintIndex: 0),
                            options: ["Tehran", "Isfahan", "Shiraz"], correct: 0,
                            fact: "Tehran sits at the foot of the snowy Alborz mountains. You can ski in the morning and be in the bazaar by lunch."),
        CountryQuizQuestion(id: "c_irn_4", countryID: "IRN", prompt: "Which poet's tomb in Shiraz do Iranians love to visit?",
                            art: Illustration(emoji: "📖", imageName: "c_irn_hafez", tintIndex: 3),
                            options: ["Hafez", "Shakespeare", "Homer"], correct: 0,
                            fact: "Many Iranian homes keep a copy of Hafez's poems and open it at random to ask for advice, a tradition called fal-e Hafez."),

        CountryQuizQuestion(id: "c_irn_5", countryID: "IRN", prompt: "Which Persian instrument is this, with four strings and a small pear-shaped body?",
                            art: Illustration(emoji: "🪕", imageName: "c_irn_setar", tintIndex: 4),
                            options: ["Setar", "Sitar", "Oud"], correct: 0,
                            fact: "Setar means \"three strings\" in Persian, though a fourth was added about 200 years ago. It's played with the nail of the index finger and the Indian sitar borrowed its name."),
        CountryQuizQuestion(id: "c_irn_6", countryID: "IRN", prompt: "What is this tower on top of a traditional Iranian house for?",
                            art: Illustration(emoji: "🏯", imageName: "q_badgir", tintIndex: 1),
                            options: ["Catching the wind to cool the house", "Watching for enemies", "Storing grain"], correct: 0,
                            fact: "It's a badgir, or windcatcher. Yazd, a desert city, is full of them, and they can drop the temperature inside by ten degrees without electricity."),

        // Japan
        CountryQuizQuestion(id: "c_jpn_1", countryID: "JPN", prompt: "What is the traditional Japanese tea ceremony called?",
                            art: Illustration(emoji: "🍵", imageName: "q_matcha", tintIndex: 2),
                            options: ["Chanoyu", "Kintsugi", "Ikebana"], correct: 0,
                            fact: "Chanoyu, \"the way of tea\", follows four ideals: harmony, respect, purity and tranquillity."),
        CountryQuizQuestion(id: "c_jpn_2", countryID: "JPN", prompt: "Which mountain is Japan's highest?",
                            art: Illustration(emoji: "🗻", imageName: "l_japan_fuji", tintIndex: 0),
                            options: ["Mount Fuji", "Mount Aso", "Mount Tate"], correct: 0,
                            fact: "Mount Fuji is 3,776 m tall and still an active volcano. It last erupted in 1707."),
        CountryQuizQuestion(id: "c_jpn_3", countryID: "JPN", prompt: "What do the Japanese call picnicking under the cherry blossoms?",
                            art: Illustration(emoji: "🌸", imageName: "c_jpn_hanami", tintIndex: 3),
                            options: ["Hanami", "Obon", "Karaoke"], correct: 0,
                            fact: "Hanami means \"flower viewing\". The blossoms last only about a week, which is part of why they're loved so much."),
        CountryQuizQuestion(id: "c_jpn_4", countryID: "JPN", prompt: "What is the Japanese art of folding paper called?",
                            art: Illustration(emoji: "🕊️", imageName: "c_jpn_origami", tintIndex: 1),
                            options: ["Origami", "Sudoku", "Bonsai"], correct: 0,
                            fact: "Classic origami uses a single square sheet with no cuts. A thousand folded cranes is a traditional wish for good luck."),

        // Turkey
        CountryQuizQuestion(id: "c_tur_1", countryID: "TUR", prompt: "Which Turkish city sits on two continents?",
                            art: Illustration(emoji: "🕌", imageName: "l_turkey_hagia_sophia", tintIndex: 0),
                            options: ["Istanbul", "Ankara", "Izmir"], correct: 0,
                            fact: "The Bosphorus strait splits Istanbul between Europe and Asia. Ankara, not Istanbul, is the capital."),
        CountryQuizQuestion(id: "c_tur_2", countryID: "TUR", prompt: "What is the Turkish bath called?",
                            art: Illustration(emoji: "🧖", imageName: "c_tur_hamam", tintIndex: 2),
                            options: ["Hamam", "Sauna", "Onsen"], correct: 0,
                            fact: "A hamam visit ends with a scrub on a heated marble slab. Many Istanbul hamams are over 400 years old."),
        CountryQuizQuestion(id: "c_tur_3", countryID: "TUR", prompt: "Which region is famous for balloon rides over \"fairy chimneys\"?",
                            art: Illustration(emoji: "🎈", imageName: "l_turkey_cappadocia", tintIndex: 1),
                            options: ["Cappadocia", "Antalya", "Bodrum"], correct: 0,
                            fact: "Cappadocia's rock towers were carved by wind and rain, and people hollowed homes and churches into them."),
        CountryQuizQuestion(id: "c_tur_4", countryID: "TUR", prompt: "How do Turks usually drink their tea?",
                            art: Illustration(emoji: "🫖", imageName: "q_turkish_tea", tintIndex: 1),
                            options: ["Black, in a small tulip glass", "With milk, in a mug", "Cold, with lemon"], correct: 0,
                            fact: "Turkey drinks more tea per person than any other country, about 3 kg a year each."),

        // Russia
        CountryQuizQuestion(id: "c_rus_1", countryID: "RUS", prompt: "How many time zones does Russia span?",
                            art: Illustration(emoji: "🕰️", imageName: "c_rus_transsiberian", tintIndex: 0),
                            options: ["11", "5", "3"], correct: 0,
                            fact: "When it's breakfast in Kaliningrad in the west, it's already dinner time in Kamchatka in the east."),
        CountryQuizQuestion(id: "c_rus_2", countryID: "RUS", prompt: "Which Russian lake is the deepest in the world?",
                            art: Illustration(emoji: "🏞️", imageName: "l_russia_baikal", tintIndex: 0),
                            options: ["Lake Baikal", "Lake Ladoga", "Lake Onega"], correct: 0,
                            fact: "Baikal holds about a fifth of the world's unfrozen fresh water and is home to the only freshwater seal."),
        CountryQuizQuestion(id: "c_rus_3", countryID: "RUS", prompt: "What are Russian nesting dolls called?",
                            art: Illustration(emoji: "🪆", imageName: "q_matryoshka", tintIndex: 1),
                            options: ["Matryoshka", "Babushka", "Balalaika"], correct: 0,
                            fact: "The first set was carved near Moscow in 1890. Babushka means grandmother, and a balalaika is an instrument."),
        CountryQuizQuestion(id: "c_rus_4", countryID: "RUS", prompt: "Which famous ballet theatre is in Moscow?",
                            art: Illustration(emoji: "🩰", imageName: "c_rus_bolshoi", tintIndex: 3),
                            options: ["Bolshoi", "La Scala", "Royal Opera House"], correct: 0,
                            fact: "Bolshoi means \"big\". Swan Lake premiered there in 1877."),

        // India
        CountryQuizQuestion(id: "c_ind_1", countryID: "IND", prompt: "What is India's spring festival of colours called?",
                            art: Illustration(emoji: "🎨", imageName: "c_ind_holi", tintIndex: 3),
                            options: ["Holi", "Diwali", "Eid"], correct: 0,
                            fact: "During Holi people throw coloured powder and water at each other, and for one day differences of rank are forgotten."),
        CountryQuizQuestion(id: "c_ind_2", countryID: "IND", prompt: "In which city is the Taj Mahal?",
                            art: Illustration(emoji: "🕌", imageName: "q_taj_mahal", tintIndex: 0),
                            options: ["Agra", "Delhi", "Jaipur"], correct: 0,
                            fact: "Shah Jahan built it for his wife Mumtaz Mahal. Its marble looks pink at dawn, white at noon and golden by moonlight."),
        CountryQuizQuestion(id: "c_ind_3", countryID: "IND", prompt: "What is the flatbread baked in a clay tandoor oven called?",
                            art: Illustration(emoji: "🫓", imageName: "q_butter_chicken", tintIndex: 1),
                            options: ["Naan", "Baguette", "Pita"], correct: 0,
                            fact: "Naan is slapped onto the hot wall of the tandoor and puffs up in seconds. It's the classic partner for butter chicken."),
        CountryQuizQuestion(id: "c_ind_4", countryID: "IND", prompt: "Which board game was invented in ancient India?",
                            art: Illustration(emoji: "♟️", imageName: "c_ind_chess", tintIndex: 2),
                            options: ["Chess", "Backgammon", "Go"], correct: 0,
                            fact: "Chess began as chaturanga around the 6th century. Its four pieces were infantry, cavalry, elephants and chariots."),

        // South Korea
        CountryQuizQuestion(id: "c_kor_1", countryID: "KOR", prompt: "What is the traditional Korean dress called?",
                            art: Illustration(emoji: "👘", imageName: "q_hanbok", tintIndex: 3),
                            options: ["Hanbok", "Kimono", "Ao dai"], correct: 0,
                            fact: "The hanbok's short jacket and full skirt have barely changed in 600 years. There's even a Hanbok Day on 21 October."),
        CountryQuizQuestion(id: "c_kor_2", countryID: "KOR", prompt: "What is the Korean alphabet called?",
                            art: Illustration(emoji: "✍️", imageName: "c_kor_hangul", tintIndex: 0),
                            options: ["Hangul", "Kanji", "Hiragana"], correct: 0,
                            fact: "King Sejong created Hangul in 1443 so ordinary people could learn to read. Its 24 letters can be learned in a day."),
        CountryQuizQuestion(id: "c_kor_3", countryID: "KOR", prompt: "What is the capital of South Korea?",
                            art: Illustration(emoji: "🏯", imageName: "l_korea_gyeongbokgung", tintIndex: 2),
                            options: ["Seoul", "Busan", "Incheon"], correct: 0,
                            fact: "Seoul has been a capital for over 600 years. Gyeongbokgung Palace, built in 1395, still stands in its centre."),
        CountryQuizQuestion(id: "c_kor_4", countryID: "KOR", prompt: "What is kimjang?",
                            art: Illustration(emoji: "🥬", imageName: "c_kor_kimjang", tintIndex: 2),
                            options: ["Making kimchi together for winter", "A spring dance", "A tea ceremony"], correct: 0,
                            fact: "Every autumn families and neighbours gather to prepare hundreds of cabbages. UNESCO lists kimjang as cultural heritage."),

        // Thailand
        CountryQuizQuestion(id: "c_tha_1", countryID: "THA", prompt: "What is the capital of Thailand?",
                            art: Illustration(emoji: "🛕", imageName: "l_thailand_grand_palace", tintIndex: 4),
                            options: ["Bangkok", "Chiang Mai", "Phuket"], correct: 0,
                            fact: "Bangkok's full ceremonial name is 168 letters long, one of the longest place names in the world."),
        CountryQuizQuestion(id: "c_tha_2", countryID: "THA", prompt: "What is the Thai New Year water festival called?",
                            art: Illustration(emoji: "💦", imageName: "c_tha_songkran", tintIndex: 0),
                            options: ["Songkran", "Loi Krathong", "Holi"], correct: 0,
                            fact: "In mid-April the whole country turns into a giant water fight. Getting soaked is a blessing for the year ahead."),
        CountryQuizQuestion(id: "c_tha_3", countryID: "THA", prompt: "What is the Thai greeting with palms pressed together called?",
                            art: Illustration(emoji: "🙏", imageName: "c_tha_wai", tintIndex: 1),
                            options: ["Wai", "Bow", "Salute"], correct: 0,
                            fact: "The higher the hands, the more respect you show. A wai to a monk goes right up to the forehead."),
        CountryQuizQuestion(id: "c_tha_4", countryID: "THA", prompt: "Which martial art is called the \"art of eight limbs\"?",
                            art: Illustration(emoji: "🥊", imageName: "q_muay_thai", tintIndex: 4),
                            options: ["Muay Thai", "Taekwondo", "Karate"], correct: 0,
                            fact: "Fists, elbows, knees and shins make eight. Before each fight the boxer dances the wai khru to honour their teacher."),

        // Scotland
        CountryQuizQuestion(id: "c_gbr_1", countryID: "GBR", prompt: "What is Scotland's national animal?",
                            art: Illustration(emoji: "🦄", imageName: "c_gbr_unicorn", tintIndex: 3),
                            options: ["Unicorn", "Lion", "Stag"], correct: 0,
                            fact: "Really. The unicorn has been on Scottish royal coats of arms since the 1400s as a symbol of purity and power."),
        CountryQuizQuestion(id: "c_gbr_2", countryID: "GBR", prompt: "What is the capital of Scotland?",
                            art: Illustration(emoji: "🏰", imageName: "l_scotland_edinburgh_castle", tintIndex: 2),
                            options: ["Edinburgh", "Glasgow", "Aberdeen"], correct: 0,
                            fact: "Glasgow is bigger, but Edinburgh is the capital, with a castle on an extinct volcano right in the middle of town."),
        CountryQuizQuestion(id: "c_gbr_3", countryID: "GBR", prompt: "What is celebrated on Burns Night, 25 January?",
                            art: Illustration(emoji: "🥘", imageName: "q_haggis", tintIndex: 4),
                            options: ["The poet Robert Burns", "The New Year", "Scottish independence"], correct: 0,
                            fact: "Haggis is carried in to bagpipes, someone recites Burns' poem to it, then stabs it open with a knife."),
        CountryQuizQuestion(id: "c_gbr_4", countryID: "GBR", prompt: "What do Scots call New Year's Eve?",
                            art: Illustration(emoji: "🎆", imageName: "c_gbr_hogmanay", tintIndex: 0),
                            options: ["Hogmanay", "Ceilidh", "Tattoo"], correct: 0,
                            fact: "Hogmanay parties can last three days. The first person through your door after midnight should bring coal or whisky for luck."),

        // Italy
        CountryQuizQuestion(id: "c_ita_1", countryID: "ITA", prompt: "Which city is the birthplace of pizza?",
                            art: Illustration(emoji: "🍕", imageName: "c_ita_pizza", tintIndex: 1),
                            options: ["Naples", "Rome", "Milan"], correct: 0,
                            fact: "The pizza Margherita was made in Naples in 1889 for Queen Margherita, in the colours of the Italian flag."),
        CountryQuizQuestion(id: "c_ita_2", countryID: "ITA", prompt: "Which Italian city has canals instead of streets?",
                            art: Illustration(emoji: "🛶", imageName: "l_italy_venice", tintIndex: 2),
                            options: ["Venice", "Florence", "Genoa"], correct: 0,
                            fact: "Venice is built on more than 100 islands. Even the ambulances and rubbish collection are boats."),
        CountryQuizQuestion(id: "c_ita_3", countryID: "ITA", prompt: "Which Leonardo da Vinci painting is in Milan?",
                            art: Illustration(emoji: "🖼️", imageName: "c_ita_last_supper", tintIndex: 4),
                            options: ["The Last Supper", "Mona Lisa", "Starry Night"], correct: 0,
                            fact: "It's painted on a wall of a convent dining room. The Mona Lisa is in Paris, and Starry Night is by Van Gogh."),
        CountryQuizQuestion(id: "c_ita_4", countryID: "ITA", prompt: "Which drink would make a waiter frown if you ordered it after lunch?",
                            art: Illustration(emoji: "☕", imageName: "q_espresso", tintIndex: 4),
                            options: ["Cappuccino", "Espresso", "Water"], correct: 0,
                            fact: "Milky coffee is a morning thing in Italy. After a meal it's espresso only, drunk in seconds at the bar."),

        // Egypt
        CountryQuizQuestion(id: "c_egy_1", countryID: "EGY", prompt: "Which river flows through Egypt?",
                            art: Illustration(emoji: "⛵", imageName: "c_egy_nile", tintIndex: 0),
                            options: ["Nile", "Tigris", "Congo"], correct: 0,
                            fact: "Almost all Egyptians live along the Nile. The rest of the country is desert."),
        CountryQuizQuestion(id: "c_egy_2", countryID: "EGY", prompt: "What was the ancient Egyptian writing system called?",
                            art: Illustration(emoji: "📜", imageName: "c_egy_hieroglyphs", tintIndex: 4),
                            options: ["Hieroglyphs", "Cuneiform", "Sanskrit"], correct: 0,
                            fact: "Nobody could read hieroglyphs for 1,400 years until the Rosetta Stone unlocked them in 1822."),
        CountryQuizQuestion(id: "c_egy_3", countryID: "EGY", prompt: "Which is the largest pyramid at Giza?",
                            art: Illustration(emoji: "🏜️", imageName: "l_egypt_pyramids", tintIndex: 4),
                            options: ["Pyramid of Khufu", "Pyramid of Khafre", "Pyramid of Menkaure"], correct: 0,
                            fact: "The Great Pyramid of Khufu was the tallest building on Earth for nearly 4,000 years."),
        CountryQuizQuestion(id: "c_egy_4", countryID: "EGY", prompt: "What is Egypt's favourite street food, made of rice, lentils and pasta?",
                            art: Illustration(emoji: "🍲", imageName: "q_koshari", tintIndex: 1),
                            options: ["Koshari", "Falafel", "Shawarma"], correct: 0,
                            fact: "Koshari is topped with spicy tomato sauce and crispy onions. Cairo has restaurants that serve nothing else."),

        // Mexico
        CountryQuizQuestion(id: "c_mex_1", countryID: "MEX", prompt: "When is the Day of the Dead celebrated?",
                            art: Illustration(emoji: "💀", imageName: "q_sugar_skull", tintIndex: 3),
                            options: ["1 and 2 November", "31 October", "5 May"], correct: 0,
                            fact: "Families build altars with marigolds, food and photos to welcome back loved ones. It's joyful, not sad."),
        CountryQuizQuestion(id: "c_mex_2", countryID: "MEX", prompt: "Which civilisation built Chichén Itzá?",
                            art: Illustration(emoji: "🛕", imageName: "l_mexico_chichen", tintIndex: 2),
                            options: ["Maya", "Aztec", "Inca"], correct: 0,
                            fact: "At the equinox the pyramid's shadow looks like a serpent slithering down the steps. The Inca were in Peru."),
        CountryQuizQuestion(id: "c_mex_3", countryID: "MEX", prompt: "Which drink is made from the blue agave plant?",
                            art: Illustration(emoji: "🌵", imageName: "c_mex_agave", tintIndex: 2),
                            options: ["Tequila", "Rum", "Sake"], correct: 0,
                            fact: "Real tequila can only be made in a few Mexican regions, mostly around the town of Tequila in Jalisco."),
        CountryQuizQuestion(id: "c_mex_4", countryID: "MEX", prompt: "Which Mexican painter is famous for her self-portraits?",
                            art: Illustration(emoji: "🎨", imageName: "l_mexico_casa_azul", tintIndex: 3),
                            options: ["Frida Kahlo", "Georgia O'Keeffe", "Tamara de Lempicka"], correct: 0,
                            fact: "Frida painted herself 55 times, often with her pet monkeys and parrots. Her blue house in Mexico City is now a museum."),

        // Morocco
        CountryQuizQuestion(id: "c_mar_1", countryID: "MAR", prompt: "What is the capital of Morocco?",
                            art: Illustration(emoji: "🏛️", imageName: "c_mar_rabat", tintIndex: 1),
                            options: ["Rabat", "Casablanca", "Marrakesh"], correct: 0,
                            fact: "Casablanca is the biggest city and Marrakesh the most famous, but quiet Rabat on the Atlantic coast is the capital."),
        CountryQuizQuestion(id: "c_mar_2", countryID: "MAR", prompt: "Which Moroccan town is famous for its blue-painted streets?",
                            art: Illustration(emoji: "🏘️", imageName: "l_morocco_chefchaouen", tintIndex: 0),
                            options: ["Chefchaouen", "Fez", "Tangier"], correct: 0,
                            fact: "Nobody is sure why it's blue. Some say to keep mosquitoes away, others say it represents the sky."),
        CountryQuizQuestion(id: "c_mar_3", countryID: "MAR", prompt: "What is the clay pot with a cone-shaped lid called?",
                            art: Illustration(emoji: "🫕", imageName: "q_tagine", tintIndex: 1),
                            options: ["Tagine", "Wok", "Paella pan"], correct: 0,
                            fact: "The cone traps steam and drips it back, so a stew can simmer for hours with almost no water."),
        CountryQuizQuestion(id: "c_mar_4", countryID: "MAR", prompt: "Which dish do Moroccan families traditionally eat for Friday lunch?",
                            art: Illustration(emoji: "🥣", imageName: "c_mar_couscous", tintIndex: 4),
                            options: ["Couscous", "Risotto", "Sushi"], correct: 0,
                            fact: "Friday couscous, piled with vegetables and meat, is eaten after prayers. UNESCO added couscous to its heritage list in 2020."),

        // Cambodia
        CountryQuizQuestion(id: "c_khm_1", countryID: "KHM", prompt: "What is the capital of Cambodia?",
                            art: Illustration(emoji: "🏙️", tintIndex: 0),
                            options: ["Phnom Penh", "Siem Reap", "Hanoi"], correct: 0,
                            fact: "Phnom Penh sits where the Mekong and Tonlé Sap rivers meet. Siem Reap is the town next to Angkor, and Hanoi is in Vietnam."),
        CountryQuizQuestion(id: "c_khm_2", countryID: "KHM", prompt: "Which building appears on Cambodia's flag?",
                            art: Illustration(emoji: "🛕", imageName: "q_angkor_wat", tintIndex: 2),
                            options: ["Angkor Wat", "The Royal Palace", "A pagoda"], correct: 0,
                            fact: "Cambodia is the only country with a building on its flag. Angkor Wat has been there since 1850."),
        CountryQuizQuestion(id: "c_khm_3", countryID: "KHM", prompt: "What is the traditional Cambodian greeting called?",
                            art: Illustration(emoji: "🙏", tintIndex: 1),
                            options: ["Sampeah", "Wai", "Namaste"], correct: 0,
                            fact: "Palms together, a slight bow, and the higher the hands the more respect. It's the Khmer cousin of the Thai wai."),
        CountryQuizQuestion(id: "c_khm_4", countryID: "KHM", prompt: "What is Cambodia's famous fish curry steamed in banana leaves called?",
                            art: Illustration(emoji: "🍛", tintIndex: 2),
                            options: ["Amok", "Pho", "Laksa"], correct: 0,
                            fact: "Fish amok is often called the national dish. It's cooked with coconut milk and kroeung, a Khmer paste of lemongrass, galangal and turmeric."),

        // Jordan
        CountryQuizQuestion(id: "c_jor_1", countryID: "JOR", prompt: "What is the capital of Jordan?",
                            art: Illustration(emoji: "🏛️", tintIndex: 4),
                            options: ["Amman", "Petra", "Aqaba"], correct: 0,
                            fact: "Amman is built on seven hills, like Rome, and has a Roman amphitheatre in its centre that seats 6,000 people."),
        CountryQuizQuestion(id: "c_jor_2", countryID: "JOR", prompt: "Why can you float without trying in Jordan's Dead Sea?",
                            art: Illustration(emoji: "🌊", tintIndex: 0),
                            options: ["It's about ten times saltier than the ocean", "The water is very warm", "It's very shallow"], correct: 0,
                            fact: "The Dead Sea's shore is the lowest dry land on Earth, more than 400 m below sea level, and the water is so salty almost nothing lives in it."),
        CountryQuizQuestion(id: "c_jor_3", countryID: "JOR", prompt: "Who carved the city of Petra into the rock?",
                            art: Illustration(emoji: "🏜️", imageName: "q_petra", tintIndex: 1),
                            options: ["The Nabataeans", "The Romans", "The Egyptians"], correct: 0,
                            fact: "The Nabataeans were desert traders who grew rich on the spice route. They carved Petra's tombs and temples around 2,000 years ago and even built water channels through the rock."),
        CountryQuizQuestion(id: "c_jor_4", countryID: "JOR", prompt: "What is Jordan's national dish, lamb cooked in dried yoghurt and served on rice?",
                            art: Illustration(emoji: "🍚", tintIndex: 4),
                            options: ["Mansaf", "Shawarma", "Hummus"], correct: 0,
                            fact: "Mansaf is eaten with the right hand from one big shared platter. Serving it is the traditional way to honour a guest."),
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
        "KHM": [
            Landmark(name: "Angkor Wat", description: "The largest religious monument in the world, built in the 12th century and still in use. Sunrise over its five towers is a famous sight.", art: Illustration(emoji: "🛕", imageName: "q_angkor_wat", tintIndex: 2)),
            Landmark(name: "Bayon Temple", description: "A temple at Angkor Thom with more than 200 giant smiling stone faces carved into its towers.", art: Illustration(emoji: "🗿", imageName: "l_cambodia_bayon", tintIndex: 4)),
        ],
        "JOR": [
            Landmark(name: "Petra", description: "A city carved into pink sandstone cliffs by the Nabataeans. You enter through the Siq, a narrow gorge over a kilometre long.", art: Illustration(emoji: "🏜️", imageName: "q_petra", tintIndex: 1)),
            Landmark(name: "Wadi Rum", description: "A red desert of towering rock formations, where Bedouin still camp and several Mars films were shot.", art: Illustration(emoji: "🏜️", imageName: "l_jordan_wadi_rum", tintIndex: 4)),
        ],
        "MAR": [
            Landmark(name: "Jemaa el-Fnaa", description: "Marrakesh's main square turns into an open-air theatre every evening, with storytellers, musicians and food stalls.", art: Illustration(emoji: "🎪", imageName: "l_morocco_jemaa", tintIndex: 1)),
            Landmark(name: "Chefchaouen", description: "A mountain town where almost every wall, step and doorway is painted blue.", art: Illustration(emoji: "🏘️", imageName: "l_morocco_chefchaouen", tintIndex: 0)),
        ],
    ]
}
