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
        QuizQuestion(id: "Q1", prompt: "한 달 살기를 한다면?", options: [
            QuizOption(text: "인프라가 잘 갖춰진 편리한 도심", signature: [.natureUrban: 0.7]),
            QuizOption(text: "창문을 열면 숲과 바다가 있는 자연", signature: [.natureUrban: -0.7])
        ]),
        QuizQuestion(id: "Q2", prompt: "숙소 창밖으로 보고 싶은 풍경은?", options: [
            QuizOption(text: "대자연", signature: [.natureUrban: -0.7]),
            QuizOption(text: "도시 스카이라인", signature: [.natureUrban: 0.7])
        ]),
        QuizQuestion(id: "Q3", prompt: "여행 중 완벽한 오후는?", options: [
            QuizOption(text: "조용히 쉬어가기", signature: [.energyLevel: -0.7]),
            QuizOption(text: "꽉 채워 즐기기", signature: [.energyLevel: 0.7])
        ]),
        QuizQuestion(id: "Q4", prompt: "여행 다녀온 뒤 듣고 싶은 말은?", options: [
            QuizOption(text: "\"푹 쉬다 왔구나\"", signature: [.energyLevel: -0.6]),
            QuizOption(text: "\"진짜 알차게 놀았구나\"", signature: [.energyLevel: 0.6])
        ]),
        QuizQuestion(id: "Q5", prompt: "아름다운 야경 앞에서 드는 생각은?", options: [
            QuizOption(text: "혼자 이 분위기를 온전히 즐겨야지", signature: [.socialMode: -0.7]),
            QuizOption(text: "아, 누군가와 같이 봤어야 하는데!", signature: [.socialMode: 0.7])
        ]),
        QuizQuestion(id: "Q6", prompt: "여행지에서의 저녁은?", options: [
            QuizOption(text: "혼자 조용히 현지 맛집", signature: [.socialMode: -0.7]),
            QuizOption(text: "새로 만난 사람들과 왁자지껄", signature: [.socialMode: 0.7])
        ]),
        QuizQuestion(id: "Q7", prompt: "\"같이 다닐래요?\" 우연한 동행 제안, 내 마음은?", options: [
            QuizOption(text: "부담스럽다", signature: [.socialMode: -0.6]),
            QuizOption(text: "반갑다", signature: [.socialMode: 0.6])
        ]),
        QuizQuestion(id: "Q8", prompt: "출발 전날 밤, 나는?", options: [
            QuizOption(text: "숙소만 잡고 나머지는 현지에서", signature: [.planningStyle: -0.7]),
            QuizOption(text: "시간 단위 일정표 완성", signature: [.planningStyle: 0.7])
        ]),
        QuizQuestion(id: "Q9", prompt: "맛집은 어떻게 찾나요?", options: [
            QuizOption(text: "걷다가 끌리는 곳에 들어감", signature: [.planningStyle: -0.6]),
            QuizOption(text: "미리 리스트 만들고 예약까지", signature: [.planningStyle: 0.6])
        ]),
        QuizQuestion(id: "Q10", prompt: "여행지에서 맞이한 첫 아침, 내 발걸음은?", options: [
            QuizOption(text: "남들이 다 가는 유명 랜드마크부터", signature: [.noveltyAppetite: -0.7]),
            QuizOption(text: "지도에 없는 낯선 로컬 골목으로", signature: [.noveltyAppetite: 0.7])
        ]),
        QuizQuestion(id: "Q11", prompt: "낯선 현지 음식 앞에서 나는?", options: [
            QuizOption(text: "익숙한 메뉴를 찾는다", signature: [.noveltyAppetite: -0.6]),
            QuizOption(text: "일단 도전해본다", signature: [.noveltyAppetite: 0.6])
        ]),
        QuizQuestion(id: "Q12", prompt: "여행 사진첩에 더 많길 바라는 장면은?", options: [
            QuizOption(text: "산·바다·하늘", signature: [.natureUrban: -0.6]),
            QuizOption(text: "거리·건물·사람", signature: [.natureUrban: 0.6])
        ])
    ]

    static let quadrantQuestion = QuizQuestion(id: "Q13", prompt: "지금 당장 순간이동한다면?", options: [
        QuizOption(text: "호숫가 오두막", signature: [.natureUrban: -0.5, .energyLevel: -0.5]),
        QuizOption(text: "래프팅·트레킹 대자연", signature: [.natureUrban: -0.5, .energyLevel: 0.5]),
        QuizOption(text: "골목 카페 소도시", signature: [.natureUrban: 0.5, .energyLevel: -0.5]),
        QuizOption(text: "야시장 대도시", signature: [.natureUrban: 0.5, .energyLevel: 0.5])
    ])

    static let escapeText = "모르겠어요"

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
