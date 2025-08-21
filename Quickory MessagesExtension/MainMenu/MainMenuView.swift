//
//  MainMenuView.swift
//  MessagesExtension
//



import SwiftUI   //the modern declarative UI framework from Apple
import Messages  //framework specifically for building iMessage extensions

//MARK: - Main Game Menu View
struct MainMenuView: View {
    
    // MARK: - State
    //User Data
    @State var showSettings = false
    @State var playerName = "Player"
    @State var rounds = 5
    @State var categories = 10
    @State var selectedAvatar = "🎯"
    
    // MARK: - Config
    //Configuration For The Setting Menu
    private let avatarOptions = ["🎯", "🌟", "🎪", "🎨", "🎵", "🎲", "🎭", "🎊"]
    private let roundOptions = [3, 5, 7, 10]
    private let categoryOptions = [5, 8, 10, 12]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                ScrollView {
                    VStack(spacing: isCompactHeight(geometry) ? 16 : 20) {
                        headerView
                        playerInfoCardWithSettings
                        actionButtonsView
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                playerName: $playerName,
                rounds: $rounds,
                categories: $categories,
                selectedAvatar: $selectedAvatar,
                avatarOptions: avatarOptions,
                roundOptions: roundOptions,
                categoryOptions: categoryOptions
            )
        }
    }
    
    // MARK: - Components
    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemGray6), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.blue.opacity(0.05))
                        .frame(width: 120, height: 120)
                        .blur(radius: 40)
                        .offset(x: 60, y: -60)
                }
                Spacer()
                HStack {
                    Circle()
                        .fill(Color.pink.opacity(0.08))
                        .frame(width: 100, height: 100)
                        .blur(radius: 30)
                        .offset(x: -40, y: 40)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: Header
    private var headerView: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Text("Quick")
                        .font(.system(size: 24, weight: .light))
                    Text("ORY")
                        .font(.system(size: 24, weight: .medium))
                }
                .foregroundColor(.primary)
                
                Text("Think fast, answer faster!")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: PlayerInfo
    private var playerInfoCardWithSettings: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .overlay(Text(selectedAvatar).font(.system(size: 20)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playerName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(rounds) rounds • \(categories) categories")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(.systemGray6)))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        )
    }
    
    // MARK: - Actions
    var actionButtonsView: some View {
        VStack(spacing: 12) {
            // Solo play button for testing
            Button(action: startSoloGame) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill").font(.system(size: 14))
                    Text("🧪 Solo Test Mode").font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Regular multiplayer button
            Button(action: startNewGameAndSend) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 14))
                    Text("Start Multiplayer Game").font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Text("Solo mode for testing • Multiplayer sends invitations")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Game Actions
    func startSoloGame() {
        print("🧪 Starting SOLO test game (no messaging):")
        print("  Player: \(playerName)")
        print("  Rounds: \(rounds)")
        print("  Categories: \(categories)")
        print("  Avatar: \(selectedAvatar)")

        let gameEngine = GameEngine()
        gameEngine.createNewGame(
            hostName: playerName,
            hostAvatar: selectedAvatar,
            rounds: rounds,
            categories: categories
        )
        
        print("🧪 Solo game engine state: \(gameEngine.gameState != nil)")
        print("🧪 Is host: \(gameEngine.isHost)")

        if let gameState = gameEngine.gameState {
            print("🧪 Solo game created with \(gameState.players.count) players")
            print("🧪 Can start: \(gameState.canStart)")
            
            // Navigate directly to gameplay (no messaging)
            if let data = try? JSONEncoder().encode(gameState) {
                let base64 = data.base64EncodedString()
                NotificationCenter.default.post(
                    name: NSNotification.Name("StartGameplay"),
                    object: nil,
                    userInfo: ["gameState": base64]
                )
                print("🧪 Sent startGameplay notification for solo mode")
            }
        } else {
            print("❌ Failed to create solo game state")
        }
    }
    
    func startNewGameAndSend() {
        print("🎮 Starting new game with engine integration:")
        print("  Player: \(playerName)")
        print("  Rounds: \(rounds)")
        print("  Categories: \(categories)")
        print("  Avatar: \(selectedAvatar)")

        let gameEngine = GameEngine()
        gameEngine.createNewGame(
            hostName: playerName,
            hostAvatar: selectedAvatar,
            rounds: rounds,
            categories: categories
        )
        
        print("🎮 Game engine state after creation: \(gameEngine.gameState != nil)")
        print("🎮 Is host: \(gameEngine.isHost)")

        if let gameState = gameEngine.gameState {
            print("🎮 Game state created with \(gameState.players.count) players")
            print("🎮 Can start: \(gameState.canStart)")
            
            // Send the invite into the conversation
            sendGameToMessages(gameState: gameState)

            // Navigate the HOST into gameplay locally
            if let data = try? JSONEncoder().encode(gameState) {
                let base64 = data.base64EncodedString()
                NotificationCenter.default.post(
                    name: NSNotification.Name("StartGameplay"),
                    object: nil,
                    userInfo: ["gameState": base64]
                )
                print("🎮 Sent startGameplay notification")
            }
        } else {
            print("❌ Failed to create game state")
        }
    }
    
    func sendGameToMessages(gameState: GameState) {
        print("📤 Preparing to send game invitation with full state...")
        
        // Encode the game state for transmission
        guard let gameStateData = try? JSONEncoder().encode(gameState) else {
            print("❌ Failed to encode game state")
            return
        }
        
        // Convert to Base64 string (URL-safe)
        let base64String = gameStateData.base64EncodedString()
        
        // Create comprehensive game data to send
        let gameData: [String: Any] = [
            "action": "newGameInvitation",
            "gameState": base64String,
            "gameId": gameState.gameId,
            "hostName": gameState.hostPlayer.name,
            "hostAvatar": gameState.hostPlayer.avatar,
            "rounds": gameState.totalRounds,
            "categories": gameState.categoriesPerRound,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Send via notification to MessagesViewController
        NotificationCenter.default.post(
            name: NSNotification.Name("SendGameInvitation"),
            object: nil,
            userInfo: gameData
        )
        
        print("📨 Game invitation sent with full game state")
        print("📊 Game ID: \(gameState.gameId)")
    }

    // MARK: Helpers
    //returns true when geometry.size.height < 400 to tighten vertical spacing in cramped layouts.
    private func isCompactHeight(_ geometry: GeometryProxy) -> Bool {
        geometry.size.height < 400
    }
}

