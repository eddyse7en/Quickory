//
//  CategoryValidationDatabase.swift
//  MessagesExtension
//
//  Simple category validation using predefined word database
//  This provides immediate validation without requiring LLM API calls
//

import Foundation

// MARK: - Validation Result

/// Result of category validation
struct ValidationResult {
    let isValid: Bool
    let confidence: Float           // 0.0 to 1.0
    let explanation: String
    let source: ValidationSource
    
    enum ValidationSource {
        case database              // From local database
        case fuzzyMatch           // From fuzzy string matching
        case rejected             // Clearly invalid
    }
}

// MARK: - Category Validation Database

/// Simple category validator using predefined word database
class CategoryValidationDatabase {
    
    // MARK: - Properties
    
    private static let categoryDatabase: [String: Set<String>] = [
        // Animals
        "animals": [
            "cat", "dog", "bird", "fish", "lion", "tiger", "elephant", "giraffe",
            "monkey", "bear", "wolf", "fox", "rabbit", "mouse", "horse", "cow",
            "pig", "sheep", "goat", "chicken", "duck", "goose", "snake", "lizard",
            "turtle", "frog", "butterfly", "bee", "spider", "ant", "whale", "dolphin",
            "shark", "eagle", "hawk", "owl", "penguin", "kangaroo", "koala", "panda"
        ],
        
        // Food
        "food": [
            "apple", "banana", "orange", "grape", "strawberry", "pizza", "burger",
            "sandwich", "pasta", "rice", "bread", "cheese", "milk", "egg", "chicken",
            "beef", "pork", "fish", "salmon", "tuna", "carrot", "potato", "tomato",
            "lettuce", "onion", "garlic", "chocolate", "cake", "cookie", "ice cream",
            "coffee", "tea", "water", "juice", "wine", "beer", "soup", "salad"
        ],
        
        // Colors
        "colors": [
            "red", "blue", "green", "yellow", "orange", "purple", "pink", "brown",
            "black", "white", "gray", "grey", "violet", "indigo", "cyan", "magenta",
            "maroon", "navy", "olive", "lime", "aqua", "silver", "gold", "beige",
            "turquoise", "crimson", "scarlet", "emerald", "amber", "ivory"
        ],
        
        // Sports
        "sports": [
            "football", "basketball", "baseball", "soccer", "tennis", "golf",
            "swimming", "running", "cycling", "boxing", "wrestling", "hockey",
            "volleyball", "badminton", "cricket", "rugby", "skiing", "snowboarding",
            "surfing", "skateboarding", "gymnastics", "track", "field", "marathon",
            "triathlon", "weightlifting", "crossfit", "yoga", "pilates", "dancing"
        ],
        
        // Countries
        "countries": [
            "usa", "canada", "mexico", "brazil", "argentina", "uk", "france",
            "germany", "italy", "spain", "russia", "china", "japan", "korea",
            "india", "australia", "egypt", "nigeria", "kenya", "south africa",
            "norway", "sweden", "denmark", "finland", "netherlands", "belgium",
            "switzerland", "austria", "poland", "czech republic", "hungary"
        ],
        
        // Occupations
        "jobs": [
            "doctor", "nurse", "teacher", "lawyer", "engineer", "programmer",
            "designer", "artist", "musician", "writer", "chef", "waiter", "pilot",
            "driver", "mechanic", "plumber", "electrician", "carpenter", "farmer",
            "scientist", "researcher", "manager", "accountant", "banker", "salesperson",
            "police", "firefighter", "soldier", "judge", "dentist", "veterinarian"
        ],
        
        // Transportation
        "transportation": [
            "car", "bus", "train", "plane", "boat", "ship", "bicycle", "motorcycle",
            "truck", "van", "taxi", "subway", "helicopter", "rocket", "scooter",
            "skateboard", "roller skates", "jet", "yacht", "canoe", "kayak",
            "ferry", "tram", "trolley", "ambulance", "fire truck", "police car"
        ],
        
        // Things in the Kitchen
        "kitchen": [
            "stove", "oven", "refrigerator", "microwave", "dishwasher", "sink",
            "knife", "fork", "spoon", "plate", "bowl", "cup", "glass", "pot",
            "pan", "spatula", "whisk", "blender", "toaster", "kettle", "cutting board",
            "can opener", "bottle opener", "colander", "measuring cup", "timer"
        ],
        
        // School Subjects
        "school subjects": [
            "math", "science", "english", "history", "geography", "art", "music",
            "physical education", "chemistry", "physics", "biology", "literature",
            "algebra", "geometry", "calculus", "economics", "psychology", "sociology",
            "philosophy", "computer science", "foreign language", "drama", "health"
        ],
        
        // Weather
        "weather": [
            "sunny", "cloudy", "rainy", "snowy", "windy", "stormy", "foggy", "humid",
            "hot", "cold", "warm", "cool", "freezing", "thunder", "lightning",
            "hail", "drizzle", "mist", "blizzard", "tornado", "hurricane", "rainbow"
        ]
    ]
    
