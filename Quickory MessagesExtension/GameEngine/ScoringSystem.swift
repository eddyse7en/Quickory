//
//  ScoringSystem.swift
//  MessagesExtension
//
//  Quickory Enhanced Scoring System: Advanced scoring logic for fair and engaging gameplay
//
//  This file contains:
//  • Letter validation (words must start with round letter)
//  • Duplicate detection (no points for same answers)
//  • Speed bonus system (+5 for fastest completion)
//  • Category validation (intelligent word-category matching)
//  • Comprehensive scoring calculation
//

import Foundation

// MARK: - Scoring Configuration

/// Configuration for scoring system rules and bonuses
struct ScoringConfig {
    static let basePointsPerAnswer = 1          // Base points for each valid answer
    static let speedBonusPoints = 5             // Bonus for fastest player
    static let duplicatePenalty = 0             // Points for duplicate answers (0 = no points)
    static let invalidLetterPenalty = 0         // Points for wrong letter (0 = no points)
    static let invalidCategoryPenalty = 0       // Points for wrong category (0 = no points)
}

// MARK: - Scoring Results

/// Detailed breakdown of a player's score for one round
struct PlayerScoreBreakdown {
    let playerId: String
    let playerName: String
    var categoryScores: [CategoryScore] = []
    var speedBonus: Int = 0
    var totalScore: Int = 0
    var submissionTime: Date
    var completionTime: TimeInterval            // Seconds taken to complete
    
    /// Individual category scoring details
    struct CategoryScore {
        let category: String
        let answer: String
        let isValidLetter: Bool
        let isValidCategory: Bool
        var isDuplicate: Bool
        var points: Int
        var failureReason: String?
    }
}

// MARK: - Enhanced Scoring System

/// Advanced scoring system that implements multiple validation rules
class ScoringSystem {
    
    // MARK: - Main Scoring Methods
    
    /// Calculates enhanced scores for all players in a round using database validation
    /// - Parameters:
    ///   - submissions: All player submissions for the round
    ///   - players: Array of all players in the game
    ///   - roundLetter: The letter answers must start with
    ///   - categories: Categories for this round
    ///   - roundStartTime: When the round began (for speed calculation)
    ///   - completion: Callback with array of detailed score breakdowns
    static func calculateRoundScoresWithValidation(
        submissions: [String: PlayerSubmission],
        players: [Player],
        roundLetter: String,
        categories: [String],
        roundStartTime: Date,
        completion: @escaping ([PlayerScoreBreakdown]) -> Void
    ) {
        // Collect all unique answers that need validation
        var uniqueAnswers: Set<String> = []
        var answerToCategory: [String: String] = [:]
        
        for submission in submissions.values {
            for category in categories {
                if let answer = submission.answers[category]?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !answer.isEmpty {
                    uniqueAnswers.insert(answer.lowercased())
                    answerToCategory[answer.lowercased()] = category
                }
            }
        }
        
        // Prepare validation requests (answer, category pairs)
        let validationRequests: [(answer: String, category: String)] = uniqueAnswers.compactMap { answer in
            guard let category = answerToCategory[answer] else { return nil }
            return (answer: answer, category: category)
        }
        
        // Validate all unique answers with database
        var validationLookup: [String: ValidationResult] = [:]
        for request in validationRequests {
            let result = CategoryValidationDatabase.validate(answer: request.answer, category: request.category)
            validationLookup[request.answer] = result
        }
        
        // Calculate scores using database validation results
        let scoreBreakdowns = calculateScoresWithValidation(
            submissions: submissions,
            players: players,
            roundLetter: roundLetter,
            categories: categories,
            roundStartTime: roundStartTime,
            validationLookup: validationLookup
        )
        
        completion(scoreBreakdowns)
    }
    
    /// Calculates enhanced scores for all players in a round (legacy method without validation)
    /// - Parameters:
    ///   - submissions: All player submissions for the round
    ///   - players: Array of all players in the game
    ///   - roundLetter: The letter answers must start with
    ///   - categories: Categories for this round
    ///   - roundStartTime: When the round began (for speed calculation)
    /// - Returns: Array of detailed score breakdowns for each player
    static func calculateRoundScores(
        submissions: [String: PlayerSubmission],
        players: [Player],
        roundLetter: String,
        categories: [String],
        roundStartTime: Date
    ) -> [PlayerScoreBreakdown] {
        return calculateScoresWithValidation(
            submissions: submissions,
            players: players,
            roundLetter: roundLetter,
            categories: categories,
            roundStartTime: roundStartTime,
            validationLookup: nil
        )
    }
    
