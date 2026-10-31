import Foundation

struct QuizOption: Identifiable {
    let id = UUID()
    let text: String
    let signature: [TasteAxis: Double]
}

struct QuizQuestion: Identifiable {
    let id: String
    let prompt: String
    let options: [QuizOption]
}

enum QuizQuestionCatalog {
    static let abQuestions: [QuizQuestion] = [
        QuizQuestion(id: "Q1", prompt: String(localized: "If you did a month-long stay, where would it be?"), options: [
            QuizOption(text: String(localized: "A convenient city center with great infrastructure"), signature: [.natureUrban: 0.7]),
            QuizOption(text: String(localized: "Nature, with forest and sea outside your window"), signature: [.natureUrban: -0.7])
        ]),
        QuizQuestion(id: "Q2", prompt: String(localized: "What view do you want outside your window?"), options: [
            QuizOption(text: String(localized: "Wild nature"), signature: [.natureUrban: -0.7]),
            QuizOption(text: String(localized: "A city skyline"), signature: [.natureUrban: 0.7])
        ]),
        QuizQuestion(id: "Q3", prompt: String(localized: "What's a perfect afternoon on a trip?"), options: [
            QuizOption(text: String(localized: "Quietly taking it easy"), signature: [.energyLevel: -0.7]),
            QuizOption(text: String(localized: "Packing it full of fun"), signature: [.energyLevel: 0.7])
        ]),
        QuizQuestion(id: "Q4", prompt: String(localized: "What do you want to hear after a trip?"), options: [
            QuizOption(text: String(localized: "\"You really got some rest\""), signature: [.energyLevel: -0.6]),
            QuizOption(text: String(localized: "\"You really made the most of it\""), signature: [.energyLevel: 0.6])
        ]),
        QuizQuestion(id: "Q5", prompt: String(localized: "What do you think in front of a beautiful night view?"), options: [
            QuizOption(text: String(localized: "I'll soak up this mood all by myself"), signature: [.socialMode: -0.7]),
            QuizOption(text: String(localized: "Ah, I wish I'd seen this with someone!"), signature: [.socialMode: 0.7])
        ]),
        QuizQuestion(id: "Q6", prompt: String(localized: "What's dinner like on a trip?"), options: [
            QuizOption(text: String(localized: "Quietly alone at a local favorite"), signature: [.socialMode: -0.7]),
            QuizOption(text: String(localized: "Lively with people I just met"), signature: [.socialMode: 0.7])
        ]),
        QuizQuestion(id: "Q7", prompt: String(localized: "\"Want to travel together?\" A chance offer to join up. How do you feel?"), options: [
            QuizOption(text: String(localized: "It feels like a burden"), signature: [.socialMode: -0.6]),
            QuizOption(text: String(localized: "I'm glad to hear it"), signature: [.socialMode: 0.6])
        ]),
        QuizQuestion(id: "Q8", prompt: String(localized: "The night before departure, you?"), options: [
            QuizOption(text: String(localized: "Book a place to stay and figure out the rest there"), signature: [.planningStyle: -0.7]),
            QuizOption(text: String(localized: "Finish an hour-by-hour itinerary"), signature: [.planningStyle: 0.7])
        ]),
        QuizQuestion(id: "Q9", prompt: String(localized: "How do you find places to eat?"), options: [
            QuizOption(text: String(localized: "Walk in wherever catches my eye"), signature: [.planningStyle: -0.6]),
            QuizOption(text: String(localized: "Make a list ahead and even book"), signature: [.planningStyle: 0.6])
        ]),
        QuizQuestion(id: "Q10", prompt: String(localized: "First morning at your destination: where do your feet take you?"), options: [
            QuizOption(text: String(localized: "Famous landmarks everyone visits first"), signature: [.noveltyAppetite: -0.7]),
            QuizOption(text: String(localized: "Unfamiliar local alleys not on the map"), signature: [.noveltyAppetite: 0.7])
        ]),
        QuizQuestion(id: "Q11", prompt: String(localized: "Faced with unfamiliar local food, you?"), options: [
            QuizOption(text: String(localized: "Look for something familiar"), signature: [.noveltyAppetite: -0.6]),
            QuizOption(text: String(localized: "Try it first"), signature: [.noveltyAppetite: 0.6])
        ]),
        QuizQuestion(id: "Q12", prompt: String(localized: "Which shots do you hope fill your travel album more?"), options: [
            QuizOption(text: String(localized: "Mountains, sea, sky"), signature: [.natureUrban: -0.6]),
            QuizOption(text: String(localized: "Streets, buildings, people"), signature: [.natureUrban: 0.6])
        ])
    ]

    static let quadrantQuestion = QuizQuestion(id: "Q13", prompt: String(localized: "If you could teleport right now?"), options: [
        QuizOption(text: String(localized: "A lakeside cabin"), signature: [.natureUrban: -0.5, .energyLevel: -0.5]),
        QuizOption(text: String(localized: "Rafting and trekking in the wild"), signature: [.natureUrban: -0.5, .energyLevel: 0.5]),
        QuizOption(text: String(localized: "A small town with alley cafés"), signature: [.natureUrban: 0.5, .energyLevel: -0.5]),
        QuizOption(text: String(localized: "A big city with night markets"), signature: [.natureUrban: 0.5, .energyLevel: 0.5])
    ])

    static let escapeText = String(localized: "I'm not sure")

    static var allQuestions: [QuizQuestion] {
        abQuestions + [quadrantQuestion]
    }

    /// 여행 기록만으로 흐린 축마다 단일 축 문항을 하나씩 고른다. 카탈로그 순서를 유지한다.
    static func miniQuizQuestions(for axes: Set<TasteAxis>) -> [QuizQuestion] {
        var remaining = axes
        return abQuestions.filter { question in
            guard let axis = question.options.first?.signature.keys.first,
                  remaining.contains(axis) else { return false }
            remaining.remove(axis)
            return true
        }
    }
}
