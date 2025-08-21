//
//  GameEngine.swift
//  MessagesExtension
//
//  Quickory Game Engine: Core logic controller for multiplayer word game
//
//  This file contains:
//  • GameEngine class - Main game logic and flow management
//  • Game setup (creating/joining games)
//  • Round management (timing, scoring, progression)
//  • Player actions (answer submission)
//  • Real-time communication between players
//

import Foundation
import Combine

// MARK: - Game Engine

/// Core game logic controller that manages game state and flow
/// ObservableObject for SwiftUI reactive updates
/// Handles: game creation, player management, round timing, scoring, communication
class GameEngine: ObservableObject {
    // MARK: - Published Properties (Observable by SwiftUI)
    @Published var gameState: GameState?        // Current state of the game (nil = no active game)
    @Published var isHost: Bool = false         // Whether current device is the game host
    @Published var currentPlayer: Player?       // The player on this device
    @Published var timeRemaining: Int = 0       // Seconds left in current round
    @Published var errorMessage: String?        // Error message to display to user
    
    // MARK: - Private Properties
    private var timer: Timer?                   // Countdown timer for rounds
    
    // MARK: - Game Configuration
    // TEMPORARY: For testing - normally should be 2
    private let minPlayers = 1                  // TODO: Change back to 2 for production
    private let maxPlayers = 8                  // Maximum players allowed in one game
    
    // MARK: - Game Setup
    
    /// Creates a new game with the current device as host
    /// - Parameters:
    ///   - hostName: Display name for the host player
    ///   - hostAvatar: Emoji avatar for the host
    ///   - rounds: Total number of rounds to play
    ///   - categories: Number of categories per round
    func createNewGame(hostName: String, hostAvatar: String, rounds: Int, categories: Int) {
        // Create host player and initialize game state
        let host = Player(name: hostName, avatar: hostAvatar, isHost: true)
        self.gameState = GameState(
            gameId: UUID().uuidString,
            hostPlayer: host,
            totalRounds: rounds,
            categoriesPerRound: categories,
            roundDuration: 120                  // 2 minutes per round
        )
        
        // Set local player info
        self.currentPlayer = host
        self.isHost = true
        
        print("🎮 New game created: \(gameState?.gameId ?? "")")
    }
    
    /// Joins an existing game created by another player
    /// - Parameters:
    ///   - gameState: The current game state received from host
    ///   - playerName: Display name for this player
    ///   - playerAvatar: Emoji avatar for this player
    func joinGame(with gameState: GameState, playerName: String, playerAvatar: String) {
        let player = Player(name: playerName, avatar: playerAvatar)
        var updatedState = gameState
        
        // Validate game capacity
        guard updatedState.players.count < maxPlayers else {
            self.errorMessage = "Game is full"
            return
        }
        
        // Add player if not already in game (prevent duplicates)
        if !updatedState.players.contains(where: { $0.name == playerName }) {
            updatedState.players.append(player)
        }
        
        // Update local state
        self.gameState = updatedState
        self.currentPlayer = player
        self.isHost = false
        
        print("👥 Player joined game: \(playerName)")
        
        // Broadcast updated player list to all devices
        sendGameUpdate()
    }
    
    // MARK: - Game Flow
    
    /// Initiates the game (host only)
    /// Validates minimum players and starts first round
    func startGame() {
        // Only host can start the game
        guard var state = gameState, isHost else { return }
        
        // Validate minimum player count
        guard state.players.count >= minPlayers else {
            errorMessage = "Need at least \(minPlayers) players to start"
            return
        }
        
        // Transition to ready state and begin first round
        state.gameStatus = .ready
        state.currentRound = 1
        gameState = state
        
        startNextRound()
        print("🚀 Game started!")
    }
    