    /// Core scoring calculation method that works with or without database validation
    private static func calculateScoresWithValidation(
        submissions: [String: PlayerSubmission],
        players: [Player],
        roundLetter: String,
        categories: [String],
        roundStartTime: Date,
        validationLookup: [String: ValidationResult]?
    ) -> [PlayerScoreBreakdown] {
        
        var scoreBreakdowns: [PlayerScoreBreakdown] = []
        
        // Step 1: Create initial score breakdowns
        for submission in submissions.values {
            guard let player = players.first(where: { $0.id == submission.playerId }) else { continue }
            
            let completionTime = submission.submissionTime.timeIntervalSince(roundStartTime)
            var breakdown = PlayerScoreBreakdown(
                playerId: submission.playerId,
                playerName: player.name,
                submissionTime: submission.submissionTime,
                completionTime: completionTime
            )
            
            // Process each category
            for category in categories {
                let answer = submission.answers[category]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let categoryScore = calculateCategoryScore(
                    answer: answer,
                    category: category,
                    roundLetter: roundLetter,
                    validationLookup: validationLookup
                )
                breakdown.categoryScores.append(categoryScore)
            }
            
            scoreBreakdowns.append(breakdown)
        }
        
        // Step 2: Check for duplicates across all players
        scoreBreakdowns = checkForDuplicates(scoreBreakdowns)
        
        // Step 3: Award speed bonus to fastest player
        scoreBreakdowns = awardSpeedBonus(scoreBreakdowns)
        
        // Step 4: Calculate total scores
        for i in 0..<scoreBreakdowns.count {
            scoreBreakdowns[i].totalScore = calculateTotalScore(scoreBreakdowns[i])
        }
        
        return scoreBreakdowns
    }
    
    // MARK: - Category Scoring
    
    /// Scores a single answer for a category with optional database validation
    private static func calculateCategoryScore(
        answer: String,
        category: String,
        roundLetter: String,
        validationLookup: [String: ValidationResult]? = nil
    ) -> PlayerScoreBreakdown.CategoryScore {
        
        // Empty answer = 0 points
        guard !answer.isEmpty else {
            return PlayerScoreBreakdown.CategoryScore(
                category: category,
                answer: answer,
                isValidLetter: false,
                isValidCategory: false,
                isDuplicate: false,
                points: 0,
                failureReason: "Empty answer"
            )
        }
        
        // Check if answer starts with correct letter
        let isValidLetter = answer.lowercased().hasPrefix(roundLetter.lowercased())
        
        // Check if answer fits the category using database or fallback
        let isValidCategory: Bool
        let validationExplanation: String?
        
        if let validationLookup = validationLookup,
           let llmResult = validationLookup[answer.lowercased()] {
            // Use database validation result
            isValidCategory = llmResult.isValid
            validationExplanation = llmResult.explanation
        } else {
            // Fallback to keyword-based validation
            isValidCategory = validateAnswerForCategory(answer: answer, category: category)
            validationExplanation = nil
        }
        
        // Calculate points based on validation
        var points = 0
        var failureReason: String?
        
        if isValidLetter && isValidCategory {
            points = ScoringConfig.basePointsPerAnswer
        } else {
            if !isValidLetter {
                failureReason = "Doesn't start with '\(roundLetter)'"
                points = ScoringConfig.invalidLetterPenalty
            } else if !isValidCategory {
                failureReason = "Doesn't fit category '\(category)'"
                points = ScoringConfig.invalidCategoryPenalty
            }
        }
        
        return PlayerScoreBreakdown.CategoryScore(
            category: category,
            answer: answer,
            isValidLetter: isValidLetter,
            isValidCategory: isValidCategory,
            isDuplicate: false,  // Will be updated in duplicate check
            points: points,
            failureReason: failureReason
        )
    }
    
    // MARK: - Category Validation
    
    /// Validates if an answer fits a given category using intelligent keyword matching
    /// This is a smart system that uses category keywords to determine if answers are valid
    private static func validateAnswerForCategory(answer: String, category: String) -> Bool {
        let normalizedAnswer = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = category.lowercased()
        
        // Get category validation rules
        guard let validationRule = CategoryValidationRules.rules[normalizedCategory] else {
            // If no specific rule exists, accept any non-empty answer
            // This allows for creative categories without breaking the game
            return !normalizedAnswer.isEmpty
        }
        
        return validationRule.isValid(answer: normalizedAnswer)
    }
    
    // MARK: - Duplicate Detection
    
