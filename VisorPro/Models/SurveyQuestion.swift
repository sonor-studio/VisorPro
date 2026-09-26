import Foundation

struct SurveyQuestion: Identifiable {
    let id: String
    let title: String
    let options: [String]
    
    // The options mapped to an answer string for TelemetryDeck
    let optionValues: [String]
}

class SurveyLibrary {
    static let questions: [SurveyQuestion] = [
        SurveyQuestion(
            id: "survey_smoothness",
            title: "Jak oceniasz płynność animacji i nakładek?",
            options: ["🧈 Gładko jak po maśle", "👍 Jest okej, ale może być lepiej", "🐢 Czasami klatkuje / laguje"],
            optionValues: ["great", "okay", "laggy"]
        ),
        SurveyQuestion(
            id: "survey_feature",
            title: "Gdybyś mógł dodać jedną rzecz do VisorPro, co by to było?",
            options: ["🎨 Więcej opcji wyglądu", "⚡ Lepsza wydajność", "🛠 Więcej ustawień", "❤️ Nic, jest super!"],
            optionValues: ["more_customization", "better_performance", "more_settings", "nothing_needed"]
        ),
        SurveyQuestion(
            id: "survey_habit",
            title: "Czy używanie VisorPro weszło Ci już w krew?",
            options: ["💯 Tak, nie wyobrażam sobie pracy bez tego", "🤷‍♂️ Używam, ale rzadko", "👻 Zapominam, że to mam"],
            optionValues: ["essential", "occasional", "forgetful"]
        ),
        SurveyQuestion(
            id: "survey_design",
            title: "Jak bardzo podoba Ci się wygląd nakładek?",
            options: ["😍 Wyglądają świetnie!", "😐 Są okej", "👎 Zdecydowanie do poprawy"],
            optionValues: ["great", "okay", "bad"]
        )
    ]
}
