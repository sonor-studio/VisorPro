import SwiftUI

struct SurveyTestSettingsView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @ObservedObject var surveyLibrary = SurveyLibrary.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Survey Testing")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Below you can trigger the selected survey as an overlay to see how it looks in practice.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Divider()
                
                if surveyLibrary.isFetching {
                    Text("Fetching surveys from database...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else if let error = surveyLibrary.errorMessage {
                    Text("⚠️ Błąd pobierania: \(error)")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.top, 20)
                        
                    Button("Spróbuj ponownie") {
                        Task {
                            await surveyLibrary.fetchSurveys()
                        }
                    }
                    .padding(.top, 8)
                } else if surveyLibrary.questions.isEmpty {
                    Text("Brak ankiet w bazie danych. Upewnij się, że tabela w Supabase nie jest pusta i ma poprawne nazwy kolumn.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else {
                    ForEach(surveyLibrary.questions) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                mediaKeyManager.showSurvey(questionId: question.id)
                            }) {
                                Text("Show Overlay")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandCursor()
                            
                            Text("ID: \(question.id)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(12)
                }
                }
                
                Spacer()
            }
            .padding(30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
