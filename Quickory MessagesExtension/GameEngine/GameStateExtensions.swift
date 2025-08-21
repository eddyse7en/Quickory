//
//  GameStateExtensions.swift
//  MessagesExtension
//
//  Quickory GameState Extensions: Convenience methods for UI and game logic
//
//  This file contains:
//  • GameState computed properties for common state checks
//  • UI helper methods for formatting and display
//  • Convenience methods that make the GameState easier to work with
//

import Foundation

// MARK: - GameState Extensions

/// GameState convenience methods for UI and game logic
extension GameState {
    
    /// Whether the game has enough players to start
    /// TEMPORARY: For testing - normally should be >= 2
    var canStart: Bool {
        return players.count >= 1 && gameStatus == .waitingForPlayers  // TODO: Change back to >= 2 for production
    }
    
    /// Whether the game is in the initial waiting state
    var isWaitingForPlayers: Bool {
        return gameStatus == .waitingForPlayers
    }
    
    /// Whether a round is currently active (players can submit answers)
    var isRoundActive: Bool {
        return gameStatus == .roundInProgress
    }
    
    /// Whether the entire game has finished
    var isGameComplete: Bool {
        return gameStatus == .gameCompleted
    }
    
    /// Players sorted by score (highest first) for leaderboard display
    var topPlayers: [Player] {
        return players.sorted { $0.score > $1.score }
    }
    
    /// Formats time remaining as MM:SS for display
    /// - Parameter timeRemaining: Seconds remaining
    /// - Returns: Formatted time string (e.g., "1:23")
    func getFormattedTimeRemaining(from timeRemaining: Int) -> String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
