import Foundation
import SwiftUI
import Combine

struct SupabaseSurvey: Codable {
    let id: String
    let title: String
    let option_1: String?
    let option_2: String?
    let option_3: String?
    let option_4: String?
}

struct SurveyQuestion: Identifiable {
    let id: String
    let title: String
    let options: [String]
    
    var height: CGFloat {
        // 12 (top padding) + 12 (spacing between title and buttons) + 12 (bottom padding)
        let basePadding: CGFloat = 36
        
        // Estimate title height (font size 13, bold). ~32 chars fit in one line in 228px width.
        let titleLines = ceil(CGFloat(title.count) / 32.0)
        let titleHeight = titleLines * 16.0
        
        // Estimate options height
        var optionsHeight: CGFloat = 0
        for option in options {
            // Estimate option text lines (font size 12). ~38 chars fit in one line.
            let optionLines = ceil(CGFloat(option.count) / 38.0)
            let optionTextHeight = optionLines * 15.0
            let optionButtonPadding: CGFloat = 12.0 // .padding(.vertical, 6) * 2
            
            // Add spacing between buttons (6.0), the extra 6 for the last element acts as a safe buffer
            optionsHeight += (optionTextHeight + optionButtonPadding + 6.0) 
        }
        
        return basePadding + titleHeight + optionsHeight
    }
}

@MainActor
class SurveyLibrary: ObservableObject {
    static let shared = SurveyLibrary()
    
    @Published var questions: [SurveyQuestion] = []
    @Published var isFetching: Bool = true
    @Published var errorMessage: String? = nil
    
    private init() {}
    
    func fetchSurveys() async {
        self.isFetching = true
        self.errorMessage = nil
        
        let supabaseUrl = EnvReader.shared.getValue(for: "SUPABASE_URL") ?? ""
        let supabaseAnonKey = EnvReader.shared.getValue(for: "SUPABASE_ANON_KEY") ?? ""
        
        guard !supabaseUrl.isEmpty, !supabaseAnonKey.isEmpty else {
            self.errorMessage = "Missing Supabase configuration in .env"
            self.isFetching = false
            return
        }
        
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/surveys?select=*&is_active=eq.true") else {
            self.errorMessage = "Invalid Supabase URL"
            self.isFetching = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                do {
                    let fetchedSurveys = try decoder.decode([SupabaseSurvey].self, from: data)
                    
                    if fetchedSurveys.isEmpty {
                        self.errorMessage = "Table is empty or RLS is blocking access."
                    }
                    
                    var newQuestions: [SurveyQuestion] = []
                    for s in fetchedSurveys {
                        var options: [String] = []
                        if let o1 = s.option_1, !o1.isEmpty { options.append(o1) }
                        if let o2 = s.option_2, !o2.isEmpty { options.append(o2) }
                        if let o3 = s.option_3, !o3.isEmpty { options.append(o3) }
                        if let o4 = s.option_4, !o4.isEmpty { options.append(o4) }
                        
                        if !options.isEmpty {
                            newQuestions.append(SurveyQuestion(id: s.id, title: s.title, options: options))
                        }
                    }
                    
                    self.questions = newQuestions
                } catch {
                    self.errorMessage = "JSON Decode Error: \(error.localizedDescription)"
                }
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self.errorMessage = "HTTP Error: \(statusCode)"
            }
        } catch {
            self.errorMessage = "Network request failed: \(error.localizedDescription)"
        }
        self.isFetching = false
    }
}
