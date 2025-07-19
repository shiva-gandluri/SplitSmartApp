import SwiftUI
import Vision
import UIKit
import NaturalLanguage

// MARK: - Data Models

// MARK: - Error Types
enum OCRError: Error {
    case apiError(String)
    case parseError(String)
    case networkError(String)
}

// MARK: - OCR Models
struct OCRResult {
    let rawText: String
    let parsedItems: [ReceiptItem]
    let confidence: Float
    let processingTime: TimeInterval
}

struct ReceiptItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var price: Double
    var isEditable: Bool = true
    
    init(name: String, price: Double) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.price = price
    }
}

// MARK: - Shared Transaction Models
struct UITransaction: Identifiable {
    let id = UUID()
    let personName: String
    let amount: Double
    let description: String
}

struct UIPersonDebt: Identifiable {
    let id = UUID()
    let name: String
    let total: Double
    let color: Color
}

// MARK: - Assign Screen Models
struct UIParticipant: Identifiable, Hashable {
    let id: Int
    let name: String
    let color: Color
}

struct UIItem: Identifiable {
    let id: Int
    var name: String
    let price: Double
    var assignedTo: Int?
}

// MARK: - Summary Screen Models
struct UISummary {
    let restaurant: String
    let date: String
    let total: Double
    let paidBy: String
    let participants: [UISummaryParticipant]
    let breakdown: [UIBreakdown]
}

struct UISummaryParticipant: Identifiable {
    let id: Int
    let name: String
    let color: Color
    let owes: Double
    let gets: Double
}

struct UIBreakdown: Identifiable {
    let id: Int
    let name: String
    let color: Color
    let items: [UIBreakdownItem]
}

struct UIBreakdownItem {
    let name: String
    let price: Double
}

