import Foundation
import SwiftUI
import Combine

class PolarLicenseManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // UWAGA: Musisz podmienić to na swoje Organization ID!
    // Znajdziesz je w panelu Polar -> Settings -> General -> Organization ID
    private let organizationId = "f7948fb8-7aba-48ea-802d-cba2602e7d50"
    
    func validateKey(key: String) async -> Bool {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/validate") else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Błąd URL"
            }
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "key": key,
            "organization_id": organizationId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            
            if httpResponse.statusCode == 200 {
                return true
            } else {
                // Odczytujemy dokładny błąd z serwera, żeby wiedzieć co jest nie tak!
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("POLAR API ERROR: \(errorJson)")
                } else if let errorString = String(data: data, encoding: .utf8) {
                    print("POLAR API RAW ERROR: \(errorString)")
                }
                
                DispatchQueue.main.async {
                    if httpResponse.statusCode == 422 {
                        self.errorMessage = "Błąd API: Upewnij się, że wkleiłeś poprawne Organization ID w kodzie!"
                    } else if httpResponse.statusCode == 404 {
                        self.errorMessage = "Klucz nie istnieje w bazie."
                    } else {
                        self.errorMessage = "Nieprawidłowy klucz (Kod: \(httpResponse.statusCode))"
                    }
                }
                return false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Błąd połączenia z siecią."
            }
            return false
        }
    }
}
