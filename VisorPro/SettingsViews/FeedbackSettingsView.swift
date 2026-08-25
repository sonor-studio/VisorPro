import SwiftUI

struct FeedbackSettingsView: View {
    @State private var feedbackType: String = "Idea"
    @State private var otherTypeDetails: String = ""
    @State private var emailAddress: String = ""
    @State private var description: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var errorMessage: String = ""
    
    let feedbackTypes = ["Idea", "Bug Report", "Question", "Other"]
    
    private var isEmailValid: Bool {
        let trimmed = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: trimmed)
    }
    
    private var isCategoryValid: Bool {
        if feedbackType == "Other" {
            return !otherTypeDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
    
    private var isValidToSubmit: Bool {
        let isTextValid = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isTextValid && isEmailValid && isCategoryValid && !isSubmitting
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                            .frame(width: 56, height: 56)
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Submit Feedback")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("We'd love to hear your thoughts! Let us know how we can improve VisorPro.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                // Form Sections
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "tag.fill", iconColor: .orange, title: "Category", subtitle: "What kind of feedback is this?") {
                            Picker("", selection: $feedbackType) {
                                ForEach(feedbackTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 140)
                        }
                        
                        if feedbackType == "Other" {
                            Divider().padding(.leading, 40)
                            CustomSettingsRow(icon: "ellipsis.bubble.fill", iconColor: .gray, title: "Specify", subtitle: "Provide more details") {
                                VStack(alignment: .trailing, spacing: 2) {
                                    TextField("Custom category...", text: $otherTypeDetails)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 200)
                                    
                                    if !isCategoryValid {
                                        Text("This field is required")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        
                        Divider().padding(.leading, 40)
                        
                        CustomSettingsRow(icon: "at", iconColor: .blue, title: "Email Address", subtitle: "Optional, if you want a reply") {
                            VStack(alignment: .trailing, spacing: 2) {
                                TextField("email@example.com", text: $emailAddress)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 200)
                                if !isEmailValid && !emailAddress.isEmpty {
                                    Text("Invalid email")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Message")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $description)
                            .font(.body)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(8)
                            
                        if description.isEmpty {
                            Text("Write your feedback here...")
                                .font(.body)
                                .foregroundColor(Color.secondary.opacity(0.5))
                                .padding(.leading, 12)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Submit Button
                VStack(spacing: 12) {
                    Button(action: {
                        submitFeedback()
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Feedback")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .tint(.blue)
                    .disabled(!isValidToSubmit)
                    
                    // Status Message below button
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                            Text("Sending...")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13, weight: .medium))
                        } else if showSuccessMessage {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Feedback sent successfully!")
                                .foregroundColor(.green)
                                .font(.system(size: 13, weight: .medium))
                        } else if !errorMessage.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .frame(height: 20)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .navigationTitle("Feedback")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onChange(of: feedbackType) { _ in resetMessages() }
        .onChange(of: otherTypeDetails) { _ in resetMessages() }
        .onChange(of: emailAddress) { _ in resetMessages() }
        .onChange(of: description) { _ in resetMessages() }
    }
    
    private func resetMessages() {
        showSuccessMessage = false
        errorMessage = ""
    }
    
    private func submitFeedback() {
        guard let urlStr = EnvReader.shared.getValue(for: "SUPABASE_URL"),
              let anonKey = EnvReader.shared.getValue(for: "SUPABASE_ANON_KEY"),
              let url = URL(string: "\(urlStr)/rest/v1/feedback") else {
            errorMessage = "Database configuration is missing."
            return
        }
        
        isSubmitting = true
        errorMessage = ""
        showSuccessMessage = false
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        let finalType = feedbackType == "Other" ? (otherTypeDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Other" : otherTypeDetails) : feedbackType
        
        let payload: [String: Any] = [
            "type": finalType,
            "description": description,
            "email": emailAddress
        ]
        
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            isSubmitting = false
            errorMessage = "Failed to encode data."
            return
        }
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isSubmitting = false
                if let error = error {
                    print("Feedback Error: \(error)")
                    errorMessage = "An error occurred. Please try again."
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    // Success
                    showSuccessMessage = true
                    description = ""
                    otherTypeDetails = ""
                    emailAddress = ""
                    feedbackType = "Idea"
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation {
                            showSuccessMessage = false
                        }
                    }
                } else {
                    errorMessage = "Server returned an error. Please try again."
                }
            }
        }.resume()
    }
}
