//
//  MessagesViewController.swift
//  Quickory MessagesExtension
//
//  Main controller for the iMessage app extension.
//  Subclasses MSMessagesAppViewController, embeds the SwiftUI
//  root view (QuickoryContainerView) using a UIHostingController,
//  and handles sending/receiving game messages via MSMessage.
//

// Core framework imports for iMessage extension functionality
import UIKit
import SwiftUI
import Messages

final class MessagesViewController: MSMessagesAppViewController {

    // MARK: - Properties
    
    // SwiftUI hosting controller for displaying game interface
    private var hostingController: UIHostingController<QuickoryContainerView>?

    // MARK: - Lifecycle Methods
    
    // Initialize extension view and setup components
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIView()
        setupNotificationObserver()
    }

    // MARK: - SwiftUI Integration
    
    // Configure SwiftUI game view within UIKit container
    private func setupSwiftUIView() {
        
        // Create main game container view
        let swiftUIView = QuickoryContainerView()
        
        // Wrap SwiftUI view in UIKit hosting controller
        hostingController = UIHostingController(rootView: swiftUIView)
        
        // Safely unwrap hosting controller
        guard let hostingController = hostingController else { return }
        
        // Add hosting controller as child for proper lifecycle management
        addChild(hostingController)
        view.addSubview(hostingController.view)

        // Configure auto-layout constraints to fill parent view
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Complete child controller setup
        hostingController.didMove(toParent: self)
        hostingController.view.backgroundColor = .clear
    }

    // MARK: - Notification Handling
    
    // Setup observer for game invitation requests
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGameInvitationRequest(_:)),
            name: .sendGameInvitation,   // Custom notification name from extension
            object: nil
        )
    }

    // Handle game invitation requests and forward to message sender
    @objc private func handleGameInvitationRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any] else {
            print("❌ No user info in game invitation notification")
            return
        }
        sendGameMessage(with: userInfo) // Forward to QuickoryIntegration.swift
    }

    // MARK: - Message Lifecycle Management
    
    // Handle extension activation and existing message selection
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        if let selected = conversation.selectedMessage {
            handleIncomingGameMessage(selected) // Process selected message
        }
    }

    // Handle message bubble selection while extension is active
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        handleIncomingGameMessage(message) // Process selected message
    }

    // MARK: - Message Sending/Receiving
    
    // Process incoming messages from other devices
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        print("📨 Received message from another device")
        handleIncomingGameMessage(message) // Process received message
    }

    // Track message sending initiation
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        super.didStartSending(message, conversation: conversation)
        print("📤 Started sending Quickory message")
    }

    // Track message sending cancellation
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        super.didCancelSending(message, conversation: conversation)
        print("❌ Cancelled sending Quickory message")
    }

    // MARK: - Cleanup
    
    // Remove notification observers on deallocation
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - MessagesViewController Extensions
extension MessagesViewController {
    
    /// Processes incoming iMessage game messages
    /// Parses message URL components and routes to appropriate handler
    /// Should be called from existing message handling methods
    func handleIncomingGameMessage(_ message: MSMessage) {
        // Extract URL components from received message
        guard let messageURL = message.url,
              let components = URLComponents(url: messageURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        // Parse query parameters into dictionary
        var gameData: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                gameData[item.name] = value
            }
        }
        
