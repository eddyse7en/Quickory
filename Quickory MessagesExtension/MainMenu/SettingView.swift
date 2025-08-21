import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Binding var playerName: String
    @Binding var rounds: Int
    @Binding var categories: Int
    @Binding var selectedAvatar: String
    
    let avatarOptions: [String]
    let roundOptions: [Int]
    let categoryOptions: [Int]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                playerNameSection
                gameConfigurationSection
                avatarSelectionSection
                Spacer()
            }
            .padding(20)
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            playerName = "Player"
                        }
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var playerNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Player Name")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            TextField("Enter your name", text: $playerName)
                .textFieldStyle(.roundedBorder)
                .frame(height: 36)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
    
    private var gameConfigurationSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rounds").font(.system(size: 14, weight: .medium))
                HStack(spacing: 4) {
                    ForEach(roundOptions, id: \.self) { option in
                        Button(action: { rounds = option }) {
                            Text("\(option)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(rounds == option ? .blue : .primary)
                                .frame(width: 30, height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(rounds == option ? Color.blue.opacity(0.1) : Color(.systemBackground))
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Categories").font(.system(size: 14, weight: .medium))
                HStack(spacing: 4) {
                    ForEach(categoryOptions, id: \.self) { option in
                        Button(action: { categories = option }) {
                            Text("\(option)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(categories == option ? .green : .primary)
                                .frame(width: 30, height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(categories == option ? Color.green.opacity(0.1) : Color(.systemBackground))
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }
    
    private var avatarSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose Avatar").font(.system(size: 14, weight: .medium))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(avatarOptions, id: \.self) { avatar in
                    Button(action: { selectedAvatar = avatar }) {
                        Text(avatar)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAvatar == avatar ? Color.pink.opacity(0.1) : Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedAvatar == avatar ? Color.pink.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

// MARK: - Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