    // MARK: - Public Interface
    
    /// Validates if an answer fits the given category
    static func validate(answer: String, category: String) -> ValidationResult {
        let normalizedAnswer = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for exact match in database
        if let categoryWords = categoryDatabase[normalizedCategory],
           categoryWords.contains(normalizedAnswer) {
            return ValidationResult(
                isValid: true,
                confidence: 1.0,
                explanation: "Perfect match found in category database",
                source: .database
            )
        }
        
        // Check for fuzzy matches (partial word matching)
        if let categoryWords = categoryDatabase[normalizedCategory] {
            for word in categoryWords {
                if word.contains(normalizedAnswer) || normalizedAnswer.contains(word) {
                    let similarity = calculateSimilarity(word, normalizedAnswer)
                    if similarity > 0.7 {
                        return ValidationResult(
                            isValid: true,
                            confidence: Float(similarity),
                            explanation: "Close match found: '\(word)' is similar to '\(normalizedAnswer)'",
                            source: .fuzzyMatch
                        )
                    }
                }
            }
        }
        
        // Check if it could belong to any category (broader search)
        for (_, words) in categoryDatabase {
            if words.contains(normalizedAnswer) {
                return ValidationResult(
                    isValid: false,
                    confidence: 0.3,
                    explanation: "Word exists but in different category",
                    source: .database
                )
            }
        }
        
        // No match found
        return ValidationResult(
            isValid: false,
            confidence: 0.1,
            explanation: "No match found in category database",
            source: .rejected
        )
    }
    
    /// Get all available categories
    static func getAvailableCategories() -> [String] {
        return Array(categoryDatabase.keys).sorted()
    }
    
    /// Check if a category exists in the database
    static func categoryExists(_ category: String) -> Bool {
        let normalized = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return categoryDatabase[normalized] != nil
    }
    
    /// Get sample words for a category (for hints or examples)
    static func getSampleWords(for category: String, count: Int = 3) -> [String] {
        let normalized = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let words = categoryDatabase[normalized] else { return [] }
        return Array(words.shuffled().prefix(count))
    }
    
    // MARK: - Private Helpers
    
    /// Calculate similarity between two strings using Levenshtein distance
    private static func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        let len1 = s1.count
        let len2 = s2.count
        
        if len1 == 0 { return len2 == 0 ? 1.0 : 0.0 }
        if len2 == 0 { return 0.0 }
        
        let maxLen = max(len1, len2)
        let distance = levenshteinDistance(s1, s2)
        return 1.0 - Double(distance) / Double(maxLen)
    }
    
    /// Calculate Levenshtein distance between two strings
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let len1 = s1Array.count
        let len2 = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 { matrix[i][0] = i }
        for j in 0...len2 { matrix[0][j] = j }
        
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[len1][len2]
    }
}

// MARK: - Extensions

extension CategoryValidationDatabase {
    
    /// Add custom words to a category (for game customization)
    static func addCustomWords(_ words: [String], to category: String) {
        // This would require making categoryDatabase mutable
        // For now, this is a placeholder for future enhancement
        print("Custom words feature not yet implemented: \(words) for \(category)")
    }
    
    /// Get statistics about the database
    static func getDatabaseStats() -> (categories: Int, totalWords: Int) {
        let totalWords = categoryDatabase.values.reduce(0) { $0 + $1.count }
        return (categories: categoryDatabase.count, totalWords: totalWords)
    }
}
