import SwiftUI

struct FeedbackSettingsView: View {
    @State private var feedbackType: String = "Bug"
    @State private var otherTypeDetails: String = ""
    @State private var emailAddress: String = ""
    @State private var description: String = ""
    
    let feedbackTypes = ["Bug", "Idea", "Other"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with graphic
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 64, height: 64)
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Submit Feedback")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("We'd love to hear your thoughts! Let us know how we can improve VisorPro.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
                
                // Form Sections
                VStack(alignment: .leading, spacing: 12) {
                    
                    Text("Details")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        
                    
                    VStack(spacing: 0) {
                        CustomSettingsRow(icon: "tag.fill", iconColor: .orange, title: "Category", subtitle: "What kind of feedback is this?") {
                            Picker("", selection: $feedbackType) {
                                ForEach(feedbackTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                            .frame(width: 120)
                        }
                        
                        if feedbackType == "Other" {
                            Divider().padding(.leading, 48)
                            CustomSettingsRow(icon: "ellipsis.bubble.fill", iconColor: .gray, title: "Specify", subtitle: "Provide more details") {
                                TextField("Optional", text: $otherTypeDetails)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: 150)
                            }
                        }
                        
                        Divider().padding(.leading, 48)
                        
                        CustomSettingsRow(icon: "at", iconColor: .blue, title: "Email Address", subtitle: "Optional, if you want a reply") {
                            TextField("email@example.com", text: $emailAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 200)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    Text("Message")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                        
                    
                    VStack(alignment: .leading, spacing: 0) {
                        TextEditor(text: $description)
                            .font(.body)
                            .frame(minHeight: 120, maxHeight: 250)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(8)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                    
                    // Submit Button
                    HStack {
                        Spacer()
                        Button(action: {
                            submitFeedback()
                        }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send Feedback")
                            }
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .tint(.blue)
                        .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (feedbackType == "Other" && otherTypeDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
            }
            .padding(40)
            .frame(maxWidth: 700)
        }
        .navigationTitle("Feedback")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    private func submitFeedback() {
        description = ""
        otherTypeDetails = ""
        emailAddress = ""
        feedbackType = "Bug"
    }
}
