import Foundation

// MARK: - Currency Utilities
extension Double {
    /// Rounds a currency value to 2 decimal places with proper rounding
    var currencyRounded: Double {
        return (self * 100).rounded() / 100
    }
    
    /// Safely adds two currency values with proper rounding
    func currencyAdd(_ other: Double) -> Double {
        return (self + other).currencyRounded
    }
    
    /// Safely divides currency value by count with proper rounding
    func currencyDivide(by count: Int) -> Double {
        guard count > 0 else { return 0.0 }
        return (self / Double(count)).currencyRounded
    }
    
    /// Smart distribution of currency among participants ensuring total matches exactly
    /// Example: $8.99 / 2 = [$4.49, $4.50] instead of [$4.495, $4.495]
    static func smartDistribute(total: Double, among count: Int) -> [Double] {
        guard count > 0 else { return [] }
        
        let baseAmount = (total / Double(count)).currencyRounded
        let totalBasic = baseAmount * Double(count)
        let remainder = (total - totalBasic).currencyRounded
        
        var distribution = Array(repeating: baseAmount, count: count)
        
        // Distribute remainder cents to first participants
        let remainderCents = Int((remainder * 100).rounded())
        for i in 0..<min(abs(remainderCents), count) {
            distribution[i] = distribution[i].currencyAdd(remainderCents > 0 ? 0.01 : -0.01)
        }
        
        return distribution
    }
}