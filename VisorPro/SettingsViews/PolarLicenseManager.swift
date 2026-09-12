import Foundation
import SwiftUI
import Combine

class PolarLicenseManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // UWAGA: Musisz podmienić to na swoje Organization ID!
    private let organizationId = "f7948fb8-7aba-48ea-802d-cba2602e7d50"
    
    func activateKey(key: String) async -> String? {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/activate") else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Invalid URL"
            }
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2026-04", forHTTPHeaderField: "Polar-Version")
        
        let body: [String: String] = [
            "key": key,
            "organization_id": organizationId,
            "label": Host.current().localizedName ?? "Mac"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            DispatchQueue.main.async { self.isLoading = false }
            
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let activationId = json["id"] as? String {
                    return activationId
                }
                return "activated_without_id" // Fallback if parsing fails
            } else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("POLAR API ERROR: \(errorJson)")
                    let errorDetail = errorJson["detail"] as? String ?? ""
                    DispatchQueue.main.async {
                        if errorDetail.contains("limit") || errorDetail.contains("Activation limit") {
                            self.errorMessage = "Activation limit reached. Please deactivate another device first."
                        } else if httpResponse.statusCode == 404 {
                            self.errorMessage = "The license key does not exist."
                        } else {
                            self.errorMessage = "Invalid key (\(errorDetail))"
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Invalid key (Code: \(httpResponse.statusCode))"
                    }
                }
                return nil
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Network connection error."
            }
            return nil
        }
    }
    
    func deactivateKey(key: String, activationId: String) async -> Bool {
        guard let url = URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/deactivate") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2026-04", forHTTPHeaderField: "Polar-Version")
        
        let body: [String: String] = [
            "key": key,
            "organization_id": organizationId,
            "activation_id": activationId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 204
        } catch {
            return false
        }
    }
    
    func validateKey(key: String) async -> Bool {
        return await activateKey(key: key) != nil
    }
}