    /// Removes points for duplicate answers across players
    private static func checkForDuplicates(_ breakdowns: [PlayerScoreBreakdown]) -> [PlayerScoreBreakdown] {
        var updatedBreakdowns = breakdowns
        
        // Group answers by category to check for duplicates
        for categoryIndex in 0..<(breakdowns.first?.categoryScores.count ?? 0) {
            var categoryAnswers: [String: [Int]] = [:] // answer -> [player indices]
            
            // Collect all answers for this category
            for (playerIndex, breakdown) in breakdowns.enumerated() {
                if categoryIndex < breakdown.categoryScores.count {
                    let answer = breakdown.categoryScores[categoryIndex].answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !answer.isEmpty {
                        if categoryAnswers[answer] == nil {
                            categoryAnswers[answer] = []
                        }
                        categoryAnswers[answer]?.append(playerIndex)
                    }
                }
            }
            
            // Mark duplicates and remove points
            for (answer, playerIndices) in categoryAnswers {
                if playerIndices.count > 1 {
                    // Multiple players have the same answer - mark as duplicate
                    for playerIndex in playerIndices {
                        updatedBreakdowns[playerIndex].categoryScores[categoryIndex].isDuplicate = true
                        updatedBreakdowns[playerIndex].categoryScores[categoryIndex].points = ScoringConfig.duplicatePenalty
                        
                        // Update failure reason
                        let existingReason = updatedBreakdowns[playerIndex].categoryScores[categoryIndex].failureReason ?? ""
                        let duplicateReason = "Duplicate answer (shared with other players)"
                        updatedBreakdowns[playerIndex].categoryScores[categoryIndex].failureReason =
                            existingReason.isEmpty ? duplicateReason : "\(existingReason); \(duplicateReason)"
                    }
                }
            }
        }
        
        return updatedBreakdowns
    }
    
    // MARK: - Speed Bonus
    
    /// Awards speed bonus to the fastest player who completed all categories
    private static func awardSpeedBonus(_ breakdowns: [PlayerScoreBreakdown]) -> [PlayerScoreBreakdown] {
        var updatedBreakdowns = breakdowns
        
        // Find players who completed all categories (have answers for all)
        let completePlayers = breakdowns.enumerated().filter { (index, breakdown) in
            return breakdown.categoryScores.allSatisfy { !$0.answer.isEmpty }
        }
        
        // Find the fastest complete player
        if let fastestPlayer = completePlayers.min(by: { $0.element.completionTime < $1.element.completionTime }) {
            updatedBreakdowns[fastestPlayer.offset].speedBonus = ScoringConfig.speedBonusPoints
            print("🏃‍♂️ Speed bonus awarded to \(fastestPlayer.element.playerName) (completed in \(String(format: "%.1f", fastestPlayer.element.completionTime))s)")
        }
        
        return updatedBreakdowns
    }
    
    // MARK: - Total Score Calculation
    
    /// Calculates the total score for a player's round
    private static func calculateTotalScore(_ breakdown: PlayerScoreBreakdown) -> Int {
        let categoryPoints = breakdown.categoryScores.reduce(0) { $0 + $1.points }
        return categoryPoints + breakdown.speedBonus
    }
}

// MARK: - Category Validation Rules

/// Intelligent category validation system using keyword matching and rules
struct CategoryValidationRules {
    
    /// Validation rule for a category
    struct ValidationRule {
        let keywords: [String]                  // Words that definitely belong in this category
        let rejectedKeywords: [String]          // Words that definitely DON'T belong
        let allowPartialMatch: Bool             // Allow partial word matching
        let customValidator: ((String) -> Bool)?  // Custom validation function
        
        /// Checks if an answer is valid for this category
        func isValid(answer: String) -> Bool {
            let normalizedAnswer = answer.lowercased()
            
            // Check rejected keywords first
            for rejected in rejectedKeywords {
                if normalizedAnswer.contains(rejected.lowercased()) {
                    return false
                }
            }
            
            // Use custom validator if provided
            if let customValidator = customValidator {
                return customValidator(normalizedAnswer)
            }
            
            // Check positive keywords
            for keyword in keywords {
                let normalizedKeyword = keyword.lowercased()
                if allowPartialMatch {
                    if normalizedAnswer.contains(normalizedKeyword) || normalizedKeyword.contains(normalizedAnswer) {
                        return true
                    }
                } else {
                    if normalizedAnswer == normalizedKeyword {
                        return true
                    }
                }
            }
            
            // If no keywords match, but it's a reasonable length word, allow it
            // This prevents the system from being too restrictive
            return normalizedAnswer.count >= 2 && normalizedAnswer.count <= 20
        }
    }
    