        // Route message based on action type
        if let action = gameData["action"] {
            switch action {
            case "newGameInvitation":
                handleGameInvitation(gameData)
            case "gameUpdate":
                handleGameUpdate(gameData)
            default:
                break
            }
        }
    }
    
    /// Handles incoming game invitation messages
    /// Decodes game state and presents join dialog to user
    private func handleGameInvitation(_ gameData: [String: String]) {
        // Decode Base64 encoded game state from invitation
        guard let gameStateString = gameData["gameState"],
              let gameStateData = Data(base64Encoded: gameStateString),
              let gameState = try? JSONDecoder().decode(GameState.self, from: gameStateData) else {
            print("❌ Failed to decode game state from invitation")
            return
        }
        
        // Present join game dialog to user
        showJoinGamePrompt(for: gameState)
    }

    
    private func handleGameUpdate(_ gameData: [String: String]) {
        // Handle real-time game updates
        guard let gameStateString = gameData["gameState"],
              let gameStateData = Data(base64Encoded: gameStateString),
              let gameState = try? JSONDecoder().decode(GameState.self, from: gameStateData) else {
            print("❌ Failed to decode game state update")
            return
        }
        
        print("📨 Received game update: \(gameState.players.count) players in game")
        
        // Send update to current game view
        NotificationCenter.default.post(
            name: NSNotification.Name("ReceiveGameUpdate"),
            object: nil,
            userInfo: ["gameStateData": gameStateData]
        )
    }

    
    private func showJoinGamePrompt(for gameState: GameState) {
        let alert = UIAlertController(
            title: "Game Invitation",
            message: "\(gameState.hostPlayer.name) invited you to play Quickory!\n\n\(gameState.totalRounds) rounds • \(gameState.categoriesPerRound) categories",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Join Game", style: .default) { _ in
            self.joinGame(gameState)
        })
        
        alert.addAction(UIAlertAction(title: "Decline", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func joinGame(_ gameState: GameState) {
        // Get player info - for now using placeholder, should be customizable
        let playerName = "Player \(gameState.players.count + 1)"
        let playerAvatar = ["🙂", "😊", "🎮", "⭐", "🚀", "🎯"].randomElement() ?? "🙂"
        
        // Create game engine and join the game
        let gameEngine = GameEngine()
        gameEngine.joinGame(with: gameState, playerName: playerName, playerAvatar: playerAvatar)
        
        // Get the updated game state (now includes this player)
        guard let updatedGameState = gameEngine.gameState,
              let gameStateData = try? JSONEncoder().encode(updatedGameState) else {
            print("❌ Failed to encode updated game state when joining")
            return
        }
        
        let base64String = gameStateData.base64EncodedString()
        
        // Send updated game state to conversation (notify other players)
        let gameData: [String: Any] = [
            "action": "gameUpdate",
            "gameState": base64String,
            "gameId": updatedGameState.gameId,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendGameMessage(with: gameData)
        
        // Navigate to gameplay view with updated state
        NotificationCenter.default.post(
            name: NSNotification.Name("StartGameplay"),
            object: nil,
            userInfo: ["gameState": base64String]
        )
        
        // Switch to expanded view if needed
        requestPresentationStyle(.expanded)
    }
    
    /**
     * Send game message to conversation
     * Call this from your notification observers
     */
    func sendGameMessage(with gameData: [String: Any]) {
        guard let conversation = activeConversation else { return }
        
        // Create message URL with game data
        var components = URLComponents()
        components.scheme = "quickory"
        components.host = "game"
        components.queryItems = []
        
        for (key, value) in gameData {
            if let stringValue = value as? String {
                components.queryItems?.append(URLQueryItem(name: key, value: stringValue))
            } else if let dataValue = value as? Data {
                // Encode data as base64 string
                let base64String = dataValue.base64EncodedString()
                components.queryItems?.append(URLQueryItem(name: key, value: base64String))
            } else {
                // Convert other types to string
                components.queryItems?.append(URLQueryItem(name: key, value: String(describing: value)))
            }
        }
        
        // Create and configure message
        let message = MSMessage()
        message.url = components.url
        
        // Set message layout
        let layout = MSMessageTemplateLayout()
        layout.image = createGameMessageImage(from: gameData)
        layout.caption = createGameMessageCaption(from: gameData)
        message.layout = layout
        
        // Insert message
        conversation.insert(message) { error in
            if let error = error {
                print("❌ Failed to send message: \(error)")
            } else {
                print("✅ Game message sent successfully")
            }
        }
    }
    
    private func createGameMessageImage(from gameData: [String: Any]) -> UIImage? {
        // Create a simple game invitation image
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        defer { UIGraphicsEndImageContext() }
        
        // Background
        UIColor.systemBlue.withAlphaComponent(0.1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Game title
        let title = "Quickory"
        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (size.width - titleSize.width) / 2,
            y: 40,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Game details
        if let hostName = gameData["hostName"] as? String {
            let subtitle = "\(hostName) invited you to play!"
            let subtitleFont = UIFont.systemFont(ofSize: 16)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            let subtitleRect = CGRect(
                x: (size.width - subtitleSize.width) / 2,
                y: titleRect.maxY + 20,
                width: subtitleSize.width,
                height: subtitleSize.height
            )
            subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func createGameMessageCaption(from gameData: [String: Any]) -> String {
        if let hostName = gameData["hostName"] as? String,
           let rounds = gameData["rounds"] as? Int,
           let categories = gameData["categories"] as? Int {
            return "\(hostName) invited you to play Quickory! \(rounds) rounds, \(categories) categories"
        }
        return "Join the Quickory game!"
    }
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let sendGameInvitation = NSNotification.Name("SendGameInvitation")
    static let startGameplay = NSNotification.Name("StartGameplay")
    static let backToMenu = NSNotification.Name("BackToMenu")
    static let receiveGameUpdate = NSNotification.Name("ReceiveGameUpdate")
}
