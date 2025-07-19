import SwiftUI
import Vision
import UIKit

// MARK: - Data Models

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
        let startTime = Date()
        
        await MainActor.run {
            isProcessing = true
            progress = 0.1
            errorMessage = nil
        }
        
        guard let cgImage = image.cgImage else {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to process image"
            }
            return OCRResult(rawText: "", parsedItems: [], confidence: 0.0, processingTime: 0)
        }
        
        do {
            // Step 1: Extract text using Vision
            await MainActor.run { progress = 0.3 }
            let extractedText = try await extractText(from: cgImage)
            
            // Step 2: Parse the extracted text
            await MainActor.run { progress = 0.7 }
            let parsedItems = parseReceiptText(extractedText)
            
            // Step 3: Calculate confidence and finish
            await MainActor.run { progress = 0.9 }
            let confidence = calculateConfidence(text: extractedText, items: parsedItems)
            let processingTime = Date().timeIntervalSince(startTime)
            
            let result = OCRResult(
                rawText: extractedText,
                parsedItems: parsedItems,
                confidence: confidence,
                processingTime: processingTime
            )
            
            await MainActor.run {
                self.lastResult = result
                self.progress = 1.0
                self.isProcessing = false
            }
            
            return result
            
        } catch {
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
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseReceiptText(_ text: String) -> [ReceiptItem] {
        let lines = text.components(separatedBy: .newlines)
        var items: [ReceiptItem] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty || 
               isHeaderLine(trimmedLine) || 
               isTotalLine(trimmedLine) ||
               isDateTimeLine(trimmedLine) ||
               isAddressLine(trimmedLine) {
                continue
            }
            
            if let item = extractItemAndPrice(from: trimmedLine) {
                items.append(item)
            }
        }
        
        return items
    }
    
    private func extractItemAndPrice(from line: String) -> ReceiptItem? {
        let patterns = [
            #"^(.+?)\s+\$(\d+\.\d{2})$"#,
            #"^(.+?)\s+(\d+\.\d{2})$"#,
            #"^(\d+x?\s+.+?)\s+\$?(\d+\.\d{2})$"#,
            #"^(.+?)\s+.*?(\d+\.\d{2})\s*$"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                
                let nameRange = Range(match.range(at: 1), in: line)
                let priceRange = Range(match.range(at: 2), in: line)
                
                if let nameRange = nameRange, let priceRange = priceRange {
                    let itemName = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let priceString = String(line[priceRange])
                    
                    if let price = Double(priceString), price > 0 && price < 1000 {
                        let cleanName = cleanItemName(itemName)
                        if !cleanName.isEmpty && cleanName.count > 2 {
                            return ReceiptItem(name: cleanName, price: price)
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func cleanItemName(_ name: String) -> String {
        var cleaned = name
        
        let prefixesToRemove = ["1x", "2x", "3x", "4x", "5x", "*"]
        let suffixesToRemove = ["EA", "LB", "OZ", "CT"]
        
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        for suffix in suffixesToRemove {
            if cleaned.lowercased().hasSuffix(suffix.lowercased()) {
                cleaned = String(cleaned.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return cleaned
    }
    
    private func isHeaderLine(_ line: String) -> Bool {
        let headerKeywords = ["receipt", "invoice", "bill", "store", "market", "restaurant", "cafe", "thank you", "welcome", "phone", "address"]
        let lowercaseLine = line.lowercased()
        return headerKeywords.contains { lowercaseLine.contains($0) }
    }
    
    private func isTotalLine(_ line: String) -> Bool {
        let totalKeywords = ["total", "subtotal", "tax", "tip", "gratuity", "change", "amount due", "balance"]
        let lowercaseLine = line.lowercased()
        return totalKeywords.contains { lowercaseLine.contains($0) }
    }
    
    private func isDateTimeLine(_ line: String) -> Bool {
        let dateTimePattern = #"\d{1,2}[/\-:]\d{1,2}[/\-:]\d{2,4}|\d{1,2}:\d{2}|\d{1,2}\s+(AM|PM)"#
        return line.range(of: dateTimePattern, options: .regularExpression) != nil
    }
    
    private func isAddressLine(_ line: String) -> Bool {
        let addressKeywords = ["street", "st", "avenue", "ave", "road", "rd", "drive", "dr", "blvd", "boulevard"]
        let lowercaseLine = line.lowercased()
        return addressKeywords.contains { lowercaseLine.contains($0) }
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
}