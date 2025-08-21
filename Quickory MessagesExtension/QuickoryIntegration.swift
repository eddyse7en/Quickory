//
//  QuickoryIntegration.swift
//  MessagesExtension
//
//  Integration updates for your existing QuickoryViews
//


import Foundation
import UIKit
import SwiftUI
import Messages

// MARK: - Main Menu Integration Notes
/**
 * The MainMenuView already has the necessary integration methods.
 * This file contains the QuickoryContainerView and MessagesViewController extensions.
 */

// MARK: - Game Container View
/**
 * Main container that handles navigation between menu and gameplay
 * Use this as your root view in MessagesViewController
 */
struct QuickoryContainerView: View {
    @State private var currentView: GameViewState = .menu
    @State private var receivedGameState: GameState?
    
    enum GameViewState {
        case menu
        case gameplay
    }
    
    var body: some View {
        ZStack {
            switch currentView {
            case .menu:
                // Main menu with game creation/joining options
                MainMenuView()
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartGameplay"))) { notification in
                        // Handle transition from menu to gameplay
                        if let gameStateString = notification.userInfo?["gameState"] as? String,
                           let gameStateData = Data(base64Encoded: gameStateString),
                           let gameState = try? JSONDecoder().decode(GameState.self, from: gameStateData) {
                            
                            receivedGameState = gameState
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentView = .gameplay
                            }
                        }
                    }
                    
            case .gameplay:
                // Active game interface with received game state
                GamePlayView(gameState: receivedGameState)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BackToMenu"))) { _ in
            // Handle return to main menu (e.g., when game ends)
            withAnimation(.easeInOut(duration: 0.3)) {
                currentView = .menu
                receivedGameState = nil
            }
        }
    }
}

// MARK: - MessagesViewController Integration Notes
/**
 * All MessagesViewController extensions are implemented in MessagesViewController.swift
 * This file only contains the QuickoryContainerView
 */

// MARK: - Notification Names
/**
 * Notification name extensions are defined in MessagesViewController.swift
 */

