import SwiftUI

struct FeedbackSettingsView: View {
    @State private var feedbackType: String = "Bug"
    @State private var otherTypeDetails: String = ""
    @State private var emailAddress: String = ""
    @State private var description: String = ""
    
    let feedbackTypes = ["Bug", "Idea", "Other"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Submit Feedback")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("We'd love to hear your thoughts! Let us know how we can improve VisorPro.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 24)
                
                // Form Container
                VStack(spacing: 20) {
                    // Type Selection
                    HStack(alignment: .top) {
                        Text("Category:")
                            .frame(width: 100, alignment: .trailing)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("", selection: $feedbackType) {
                                ForEach(feedbackTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .labelsHidden()
                            .frame(width: 200)
                            
                            if feedbackType == "Other" {
                                TextField("Please specify...", text: $otherTypeDetails)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: 300)
                            }
                        }
                        Spacer()
                    }
                    
                    Divider()
                        .padding(.leading, 116)
                    
                    // Email
                    HStack(alignment: .center) {
                        Text("Email:")
                            .frame(width: 100, alignment: .trailing)
                            .foregroundColor(.secondary)
                        
                        TextField("Optional for replies", text: $emailAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 300)
                        
                        Spacer()
                    }
                    
                    Divider()
                        .padding(.leading, 116)
                    
                    // Description
                    HStack(alignment: .top) {
                        Text("Description:")
                            .frame(width: 100, alignment: .trailing)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $description)
                            .font(.body)
                            .frame(minHeight: 120, maxHeight: 250)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Submit Button
                    HStack {
                        Spacer()
                        Button(action: {
                            submitFeedback()
                        }) {
                            Text("Send Feedback")
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (feedbackType == "Other" && otherTypeDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    }
                    .padding(.top, 4)
                }
                .padding(24)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding(40)
            .frame(maxWidth: 700)
        }
    }
    
    private func submitFeedback() {
        print("Feedback submitted: \(feedbackType) - \(otherTypeDetails) - \(description)")
        description = ""
        otherTypeDetails = ""
        emailAddress = ""
        feedbackType = "Bug"
    }
}
