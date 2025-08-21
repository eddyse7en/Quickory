//
//  GameModels.swift
//  MessagesExtension
//
//  Quickory Game Models: Core data structures for multiplayer word game
//
//  This file contains:
//  • GameState - Central game state tracking
//  • Player - Individual player representation
//  • PlayerSubmission - Round answer submissions
//  • GameStatus - Game lifecycle states
//  • CategoryData - Game categories and letters
//

import Foundation

// MARK: - Game Models

/// Central game state that tracks all game information across devices
/// Codable for serialization between players via iMessage
struct GameState: Codable {
    let gameId: String                              // Unique identifier for this game session
    let hostPlayer: Player                          // Player who created the game (controls flow)
    var players: [Player]                           // All players currently in the game
    var currentRound: Int                           // Current round number (1-based)
    let totalRounds: Int                            // Total rounds configured for this game
    let categoriesPerRound: Int                     // Number of categories per round
    var gameStatus: GameStatus                      // Current state of the game
    var currentLetter: String?                      // Letter that answers must start with
    var currentCategories: [String]                 // Categories for the current round
    var roundStartTime: Date?                       // When the current round started (for timing)
    var roundDuration: TimeInterval                 // Time limit per round in seconds
    var submissions: [String: PlayerSubmission]     // Player ID -> their answers for current round
    var submittedPlayerIds: Set<String>             // Player IDs who have submitted this round
    
    /// Initialize a new game state
    /// - Parameters:
    ///   - gameId: Unique identifier for this game
    ///   - hostPlayer: Player who created the game
    ///   - totalRounds: Number of rounds to play
    ///   - categoriesPerRound: Categories per round
    ///   - roundDuration: Time limit per round (default 2 minutes)
    init(gameId: String, hostPlayer: Player, totalRounds: Int, categoriesPerRound: Int, roundDuration: TimeInterval = 120) {
        self.gameId = gameId
        self.hostPlayer = hostPlayer
        self.players = [hostPlayer]                 // Start with just the host
        self.currentRound = 0                       // Game hasn't started yet
        self.totalRounds = totalRounds
        self.categoriesPerRound = categoriesPerRound
        self.gameStatus = .waitingForPlayers        // Initial state
        self.currentCategories = []                 // No active round yet
        self.roundDuration = roundDuration
        self.submissions = [:]                      // No submissions yet
        self.submittedPlayerIds = []                // No submissions yet
    }
}

/// Represents an individual player in the game
/// Identifiable for SwiftUI lists, Equatable for comparisons, Codable for transmission
struct Player: Codable, Identifiable, Equatable {
    let id: String          // Unique player identifier (UUID)
    let name: String        // Display name chosen by player
    let avatar: String      // Emoji avatar for visual identification
    var score: Int          // Cumulative score across all rounds
    var isHost: Bool        // Whether this player created/controls the game
    
    /// Initialize a new player
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - name: Display name for the player
    ///   - avatar: Emoji avatar for visual identification
    ///   - isHost: Whether this player created/controls the game
    init(id: String = UUID().uuidString, name: String, avatar: String, isHost: Bool = false) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.score = 0                              // Start with zero score
        self.isHost = isHost
    }
}

/// Contains a player's answers for one round
/// Tracks submission time and validation status for scoring
struct PlayerSubmission: Codable {
    let playerId: String                    // ID of player who submitted these answers
    let answers: [String: String]           // Category name -> player's answer
    let submissionTime: Date                // When answers were submitted (for timing bonuses)
    var isValidated: Bool = false           // Whether answers have been checked
    var validAnswers: Set<String> = []      // Which categories had valid answers
    
    /// Initialize a player's submission for a round
    /// - Parameters:
    ///   - playerId: ID of the player submitting answers
    ///   - answers: Dictionary of category -> answer
    init(playerId: String, answers: [String: String]) {
        self.playerId = playerId
        self.answers = answers
        self.submissionTime = Date()                // Record when submitted
    }
}

/// Tracks the current phase of the game lifecycle
/// String raw values for easy debugging and logging
enum GameStatus: String, Codable, CaseIterable {
    case waitingForPlayers = "waiting"     // Game created, waiting for more players to join
    case ready = "ready"                   // Enough players joined, can start first round
    case roundInProgress = "playing"       // Round active, players answering questions
    case waitingForSubmissions = "waitingForSubmissions"  // Some players submitted, waiting for others
    case roundEnded = "roundEnded"         // Round finished, processing results
    case gameCompleted = "completed"       // All rounds done, showing final scores
    
    var displayText: String {
        switch self {
        case .waitingForPlayers: return "Waiting for players..."
        case .ready: return "Ready to start!"
        case .roundInProgress: return "Round in progress"
        case .waitingForSubmissions: return "Waiting for other players submissions..."
        case .roundEnded: return "Round complete"
        case .gameCompleted: return "Game finished!"
        }
    }
}

// MARK: - Category Data

/// Static data source for game categories and letters
/// Provides randomization methods for game variety
struct CategoryData {
    static let categories = [
        // Basic Categories - Simple, universal topics everyone knows
        "Animals", "Food & Drinks", "Movies", "Countries", "Colors",
        "Sports", "Professions", "Things in a Kitchen", "Clothing",
        "School Subjects", "Musical Instruments", "Vehicles",
        
        // Fun Categories - More creative and engaging topics
        "Things That Are Red", "Things You Find in a Park", "Superheroes",
        "Things That Make Noise", "Things in the Sky", "Board Games",
        "Ice Cream Flavors", "Pizza Toppings", "Cartoon Characters",
        
        // Creative Categories - Require more imagination
        "Things That Are Round", "Things You Take on Vacation",
        "Things in a Bathroom", "Things That Are Soft", "Video Games",
        "Things You Can Draw", "Things That Smell Good", "Breakfast Foods",
        
        // Advanced Categories - Challenging topics for experienced players
        "Historical Figures", "Mythical Creatures", "Book Titles",
        "Things Made of Wood", "Things That Are Expensive",
        "Things You Do at Night", "Things That Are Scary",
        "Things You Can Collection", "Dance Moves", "Magic Spells"
    ]
    
    /// Letters that work well for the game
    /// Excludes difficult letters (Q, X, Z) that have few common words
    static let gameLetters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "R", "S", "T", "U", "V", "W", "Y"]
    
    /// Selects random categories for a round, ensuring variety
    /// - Parameter count: Number of categories needed
    /// - Returns: Array of unique random categories
    static func getRandomCategories(count: Int) -> [String] {
        return Array(categories.shuffled().prefix(count))
    }
    
    /// Selects a random letter for the round
    /// - Returns: Random letter from gameLetters array, defaults to "A" if error
    static func getRandomLetter() -> String {
        return gameLetters.randomElement() ?? "A"
    }
}
