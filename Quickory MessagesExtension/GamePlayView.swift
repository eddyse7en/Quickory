//
//  GamePlayView.swift
//  MessagesExtension
//
//  Quickory SwiftUI Views: Complete gameplay interface for multiplayer word game
//
//  This file contains:
//  • Main game container that manages different game states
//  • Lobby view for pre-game player waiting
//  • Active gameplay interface with category inputs
//  • Results views for round completion and final scores
//  • Custom button and text field styles
//  • Real-time state synchronization across devices
//

import SwiftUI

// MARK: - Main Game Container

/// Root game view that orchestrates the entire gameplay experience
/// Manages state transitions: lobby → active game → results → final scores
/// Handles real-time updates from other players via notifications
struct GamePlayView: View {
    // MARK: - State Properties
    
    /// Core game logic and state management engine
    @StateObject private var gameEngine = GameEngine()
    
    /// Player's answers for the current round (category -> answer)
    @State private var currentAnswers: [String: String] = [:]
    
    /// Controls visibility of results screens
    @State private var showResults = false
    
    /// Game state passed when joining an existing game (nil for new games)
    let initialGameState: GameState?
    
    /// Track the current round to detect changes
    @State private var lastSeenRound: Int = 0
    
    /// Initialize game view
    /// - Parameter gameState: Existing game state if joining mid-game
    init(gameState: GameState? = nil) {
        self.initialGameState = gameState
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            // Render appropriate view based on current game status
            if let gameState = gameEngine.gameState {
                switch gameState.gameStatus {
                case .waitingForPlayers, .ready:
                    // Pre-game lobby where players join and host can start
                    GameLobbyView(gameEngine: gameEngine, gameState: gameState)
                    
                case .roundInProgress:
                    // Active gameplay with timer, letter, and category inputs
                    ActiveGameView(
                        gameEngine: gameEngine,
                        gameState: gameState,
                        currentAnswers: $currentAnswers
                    )
                    
                case .waitingForSubmissions:
                    // Waiting screen after player has submitted but others haven't
                    WaitingForSubmissionsView(gameEngine: gameEngine, gameState: gameState)
                    
                case .roundEnded:
                    // Brief results screen between rounds
                    RoundResultsView(gameEngine: gameEngine, gameState: gameState)
                    
                case .gameCompleted:
                    // Final leaderboard and winner celebration
                    FinalResultsView(gameEngine: gameEngine, gameState: gameState)
                }
            } else {
                // Loading state while game engine initializes
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading game...")
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
            }
        }
        .onAppear {
            // Handle joining existing game vs creating new game
            if let gameState = initialGameState {
                print("🎮 GamePlayView: Joining existing game with \(gameState.players.count) players")
                print("🎮 GamePlayView: Game status: \(gameState.gameStatus)")
                print("🎮 GamePlayView: Can start: \(gameState.canStart)")
                print("🎮 GamePlayView: Host player: \(gameState.hostPlayer.name)")
                
                // Configure local player 
                // Note: For proper multiplayer, this should be set when the player joins
                // For now, assume host for solo testing
                gameEngine.currentPlayer = gameState.hostPlayer
                gameEngine.isHost = true
                gameEngine.receiveGameUpdate(gameState)
                
                // Initialize round tracking
                lastSeenRound = gameState.currentRound
                
                print("🎮 GamePlayView: Setup complete - isHost: \(gameEngine.isHost)")
            } else {
                print("🎮 GamePlayView: Starting fresh (no existing game state)")
            }
        }
        .onChange(of: gameEngine.gameState?.currentRound) { oldRound, newRound in
            // Clear answers when round changes directly (handles solo mode)
            if let newRound = newRound, newRound != lastSeenRound && newRound > lastSeenRound {
                currentAnswers.removeAll()
                lastSeenRound = newRound
                print("🧹 Direct round change detected: Cleared currentAnswers for round \(newRound)")
            }
        }
        .onChange(of: gameEngine.gameState?.gameStatus) { oldStatus, newStatus in
            // Additional check when status changes to roundInProgress
            if newStatus == .roundInProgress,
               let currentRound = gameEngine.gameState?.currentRound,
               currentRound > lastSeenRound {
                currentAnswers.removeAll()
                lastSeenRound = currentRound
                print("🧹 Status change to roundInProgress: Cleared currentAnswers for round \(currentRound)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReceiveGameUpdate"))) { notification in
            // Process real-time game state updates from other players
            // Handles both "gameStateData" and "gameState" keys for compatibility
            if let gameStateData = notification.userInfo?["gameStateData"] as? Data,
               let gameState = gameEngine.decodeGameState(from: gameStateData) {
                let previousRound = gameEngine.gameState?.currentRound
                gameEngine.receiveGameUpdate(gameState)
                
                // Clear currentAnswers when a new round starts
                if let previousRound = previousRound,
                   gameState.currentRound > previousRound && gameState.gameStatus == .roundInProgress {
                    currentAnswers.removeAll()
                    print("🧹 Cleared currentAnswers for new round \(gameState.currentRound)")
                }
                
                print("🔄 Game state updated via gameStateData: \(gameState.players.count) players")
            } else if let gameStateData = notification.userInfo?["gameState"] as? Data,
                      let gameState = gameEngine.decodeGameState(from: gameStateData) {
                let previousRound = gameEngine.gameState?.currentRound
                gameEngine.receiveGameUpdate(gameState)
                
                // Clear currentAnswers when a new round starts
                if let previousRound = previousRound,
                   gameState.currentRound > previousRound && gameState.gameStatus == .roundInProgress {
                    currentAnswers.removeAll()
                    print("🧹 Cleared currentAnswers for new round \(gameState.currentRound)")
                }
                
                print("🔄 Game state updated via gameState: \(gameState.players.count) players")
            }
        }
    }
    
    /// Subtle gradient background that provides visual depth
    /// Uses system colors for proper light/dark mode support
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(.systemGray6), Color.white]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Game Lobby View