    /// Category validation rules database
    static let rules: [String: ValidationRule] = [
        
        // Basic Categories
        "animals": ValidationRule(
            keywords: ["dog", "cat", "lion", "tiger", "elephant", "bird", "fish", "snake", "horse", "cow", "pig", "sheep", "goat", "chicken", "duck", "rabbit", "mouse", "rat", "bear", "wolf", "fox", "deer", "zebra", "giraffe", "monkey", "ape", "whale", "dolphin", "shark", "octopus", "spider", "ant", "bee", "butterfly", "eagle", "owl", "penguin", "kangaroo", "koala", "panda", "rhino", "hippo"],
            rejectedKeywords: ["person", "human", "car", "house", "food"],
            allowPartialMatch: true,
            customValidator: nil
        ),
        
        "food & drinks": ValidationRule(
            keywords: ["pizza", "burger", "bread", "apple", "banana", "orange", "water", "juice", "coffee", "tea", "milk", "cheese", "meat", "chicken", "beef", "fish", "rice", "pasta", "salad", "soup", "cake", "cookie", "chocolate", "ice cream", "beer", "wine", "soda", "sandwich", "taco", "sushi", "noodles", "egg", "bacon", "cereal", "yogurt", "fruit", "vegetable"],
            rejectedKeywords: ["animal", "car", "house", "person"],
            allowPartialMatch: true,
            customValidator: nil
        ),
        
        "movies": ValidationRule(
            keywords: ["avatar", "titanic", "avengers", "batman", "superman", "starwars", "indiana", "jurassic", "matrix", "terminator", "alien", "jaws", "rocky", "godfather", "casablanca", "psycho", "vertigo", "singin", "wizard", "gone", "lawrence", "schindler", "citizen", "sunset", "graduate", "bridge", "apartment", "maltese", "raging", "north", "chinatown", "goodfellas", "pulp", "deer", "apocalypse", "taxi", "silence", "unforgiven", "network", "african", "singin", "some", "all", "sunset", "mr", "double", "high", "philadelphia", "amadeus", "sting", "ordinary", "verdict", "tootsie", "breaking", "hospital", "french", "butch", "sundance", "cool", "bonnie", "midnight", "graduate", "african", "queen", "treasure", "sierra", "strada", "bicycle", "thief", "grand", "illusion", "bicycle", "thief"],
            rejectedKeywords: ["food", "animal", "car", "person"],
            allowPartialMatch: true,
            customValidator: nil
        ),
        
        "countries": ValidationRule(
            keywords: ["usa", "america", "canada", "mexico", "brazil", "argentina", "chile", "colombia", "peru", "venezuela", "uk", "england", "france", "germany", "italy", "spain", "portugal", "netherlands", "belgium", "switzerland", "austria", "poland", "russia", "china", "japan", "india", "australia", "egypt", "south africa", "nigeria", "kenya", "morocco", "turkey", "greece", "sweden", "norway", "denmark", "finland", "iceland"],
            rejectedKeywords: ["food", "animal", "movie", "person"],
            allowPartialMatch: true,
            customValidator: nil
        ),
        
        "colors": ValidationRule(
            keywords: ["red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white", "gray", "grey", "brown", "violet", "indigo", "cyan", "magenta", "maroon", "navy", "olive", "lime", "aqua", "silver", "gold", "beige", "tan", "coral", "salmon", "crimson", "scarlet", "turquoise", "teal"],
            rejectedKeywords: ["food", "animal", "movie", "person", "car", "house"],
            allowPartialMatch: true,
            customValidator: nil
        ),
        
        // Creative Categories
        "things that are red": ValidationRule(
            keywords: ["apple", "strawberry", "cherry", "tomato", "rose", "fire", "blood", "lipstick", "wine", "brick", "cardinal", "stop sign", "fire truck", "coca cola", "santa", "valentine", "mars", "ruby", "ladybug", "barn"],
            rejectedKeywords: [],
            allowPartialMatch: true,
            customValidator: { answer in
                // Custom logic: if it contains "red" or commonly red things
                return answer.contains("red") || answer.contains("crimson") || answer.contains("scarlet")
            }
        ),
        
        "things you find in a park": ValidationRule(
            keywords: ["tree", "bench", "playground", "swing", "slide", "grass", "flower", "pond", "duck", "squirrel", "path", "trail", "picnic", "table", "fountain", "statue", "jogger", "dog", "frisbee", "ball", "children", "families"],
            rejectedKeywords: ["car", "house", "office", "kitchen"],
            allowPartialMatch: true,
            customValidator: nil
        ),
        
        "superheroes": ValidationRule(
            keywords: ["superman", "batman", "spiderman", "wonderwoman", "hulk", "ironman", "captain", "thor", "flash", "aquaman", "green lantern", "wolverine", "deadpool", "punisher", "daredevil", "antman", "wasp", "hawkeye", "black widow", "falcon", "winter soldier", "scarlet witch", "vision", "doctor strange", "black panther"],
            rejectedKeywords: ["food", "animal", "car", "house"],
            allowPartialMatch: true,
            customValidator: nil
        )
        
        // Add more categories as needed...
    ]
}
