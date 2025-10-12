//
//  Font+Extensions.swift
//  SplitSmart Design System
//
//  Typography scale with Dynamic Type support
//  Based on 4px/8px grid system for consistent hierarchy
//

import SwiftUI

extension Font {
    // MARK: - Type Scale
    // Consistent font hierarchy based on relative em units
    // Scales proportionally with system text size settings

    /// Heading 1 - 40pt (2.5em)
    /// Use for: Screen titles, main headings
    static let h1 = Font.system(size: 40, weight: .bold, design: .default)

    /// Heading 2 - 32pt (2em)
    /// Use for: Section titles, important headings
    static let h2 = Font.system(size: 32, weight: .bold, design: .default)

    /// Heading 3 - 24pt (1.5em)
    /// Use for: Subsection titles, card headers
    static let h3 = Font.system(size: 24, weight: .semibold, design: .default)

    /// Heading 4 - 20pt (1.25em)
    /// Use for: Minor headings, label groups
    static let h4 = Font.system(size: 20, weight: .semibold, design: .default)

    /// Body - 16pt (1em) - Base size
    /// Use for: Main content, default text
    static let bodyText = Font.system(size: 16, weight: .regular, design: .default)

    /// Small - 14pt (0.875em)
    /// Use for: Secondary content, metadata
    static let smallText = Font.system(size: 14, weight: .regular, design: .default)

    /// Caption - 12pt (0.75em)
    /// Use for: Fine print, timestamps, captions
    static let captionText = Font.system(size: 12, weight: .regular, design: .default)

    // MARK: - Dynamic Type Support
    // iOS accessibility feature for user-controlled text sizing

    /// Heading 1 with Dynamic Type scaling
    /// Automatically adjusts to user's preferred text size
    static let h1Dynamic = Font.system(.largeTitle, design: .default).weight(.bold)

    /// Heading 2 with Dynamic Type scaling
    static let h2Dynamic = Font.system(.title, design: .default).weight(.bold)

    /// Heading 3 with Dynamic Type scaling
    static let h3Dynamic = Font.system(.title2, design: .default).weight(.semibold)

    /// Heading 4 with Dynamic Type scaling
    static let h4Dynamic = Font.system(.title3, design: .default).weight(.semibold)

    /// Body with Dynamic Type scaling (Default)
    static let bodyDynamic = Font.system(.body, design: .default)

    /// Small with Dynamic Type scaling
    static let smallDynamic = Font.system(.callout, design: .default)

    /// Caption with Dynamic Type scaling
    static let captionDynamic = Font.system(.caption, design: .default)

    // MARK: - Semantic Font Styles
    // Context-specific font usage for common UI patterns

    /// Button text style - Medium weight, body size
    static let buttonText = Font.system(size: 16, weight: .medium, design: .default)

    /// Input label style - Medium weight, small size
    static let inputLabel = Font.system(size: 14, weight: .medium, design: .default)

    /// Navigation title style - Bold, large
    static let navTitle = Font.system(size: 34, weight: .bold, design: .default)

    /// Tab bar item style - Regular, caption size
    static let tabItem = Font.system(size: 10, weight: .regular, design: .default)
}

// MARK: - Text Modifier Extensions
// Convenient text styling modifiers

extension Text {
    /// Apply heading 1 style with primary text color
    func heading1() -> some View {
        self
            .font(.h1Dynamic)
            .foregroundColor(.adaptiveTextPrimary)
    }

    /// Apply heading 2 style with primary text color
    func heading2() -> some View {
        self
            .font(.h2Dynamic)
            .foregroundColor(.adaptiveTextPrimary)
    }

    /// Apply heading 3 style with primary text color
    func heading3() -> some View {
        self
            .font(.h3Dynamic)
            .foregroundColor(.adaptiveTextPrimary)
    }

    /// Apply heading 4 style with primary text color
    func heading4() -> some View {
        self
            .font(.h4Dynamic)
            .foregroundColor(.adaptiveTextPrimary)
    }

    /// Apply body style with primary text color
    func bodyStyle() -> some View {
        self
            .font(.bodyDynamic)
            .foregroundColor(.adaptiveTextPrimary)
    }

    /// Apply small style with secondary text color
    func smallStyle() -> some View {
        self
            .font(.smallDynamic)
            .foregroundColor(.adaptiveTextSecondary)
    }

    /// Apply caption style with tertiary text color
    func captionStyle() -> some View {
        self
            .font(.captionDynamic)
            .foregroundColor(.adaptiveTextTertiary)
    }
}

// MARK: - Usage Examples
/*

 Basic Typography:
 ```
 Text("Welcome to SplitSmart")
     .font(.h1Dynamic)
     .foregroundColor(.adaptiveTextPrimary)
 ```

 Semantic Modifiers:
 ```
 Text("Welcome to SplitSmart")
     .heading1()

 Text("Bill splitting made easy")
     .bodyStyle()

 Text("Last updated: 2 minutes ago")
     .captionStyle()
 ```

 Mixed Hierarchy:
 ```
 VStack(alignment: .leading, spacing: .spacingMD) {
     Text("Payment Summary")
         .heading2()

     Text("Total amount to be split")
         .bodyStyle()

     Text("Updated today")
         .captionStyle()
 }
 ```

 Dynamic Type Support:
 ```
 // Automatically scales with user's text size preference
 Text("Accessible Text")
     .font(.bodyDynamic)

 // Fixed size (use sparingly, not accessible)
 Text("Fixed Size")
     .font(.bodyText)
 ```

 Navigation and Buttons:
 ```
 Text("Confirm")
     .font(.buttonText)

 Text("Email Address")
     .font(.inputLabel)
 ```

 */