    /// Starts a new round (host only)
    /// Generates letter, categories, starts timer, and notifies players
    func startNextRound() {
        // Only host controls round flow
        guard var state = gameState, isHost else { return }
        
        // Check if game is complete
        guard state.currentRound <= state.totalRounds else {
            endGame()
            return
        }
        
        // Generate new round data
        state.currentLetter = CategoryData.getRandomLetter()
        state.currentCategories = CategoryData.getRandomCategories(count: state.categoriesPerRound)
        state.roundStartTime = Date()
        state.gameStatus = .roundInProgress
        state.submissions.removeAll()           // Clear previous round's answers
        state.submittedPlayerIds.removeAll()   // Clear previous round's submission tracking
        
        gameState = state
        
        // Initialize and start countdown timer
        timeRemaining = Int(state.roundDuration)
        startTimer()
        
        print("⏱️ Round \(state.currentRound) started - Letter: \(state.currentLetter!) Categories: \(state.currentCategories)")
        
        // Notify all players that new round has started
        sendGameUpdate()
    }
    
    /// Starts the countdown timer for the current round
    /// Updates timeRemaining every second and ends round when time expires
    private func startTimer() {
        timer?.invalidate()                     // Cancel any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.timeRemaining -= 1
            
            // End round when timer reaches zero
            if self.timeRemaining <= 0 {
                self.endRound()
            }
        }
    }
    
    /// Ends the current round and processes results
    /// Called when timer expires or all players submit answers
    func endRound() {
        timer?.invalidate()                     // Stop the countdown timer
        guard var state = gameState else { return }
        
        // Mark round as ended
        state.gameStatus = .roundEnded
        gameState = state
        
        if isHost {
            // Host processes scores after brief delay for UI feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.processRoundResults()
            }
        }
        
        print("⏹️ Round \(state.currentRound) ended")
    }
    
    /// Calculates scores for the round using enhanced scoring system and advances to next round or ends game
    /// Host-only function that processes all player submissions with advanced validation
    private func processRoundResults() {
        guard var state = gameState, isHost else { return }
        guard let roundStartTime = state.roundStartTime,
              let currentLetter = state.currentLetter else { return }
        
        // Use enhanced scoring system with database validation
        ScoringSystem.calculateRoundScoresWithValidation(
            submissions: state.submissions,
            players: state.players,
            roundLetter: currentLetter,
            categories: state.currentCategories,
            roundStartTime: roundStartTime
        ) { scoreBreakdowns in
            // Apply calculated scores to players
            for breakdown in scoreBreakdowns {
                if let playerIndex = state.players.firstIndex(where: { $0.id == breakdown.playerId }) {
                    state.players[playerIndex].score += breakdown.totalScore
                    
                    // Log detailed scoring breakdown for debugging
                    print("📊 \(breakdown.playerName) scored \(breakdown.totalScore) points this round:")
                    for categoryScore in breakdown.categoryScores {
                        let status = categoryScore.points > 0 ? "✅" : "❌"
                        print("  \(status) \(categoryScore.category): '\(categoryScore.answer)' (\(categoryScore.points) pts)")
                        if let reason = categoryScore.failureReason {
                            print("    - \(reason)")
                        }
                    }
                    if breakdown.speedBonus > 0 {
                        print("  🏃‍♂️ Speed bonus: +\(breakdown.speedBonus) pts")
                    }
                }
            }
            
            // Update game state and continue to next round
            self.gameState = state
            self.continueToNextRound()
        }
    }
    
    /// Continues to next round or ends game after scoring is complete
    private func continueToNextRound() {
        guard var state = gameState else { return }
        
        // Move to next round
        state.currentRound += 1
        
        if state.currentRound <= state.totalRounds {
            gameState = state
            // Brief pause before starting next round for score display
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.startNextRound()
            }
        } else {
            // All rounds completed, end the game
            endGame()
        }
    }
    
    /// Ends the entire game and shows final results
    /// Called when all rounds are completed
    private func endGame() {
        guard var state = gameState else { return }
        
        // Mark game as completed
        state.gameStatus = .gameCompleted
        gameState = state
        timer?.invalidate()                     // Ensure timer is stopped
        
        print("🏁 Game completed!")
        sendGameUpdate()                        // Notify all players of game end
    }
    
    // MARK: - Player Actions
    
    /// Submits a player's answers for the current round
    /// - Parameter answers: Dictionary of category -> player's answer
    func submitAnswers(_ answers: [String: String]) {
        // Validate submission conditions
        guard var state = gameState,
              let player = currentPlayer,
              state.gameStatus == .roundInProgress || state.gameStatus == .waitingForSubmissions else { return }
        
        // Check if player has already submitted for this round
        guard !state.submittedPlayerIds.contains(player.id) else {
            print("⚠️ Player \(player.name) already submitted for this round")
            return
        }
        
        // Create and store submission
        let submission = PlayerSubmission(playerId: player.id, answers: answers)
        state.submissions[player.id] = submission
        state.submittedPlayerIds.insert(player.id)
        
        // Check if this is the first submission - move to waiting state
        if state.gameStatus == .roundInProgress {
            state.gameStatus = .waitingForSubmissions
        }
        
        gameState = state
        
        print("📝 Answers submitted by \(player.name): \(answers)")
        print("📊 Submissions: \(state.submittedPlayerIds.count)/\(state.players.count) players")
        
        // Check if all players have submitted
        if state.submittedPlayerIds.count >= state.players.count {
            print("🎯 All players have submitted! Moving to scoring...")
            endRound()
        }
        
        // Broadcast submission to all players for real-time updates
        sendGameUpdate()
    }
    
    // MARK: - Communication
    
    /// Broadcasts current game state to all players via notifications
    /// Handles both local UI updates and iMessage transmission
    private func sendGameUpdate() {
        guard let state = gameState else { return }
        
        // 1. Update local game view immediately
        let localGameData: [String: Any] = [
            "action": "gameUpdate",
            "gameState": encodeGameState(state),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ReceiveGameUpdate"),
            object: nil,
            userInfo: localGameData
        )
        
        // 2. Send to other players via iMessage
        if let gameStateData = encodeGameState(state) {
            let base64String = gameStateData.base64EncodedString()
            let messageGameData: [String: Any] = [
                "action": "gameUpdate",
                "gameState": base64String,
                "gameId": state.gameId,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            // Trigger message sending via MessagesViewController
            NotificationCenter.default.post(
                name: NSNotification.Name("SendGameInvitation"),
                object: nil,
                userInfo: messageGameData
            )
        }
    }
    
    /// Processes incoming game state updates from other players
    /// - Parameter gameState: Updated game state received via iMessage
    func receiveGameUpdate(_ gameState: GameState) {
        self.gameState = gameState
        
        // Determine if this device is the host
        if let currentPlayer = self.currentPlayer {
            self.isHost = currentPlayer.id == gameState.hostPlayer.id
        } else {
            // Fallback: check if we match the host player info
            self.isHost = gameState.hostPlayer.isHost
        }
        
        print("🔄 Game update received - isHost: \(self.isHost), currentPlayer: \(self.currentPlayer?.name ?? "none")")
        
        // Sync timer for active rounds (non-hosts sync to host's timer)
        if gameState.gameStatus == .roundInProgress,
           let startTime = gameState.roundStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, gameState.roundDuration - elapsed)
            self.timeRemaining = Int(remaining)
            
            // Non-hosts start their timer to sync with host
            if remaining > 0 && !isHost {
                startTimer()
            }
        }
    }
    
    /// Encodes game state to Data for transmission
    /// - Parameter state: Game state to encode
    /// - Returns: Encoded data or nil if encoding fails
    private func encodeGameState(_ state: GameState) -> Data? {
        return try? JSONEncoder().encode(state)
    }
    
    /// Decodes game state from received Data
    /// - Parameter data: Encoded game state data
    /// - Returns: Decoded GameState or nil if decoding fails
    func decodeGameState(from data: Data) -> GameState? {
        return try? JSONDecoder().decode(GameState.self, from: data)
    }
    
    // MARK: - Cleanup
    
    /// Clean up resources when GameEngine is deallocated
    deinit {
        timer?.invalidate()                     // Stop any running timers
    }
}