/// Pre-game waiting room where players join and host can start the game
/// Displays player list, game settings, and start button for host
/// Shows debug information during development
struct GameLobbyView: View {
    /// Reference to game engine for triggering actions
    @ObservedObject var gameEngine: GameEngine
    
    /// Current game state to display
    let gameState: GameState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Game configuration header with settings overview
                VStack(spacing: 8) {
                    Text("Game Lobby")
                        .font(.system(size: 24, weight: .medium))
                    
                    // Display game settings so players know what they're joining
                    HStack(spacing: 16) {
                        Label("\(gameState.totalRounds) rounds", systemImage: "clock.circle")
                        Label("\(gameState.categoriesPerRound) categories", systemImage: "list.bullet")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Display all players currently in the game
                PlayersListView(players: gameState.players)
                
                // Host controls and status information
                VStack(spacing: 12) {
                    if gameEngine.isHost {
                        // Debug information for development
                        VStack(spacing: 4) {
                            Text("DEBUG: isHost: \(gameEngine.isHost)")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("DEBUG: Players: \(gameState.players.count), Status: \(gameState.gameStatus.rawValue), CanStart: \(gameState.canStart)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        // Host controls - start game when ready
                        if gameState.canStart {
                            VStack(spacing: 8) {
                                Button("Start Game") {
                                    gameEngine.startGame()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                
                                // TEMPORARY: Testing mode indicator
                                if gameState.players.count == 1 {
                                    Text("🧪 TEST MODE: Solo Play")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.orange.opacity(0.1))
                                        )
                                }
                            }
                        } else {
                            Text("Waiting for more players... (min 1 for testing)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    } else {
                        // Debug info for non-host
                        VStack(spacing: 4) {
                            Text("DEBUG: isHost: \(gameEngine.isHost)")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                            Text("DEBUG: currentPlayer: \(gameEngine.currentPlayer?.name ?? "none")")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        
                        // Non-host waiting message
                        Text("Waiting for host to start game...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    // Game identifier for sharing
                    Text("Game ID: \(gameState.gameId.prefix(8))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Active Game View

/// Main gameplay interface during active rounds
/// Features: timer, current letter display, category input fields, submit button
/// Updates in real-time as players submit answers
struct ActiveGameView: View {
    /// Reference to game engine for submitting answers
    @ObservedObject var gameEngine: GameEngine
    
    /// Current game state with round info
    let gameState: GameState
    
    /// Binding to parent's answer storage (category -> answer)
    @Binding var currentAnswers: [String: String]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with round info and countdown timer
            gameHeaderView
            
            // Prominent display of current letter for this round
            letterDisplayView
            
            // Scrollable list of categories with input fields
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(gameState.currentCategories, id: \.self) { category in
                        CategoryAnswerRow(
                            category: category,
                            letter: gameState.currentLetter ?? "A",
                            answer: Binding(
                                get: { currentAnswers[category] ?? "" },
                                set: { currentAnswers[category] = $0 }
                            )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)              // Space for floating submit button
            }
            
            // Fixed submit button at bottom with fade overlay
            submitButtonView
        }
        .onAppear {
            // Initialize empty answer strings for all categories in the round
            for category in gameState.currentCategories {
                if currentAnswers[category] == nil {
                    currentAnswers[category] = ""
                }
            }
        }
        .onChange(of: gameState.currentRound) { oldValue, newValue in
            // Clear answers when round changes (additional safeguard)
            if newValue != oldValue {
                currentAnswers.removeAll()
                print("🧹 ActiveGameView: Cleared answers for round change \(oldValue) -> \(newValue)")
                // Re-initialize for new categories
                for category in gameState.currentCategories {
                    currentAnswers[category] = ""
                }
            }
        }
    }
    
    /// Header section showing round info, timer, and progress bar
    /// Uses color coding for urgency (red when < 30 seconds)
    private var gameHeaderView: some View {
        VStack(spacing: 8) {
            HStack {
                // Current round indicator
                Text("Round \(gameState.currentRound)/\(gameState.totalRounds)")
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                // Countdown timer with urgency color coding
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .foregroundColor(gameEngine.timeRemaining < 30 ? .red : .blue)
                    Text(gameState.getFormattedTimeRemaining(from: gameEngine.timeRemaining))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(gameEngine.timeRemaining < 30 ? .red : .primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 2)
                )
            }
            
            // Visual progress bar showing time remaining
            ProgressView(value: Double(gameEngine.timeRemaining), total: gameState.roundDuration)
                .progressViewStyle(LinearProgressViewStyle(tint: gameEngine.timeRemaining < 30 ? .red : .blue))
        }
        .padding(20)
        .background(Color(.systemGray6))
    }
    
    /// Large circular display of the current round's letter
    /// Visually prominent to remind players what letter answers must start with
    private var letterDisplayView: some View {
        VStack(spacing: 8) {
            Text("Your Letter")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            // Large circular letter display with blue styling
            Text(gameState.currentLetter ?? "A")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                )
        }
        .padding(.vertical, 20)
    }
    
    /// Fixed submit button at bottom with gradient fade overlay
    /// Prevents content from hiding behind button while maintaining accessibility
    private var submitButtonView: some View {
        VStack(spacing: 0) {
            // Gradient fade overlay to visually separate content from button
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color(.systemBackground)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 20)
            
            // Main submit button that sends answers to game engine
            let hasSubmitted = gameEngine.currentPlayer?.id != nil &&
                              gameState.submittedPlayerIds.contains(gameEngine.currentPlayer!.id)
            
            Button(hasSubmitted ? "Already Submitted" : "Submit Answers") {
                if !hasSubmitted {
                    gameEngine.submitAnswers(currentAnswers)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(hasSubmitted)
            .opacity(hasSubmitted ? 0.6 : 1.0)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Category Answer Row

/// Individual category input field with custom styling
/// Displays category name and text field for player's answer
/// Uses game-specific styling for consistent appearance
struct CategoryAnswerRow: View {
    /// Category name to display and answer for
    let category: String
    
    /// Current round's letter (for reference, not enforced)
    let letter: String
    
    /// Binding to player's answer for this category
    @Binding var answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category name
            Text(category)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            // Text input field with custom styling
            TextField("Type your answer...", text: $answer)
                .textFieldStyle(GameTextFieldStyle())
                .autocorrectionDisabled()          // Disable autocorrect for game words
                .textCase(.lowercase)               // Normalize to lowercase
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Waiting For Submissions View

/// View shown to players who have submitted but are waiting for others
/// Displays submission status and which players are still playing
struct WaitingForSubmissionsView: View {
    /// Reference to game engine for state updates
    @ObservedObject var gameEngine: GameEngine
    
    /// Current game state with submission info
    let gameState: GameState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header showing round and submission status
                VStack(spacing: 8) {
                    Text("✅ Answers Submitted!")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("Round \(gameState.currentRound)/\(gameState.totalRounds)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text("Waiting for other players to finish...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Progress indicator showing who has submitted
                VStack(alignment: .leading, spacing: 16) {
                    Text("Submission Progress")
                        .font(.system(size: 18, weight: .medium))
                    
                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(gameState.submittedPlayerIds.count) of \(gameState.players.count) players submitted")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(Double(gameState.submittedPlayerIds.count) / Double(gameState.players.count) * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        
                        ProgressView(value: Double(gameState.submittedPlayerIds.count), total: Double(gameState.players.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    }
                    
                    // List of players with submission status
                    ForEach(gameState.players, id: \.id) { player in
                        HStack(spacing: 12) {
                            // Player avatar
                            Text(player.avatar)
                                .font(.system(size: 20))
                            
                            // Player name
                            Text(player.name)
                                .font(.system(size: 16))
                            
                            Spacer()
                            
                            // Submission status
                            if gameState.submittedPlayerIds.contains(player.id) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Submitted")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Playing...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(gameState.submittedPlayerIds.contains(player.id) ?
                                      Color.green.opacity(0.1) : Color(.systemGray6))
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2)
                )
                
                // Timer showing remaining time for other players
                if gameEngine.timeRemaining > 0 {
                    VStack(spacing: 8) {
                        Text("⏱️ Time Remaining")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(gameState.getFormattedTimeRemaining(from: gameEngine.timeRemaining))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(gameEngine.timeRemaining < 30 ? .red : .blue)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2)
                    )
                }
                
                // Motivational message
                Text("Great job! You've completed this round. Results will be shown once everyone finishes.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(20)
        }
    }
}

// MARK: - Round Results View

/// Transitional view shown between rounds
/// Displays current scores and brief "preparing next round" message
/// Automatically advances to next round (host controls timing)
struct RoundResultsView: View {
    /// Reference to game engine for state updates
    @ObservedObject var gameEngine: GameEngine
    
    /// Current game state with player scores
    let gameState: GameState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Round completion header
                VStack(spacing: 8) {
                    Text("Round \(gameState.currentRound - 1) Complete!")
                        .font(.system(size: 24, weight: .medium))
                    
                    Text("Preparing next round...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Current leaderboard snapshot
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Scores")
                        .font(.system(size: 18, weight: .medium))
                    
                    // Display top players with scores
                    ForEach(gameState.topPlayers, id: \.id) { player in
                        HStack {
                            Text(player.avatar)
                                .font(.system(size: 20))
                            
                            Text(player.name)
                                .font(.system(size: 16))
                            
                            Spacer()
                            
                            Text("\(player.score) pts")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2)
                )
                
                // Loading indicator for next round
                ProgressView()
                    .scaleEffect(1.2)
            }
            .padding(20)
        }
    }
}

// MARK: - Final Results View

/// End-game view displaying final leaderboard and winner celebration
/// Shows all players ranked by final score with special highlighting for winner
/// Includes "Play Again" option for host
struct FinalResultsView: View {
    /// Reference to game engine for potential new game actions
    @ObservedObject var gameEngine: GameEngine
    
    /// Final game state with completed scores
    let gameState: GameState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Game completion celebration header
                VStack(spacing: 8) {
                    Text("🎉")
                        .font(.system(size: 48))
                    
                    Text("Game Complete!")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Final Results")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Final leaderboard with rankings
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(gameState.topPlayers.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 16) {
                            // Rank number with winner highlighting
                            Text("\(index + 1)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(index == 0 ? .yellow : .secondary)
                                .frame(width: 30)
                            
                            // Player avatar
                            Text(player.avatar)
                                .font(.system(size: 24))
                            
                            // Player name and winner status
                            VStack(alignment: .leading) {
                                Text(player.name)
                                    .font(.system(size: 18, weight: .medium))
                                if index == 0 {
                                    Text("Winner!")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            Spacer()
                            
                            // Final score
                            Text("\(player.score)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(index == 0 ? Color.yellow.opacity(0.1) : Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(index == 0 ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                }
                
                // Host option to start a new game with same players
                if gameEngine.isHost {
                    Button("Play Again") {
                        // TODO: Implement game reset logic
                        print("Play again requested")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Players List View

/// Displays current players in the game lobby
/// Shows player count, avatars, names, and host badge
/// Used in lobby to show who has joined the game
struct PlayersListView: View {
    /// Array of players currently in the game
    let players: [Player]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header showing current player count and maximum
            Text("Players (\(players.count)/8)")
                .font(.system(size: 16, weight: .medium))
            
            // List each player with avatar, name, and host status
            ForEach(players, id: \.id) { player in
                HStack(spacing: 12) {
                    // Player's emoji avatar
                    Text(player.avatar)
                        .font(.system(size: 20))
                    
                    // Player's display name
                    Text(player.name)
                        .font(.system(size: 16))
                    
                    // Special badge indicating game host
                    if player.isHost {
                        Text("HOST")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2)
        )
    }
}

// MARK: - Custom Styles

/// Primary action button style with gradient background and press animation
/// Used for main game actions like "Start Game", "Submit Answers", etc.
/// Provides consistent styling across the app
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)      // Subtle press animation
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Custom text field style for game answer inputs
/// Provides consistent styling for category answer fields
/// Uses system gray background with border for clear definition
struct GameTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))           // Light gray background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)  // Subtle border
            )
    }
}

// MARK: - Preview Provider

/// SwiftUI preview for development and testing
/// Provides quick visual feedback during development
struct GamePlayView_Previews: PreviewProvider {
    static var previews: some View {
        GamePlayView()
            .previewDisplayName("Game Play")
            .previewDevice("iPhone 11")
    }
}