// MARK: - OCR Service
class OCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Float = 0.0
    @Published var lastResult: OCRResult?
    @Published var errorMessage: String?
    
    func processImage(_ image: UIImage) async -> OCRResult {
        print("🚀 Starting OCR processing...")
        let startTime = Date()
        
        await MainActor.run {
            isProcessing = true
            progress = 0.1
            errorMessage = nil
        }
        
        guard let cgImage = image.cgImage else {
            print("❌ Failed to get CGImage from UIImage")
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to process image"
            }
            return OCRResult(rawText: "", parsedItems: [], confidence: 0.0, processingTime: 0)
        }
        
        print("✅ CGImage created successfully, size: \(cgImage.width)x\(cgImage.height)")
        
        do {
            // Step 1: Extract text using Vision
            print("📖 Step 1: Extracting text using Vision framework...")
            await MainActor.run { progress = 0.3 }
            let extractedText = try await extractText(from: cgImage)
            
            print("📝 Step 1 Complete: Extracted \(extractedText.count) characters")
            
            // Step 2: Parse the extracted text
            print("🔍 Step 2: Parsing extracted text...")
            await MainActor.run { progress = 0.7 }
            let parsedItems = parseReceiptText(extractedText)
            
            print("✅ Step 2 Complete: Found \(parsedItems.count) items")
            
            // Step 3: Calculate confidence and finish
            print("📊 Step 3: Calculating confidence...")
            await MainActor.run { progress = 0.9 }
            let confidence = calculateConfidence(text: extractedText, items: parsedItems)
            let processingTime = Date().timeIntervalSince(startTime)
            
            let result = OCRResult(
                rawText: extractedText,
                parsedItems: parsedItems,
                confidence: confidence,
                processingTime: processingTime
            )
            
            print("🎯 OCR FINAL RESULT:")
            print("   Raw text length: \(extractedText.count)")
            print("   Items found: \(parsedItems.count)")
            for (index, item) in parsedItems.enumerated() {
                print("   Final Item \(index + 1): '\(item.name)' - $\(item.price)")
            }
            let totalValue = parsedItems.reduce(0) { $0 + $1.price }
            print("   Total value of all items: $\(totalValue)")
            print("   Confidence: \(confidence)")
            print("   Processing time: \(processingTime)s")
            
            await MainActor.run {
                self.lastResult = result
                self.progress = 1.0
                self.isProcessing = false
            }
            
            return result
            
        } catch {
            print("❌ OCR processing failed with error: \(error)")
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = "OCR processing failed: \(error.localizedDescription)"
            }
            return OCRResult(rawText: "", parsedItems: [], confidence: 0.0, processingTime: Date().timeIntervalSince(startTime))
        }
    }
    
    private func extractText(from cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                print("🔍 OCR Processing Results:")
                print("📊 Number of text observations: \(observations.count)")
                
                let recognizedText = observations.compactMap { observation in
                    let topCandidate = observation.topCandidates(3).first?.string
                    if let text = topCandidate {
                        print("📝 Detected text: '\(text)' (confidence: \(observation.confidence))")
                    }
                    return topCandidate
                }.joined(separator: "\n")
                
                print("🔍 OCR Raw Text Output:")
                print("======================")
                print(recognizedText.isEmpty ? "⚠️ NO TEXT DETECTED" : recognizedText)
                print("======================")
                print("📏 Total text length: \(recognizedText.count) characters")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US", "en"]
            request.minimumTextHeight = 0.01
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseReceiptText(_ text: String) -> [ReceiptItem] {
        print("🔍 OCR Raw Text Length: \(text.count) characters")
        print("🔍 Using Google Gemini 2.0 Flash for receipt parsing...")
        
        // Use Google Gemini 2.0 Flash for intelligent parsing
        return parseReceiptWithLLM(text)
    }
    
    private func parseReceiptWithLLM(_ text: String) -> [ReceiptItem] {
        let prompt = """
        You are analyzing text from a restaurant receipt. Extract ONLY the food/drink items and their prices.
        
        Instructions:
        1. Identify food and beverage items with their prices
        2. Ignore header information (restaurant name, address, date, server info)
        3. Ignore footer information (payment method, card numbers, signatures)
        4. Ignore tax, tip, subtotal, and total lines
        5. Return ONLY items that customers would actually order
        6. Look for items where the name and price might be on separate lines
        
        Receipt text:
        \(text)
        
        Format your response as a valid JSON array like this:
        [
          {"name": "Item Name", "price": 12.50},
          {"name": "Another Item", "price": 8.99}
        ]
        
        If no food items can be identified, return an empty array: []
        
        IMPORTANT: Return ONLY the JSON array, no other text.
        """
        
        // Use Google Gemini 2.0 Flash API for actual LLM processing
        return parseWithGemini(prompt: prompt, originalText: text)
    }
    
    private func parseWithGemini(prompt: String, originalText: String) -> [ReceiptItem] {
        print("🤖 Using Google Gemini 2.0 Flash API for receipt parsing...")
        
        // Use async/await for the API call
        let semaphore = DispatchSemaphore(value: 0)
        var result: [ReceiptItem] = []
        
        Task {
            do {
                result = try await callGemini(prompt: prompt)
                if result.isEmpty {
                    print("⚠️ Gemini returned empty results, using fallback...")
                    result = createSimpleFallback(originalText)
                }
            } catch {
                print("❌ Gemini API error: \(error)")
                result = createSimpleFallback(originalText)
            }
            semaphore.signal()
        }
        
        // Wait for the async call to complete (with timeout)
        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("⏰ Gemini API timeout")
            return []
        }
        
        return result
    }
    
    private func callGemini(prompt: String) async throws -> [ReceiptItem] {
        // Google Gemini API configuration
        guard let apiKey = getGeminiAPIKey() else {
            throw OCRError.apiError("Google Gemini API key not configured")
        }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-001:generateContent")!
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Request body for Gemini API
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 1000,
                "responseMimeType": "text/plain"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OCRError.apiError("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        // Parse Gemini response
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonResponse["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw OCRError.parseError("Invalid Gemini API response format")
        }
        
        print("🤖 Gemini Response: \(text)")
        
        // Parse the JSON array from LLM response
        return try parseItemsFromJSON(text)
    }
    
    private func parseItemsFromJSON(_ jsonString: String) throws -> [ReceiptItem] {
        let cleanedJSON = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw OCRError.parseError("Invalid JSON string")
        }
        
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw OCRError.parseError("JSON is not an array")
        }
        
        var items: [ReceiptItem] = []
        
        for itemDict in jsonArray {
            guard let name = itemDict["name"] as? String,
                  let price = itemDict["price"] as? Double else {
                print("⚠️ Skipping invalid item: \(itemDict)")
                continue
            }
            
            if price > 0 && price < 1000 && !name.isEmpty {
                let item = ReceiptItem(name: name, price: price)
                items.append(item)
                print("✅ Parsed LLM item: \(item.name) - $\(item.price)")
            }
        }
        
        return items
    }
    
    private func getGeminiAPIKey() -> String? {
        // Priority 1: Check environment variable (most secure for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !envKey.isEmpty && envKey != "YOUR_GEMINI_API_KEY" {
            return envKey
        }
        
        // Priority 2: Check secure APIKeys.plist (local development)
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["GEMINI_API_KEY"] as? String,
           !apiKey.isEmpty && apiKey != "YOUR_GEMINI_API_KEY_HERE" {
            return apiKey
        }
        
        // Priority 3: Check Info.plist (fallback - not recommended for production)
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["GEMINI_API_KEY"] as? String,
           !apiKey.isEmpty && apiKey != "YOUR_GEMINI_API_KEY" {
            print("⚠️ Warning: API key found in Info.plist. Consider moving to APIKeys.plist for better security.")
            return apiKey
        }
        
        print("❌ Gemini API key not configured. Please:")
        print("   1. Add GEMINI_API_KEY to your environment variables, OR")
        print("   2. Create APIKeys.plist with your key, OR") 
        print("   3. Add key to Info.plist (not recommended for production)")
        
        return nil
    }
    
    // Simple fallback if LLM fails - creates single item from receipt
    private func createSimpleFallback(_ text: String) -> [ReceiptItem] {
        print("⚠️ LLM failed, creating simple fallback item...")
        
        // Find any reasonable total amount in the text
        let numberPattern = #"(\d{2,3}\.\d{2})"#
        let regex = try? NSRegularExpression(pattern: numberPattern, options: [])
        var amounts: [Double] = []
        
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range])
                if let amount = Double(amountStr), amount >= 10.0 && amount <= 999.0 {
                    amounts.append(amount)
                }
            }
        }
        
        // Use the highest reasonable amount
        if let maxAmount = amounts.max() {
            let item = ReceiptItem(name: "Restaurant Order", price: maxAmount)
            print("✅ Created fallback item: \(item.name) - $\(item.price)")
            return [item]
        }
        
        return []
    }
    
    private func isHeaderOrFooterLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let headerFooterKeywords = [
            "guest", "check", "table", "server", "receipt", "welcome", "thank",
            "address", "phone", "www", ".com", "card", "signature", "approved",
            "transaction", "account", "income", "tax", "total", "subtotal",
            "angeles", "blvd", "7733"
        ]
        
        return headerFooterKeywords.contains { lowercased.contains($0) }
    }
    
    private func extractFoodItem(from line: String) -> ReceiptItem? {
        // Simple but effective patterns for food items
        let patterns = [
            #"^(.+?)\s+(\d+\.?\d*)-?$"#,  // "Item name 12-" or "Item name 12.50"
            #"^(.+?)\s+\$(\d+\.?\d*)$"#,   // "Item name $12.50"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                
                let nameRange = Range(match.range(at: 1), in: line)
                let priceRange = Range(match.range(at: 2), in: line)
                
                if let nameRange = nameRange, let priceRange = priceRange {
                    let itemName = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let priceString = String(line[priceRange])
                    
                    if let price = Double(priceString),
                       price >= 1.0 && price <= 100.0,
                       itemName.count >= 3 && itemName.count <= 50,
                       !isHeaderOrFooterLine(itemName) {
                        
                        return ReceiptItem(name: itemName, price: price)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func createFallbackItem(from text: String) -> [ReceiptItem] {
        print("🍽️ Creating fallback item from receipt total...")
        
        // Find the highest reasonable number in the receipt
        let numberPattern = #"(\d+\.?\d*)"#
        let regex = try? NSRegularExpression(pattern: numberPattern, options: [])
        var amounts: [Double] = []
        
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range])
                if let amount = Double(amountStr), amount >= 10.0 && amount <= 999.0 {
                    amounts.append(amount)
                }
            }
        }
        
        // Use the highest amount as the total
        if let maxAmount = amounts.max() {
            let restaurantName = extractRestaurantName(from: text)
            let item = ReceiptItem(name: restaurantName, price: maxAmount)
            print("✅ Created fallback item: \(item.name) - $\(item.price)")
            return [item]
        }
        
        return []
    }
    
    private func extractRestaurantName(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        
        // Look for restaurant indicators
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().contains("restaurant") || 
               trimmed.lowercased().contains("eats") ||
               trimmed.lowercased().contains("cafe") {
                return trimmed
            }
        }
        
        // Use first non-empty line as restaurant name
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count > 3 {
                return trimmed
            }
        }
        
        return "Restaurant Order"
    }
    
    private func isPotentialFoodName(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have some letters
        guard trimmed.rangeOfCharacter(from: .letters) != nil else { return false }
        
        // Reasonable length
        guard trimmed.count >= 3 && trimmed.count <= 50 else { return false }
        
        // Skip if it's obviously not food
        if isHeaderOrFooterLine(trimmed) { return false }
        
        // Skip pure price lines
        if extractPriceOnly(from: trimmed) != nil { return false }
        
        // Skip lines with only numbers/symbols
        let hasEnoughLetters = trimmed.filter { $0.isLetter }.count >= 2
        guard hasEnoughLetters else { return false }
        
        print("  🍽️ Potential food name: '\(trimmed)'")
        return true
    }
    
    private func extractPriceOnly(from line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Patterns for standalone prices
        let pricePatterns = [
            #"^(\d{1,2})-$"#,              // "14-"
            #"^(\d{1,2}\.\d{2})$"#,        // "12.50"
            #"^\$(\d{1,2}\.\d{2})$"#,      // "$12.50"
            #"^(\d{1,2})$"#,               // "12"
            #"^(\d{1,2})\s*-\s*$"#         // "3 -"
        ]
        
        for pattern in pricePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)) {
                
                let priceRange = Range(match.range(at: 1), in: trimmed)
                if let priceRange = priceRange {
                    let priceString = String(trimmed[priceRange])
                    if let price = Double(priceString), price >= 1.0 && price <= 99.0 {
                        print("  💰 Extracted standalone price: $\(price) from '\(trimmed)'")
                        return price
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractItemAndPrice(from line: String) -> ReceiptItem? {
        print("  🔍 Processing line: '\(line)'")
        
        // Skip obvious header/footer lines but be less restrictive
        let lowercaseLine = line.lowercased()
        let skipKeywords = ["receipt #", "transaction #", "card #", "www.", ".com", "thank you", "cashier:", "server:"]
        
        for keyword in skipKeywords {
            if lowercaseLine.contains(keyword) {
                print("  ⏭️ Skipping line - contains keyword: '\(keyword)'")
                return nil
            }
        }
        
        // More flexible patterns - looking for any text followed by a price
        let patterns = [
            // Standard format: item name + price with $
            #"(.+?)\s+\$(\d+\.?\d*)$"#,
            // Standard format: item name + price without $
            #"(.+?)\s+(\d+\.\d{1,2})$"#,
            // Quantity format: 1x item + price
            #"(\d+x?\s+.+?)\s+\$?(\d+\.?\d*)$"#,
            // Flexible: any text with price at end
            #"(.+?)\s+(\d+\.?\d*)\s*$"#,
            // Price anywhere in line
            #"(.+?)\s+.*?(\d+\.\d{1,2}).*$"#,
            // Simple: word(s) followed by number
            #"([a-zA-Z][a-zA-Z\s]+?)\s+(\d+\.?\d*)$"#,
            // Very loose: any text + any decimal number
            #"(.+?)\s+(\d*\.?\d+).*$"#
        ]
        
        print("  🔍 Trying \(patterns.count) patterns...")
        
        for (patternIndex, pattern) in patterns.enumerated() {
            print("    Pattern \(patternIndex + 1): \(pattern)")
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                
                let nameRange = Range(match.range(at: 1), in: line)
                let priceRange = Range(match.range(at: 2), in: line)
                
                if let nameRange = nameRange, let priceRange = priceRange {
                    let itemName = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let priceString = String(line[priceRange])
                    
                    print("    ✅ Pattern \(patternIndex + 1) MATCHED - Name: '\(itemName)', Price: '\(priceString)'")
                    
                    // More lenient price validation - increased upper limit
                    if let price = Double(priceString), price > 0.01 && price < 9999.99 {
                        let cleanName = cleanItemName(itemName)
                        // More lenient name validation
                        if !cleanName.isEmpty && cleanName.count >= 1 && !isOnlyNumbers(cleanName) {
                            print("    ✅ Valid item created: '\(cleanName)' - $\(price)")
                            return ReceiptItem(name: cleanName, price: price)
                        } else {
                            print("    ❌ Item name invalid: '\(cleanName)' (empty: \(cleanName.isEmpty), length: \(cleanName.count), onlyNumbers: \(isOnlyNumbers(cleanName)))")
                        }
                    } else {
                        let parsedPrice = Double(priceString) ?? -1
                        print("    ❌ Price invalid: '\(priceString)' -> \(parsedPrice) (must be between 0.01 and 9999.99)")
                    }
                } else {
                    print("    ❌ Pattern matched but couldn't extract name/price ranges")
                }
            } else {
                print("    ❌ Pattern \(patternIndex + 1) no match")
            }
        }
        
        print("  ❌ No valid item found for line: '\(line)'")
        return nil
    }
    
    private func isOnlyNumbers(_ text: String) -> Bool {
        return text.trimmingCharacters(in: .decimalDigits).isEmpty
    }
    
    private func extractJustPrice(from line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern for just a price like "14-", "$12.50", "8.93" - but NOT large numbers
        let pricePatterns = [
            #"^(\d{1,2})-$"#,           // "14-" (1-2 digits only)
            #"^\$?(\d{1,2}\.\d{2})$"#,  // "$12.50" or "12.50" (reasonable food prices)
            #"^\$?(\d{1,2})$"#,         // "$12" or "12" (1-2 digits only)
        ]
        
        for pattern in pricePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)) {
                
                let priceRange = Range(match.range(at: 1), in: trimmed)
                if let priceRange = priceRange {
                    let priceString = String(trimmed[priceRange])
                    if let price = Double(priceString), price >= 1.0 && price <= 50.0 {
                        print("  💰 Extracted valid food price: $\(price) from '\(trimmed)'")
                        return price
                    }
                }
            }
        }
        
        return nil
    }
    
    private func isPurePrice(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if line contains ONLY a price pattern - no other text
        let pricePatternsOnly = [
            #"^(\d{1,2})-$"#,           // "14-"
            #"^\$?(\d{1,2}\.\d{2})$"#,  // "$12.50" or "12.50"
            #"^\$?(\d{1,2})$"#,         // "$12" or "12"
        ]
        
        for pattern in pricePatternsOnly {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func isValidFoodName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        // Must have letters
        guard trimmed.rangeOfCharacter(from: .letters) != nil else { 
            print("  ❌ Food name validation failed: no letters in '\(trimmed)'")
            return false 
        }
        
        // Must be reasonable length for food items
        guard trimmed.count >= 3 && trimmed.count <= 30 else { 
            print("  ❌ Food name validation failed: bad length (\(trimmed.count)) for '\(trimmed)'")
            return false 
        }
        
        // Skip obvious non-food lines (expanded list)
        let skipKeywords = [
            "guest", "table", "server", "receipt", "tax", "total", "subtotal", 
            "check", "guests", "seaver", "income", "expense", "account", "as",
            "blvd", "angeles", "phone", "7733", "approved", "purchase"
        ]
        
        for keyword in skipKeywords {
            if lowercased.contains(keyword) {
                print("  ❌ Food name validation failed: contains '\(keyword)' in '\(trimmed)'")
                return false
            }
        }
        
        // Skip pure numbers or codes
        if trimmed.range(of: #"^\d+$"#, options: .regularExpression) != nil || 
           trimmed.range(of: #"^\d+-\d+$"#, options: .regularExpression) != nil {
            print("  ❌ Food name validation failed: looks like code '\(trimmed)'")
            return false
        }
        
        // Skip lines that are mostly non-Latin characters (like Cyrillic)
        let latinCharacters = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"))
        if latinCharacters == nil && !lowercased.contains("coke") {
            print("  ❌ Food name validation failed: no Latin characters in '\(trimmed)'")
            return false
        }
        
        print("  ✅ Food name validation passed: '\(trimmed)'")
        return true
    }
    
    private func cleanItemName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common quantity prefixes
        let quantityPrefixes = ["1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x", "9x", "*"]
        for prefix in quantityPrefixes {
            if cleaned.lowercased().hasPrefix(prefix.lowercased() + " ") {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Remove common unit suffixes
        let unitSuffixes = [" EA", " LB", " OZ", " CT", " PC", " PCS"]
        for suffix in unitSuffixes {
            if cleaned.uppercased().hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        return cleaned
    }
    
    private func calculateConfidence(text: String, items: [ReceiptItem]) -> Float {
        if text.isEmpty {
            return 0.0
        }
        
        let textLength = Float(text.count)
        let itemCount = Float(items.count)
        
        var confidence: Float = min(textLength / 100.0, 1.0)
        confidence = confidence * 0.7 + (itemCount > 0 ? 0.3 : 0.0)
        
        return min(max(confidence, 0.0), 1.0)
    }
    
    // Debug method to test parsing with known text
    func testParsing() -> OCRResult {
        print("🧪 Testing OCR parsing with known text...")
        
        let testText = """
        McDonald's Receipt
        Big Mac        12.99
        French Fries   4.50
        Coke          2.75
        Total         20.24
        """
        
        let items = parseReceiptText(testText)
        let confidence = calculateConfidence(text: testText, items: items)
        
        return OCRResult(
            rawText: testText,
            parsedItems: items,
            confidence: confidence,
            processingTime: 0.1
        )
    }
}