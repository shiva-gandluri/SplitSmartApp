//
//  Color+Extensions.swift
//  SplitSmart Design System
//
//  OKLCH-based color system with depth levels and text hierarchy
//  Following modern UI design principles for perceptually uniform colors
//

import SwiftUI

extension Color {
    // MARK: - OKLCH Color System
    // Adaptive colors that automatically switch between light and dark mode
    // Based on perceptually uniform OKLCH color space principles

    // MARK: - Adaptive Colors (Light/Dark Mode)
    // These automatically switch based on system appearance
    // Uses environment-aware color selection for light/dark mode support

    /// Adaptive depth 0 - Base background that responds to color scheme
    static var adaptiveDepth0: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)  // Dark: RGB(26,26,26)
                : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)        // Light: RGB(255,255,255) WHITE
        })
    }

    /// Adaptive depth 1 - Raised containers
    static var adaptiveDepth1: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.149, green: 0.149, blue: 0.149, alpha: 1.0)  // Dark: RGB(38,38,38)
                : UIColor(red: 0.969, green: 0.969, blue: 0.969, alpha: 1.0)  // Light: RGB(247,247,247) Very light gray
        })
    }

    /// Adaptive depth 2 - Card surfaces
    static var adaptiveDepth2: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.200, green: 0.200, blue: 0.200, alpha: 1.0)  // Dark: RGB(51,51,51)
                : UIColor(red: 0.941, green: 0.941, blue: 0.941, alpha: 1.0)  // Light: RGB(240,240,240) Light gray
        })
    }

    /// Adaptive depth 3 - Elevated elements
    static var adaptiveDepth3: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.251, green: 0.251, blue: 0.251, alpha: 1.0)  // Dark: RGB(64,64,64)
                : UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1.0)  // Light: RGB(229,229,229) Medium-light gray
        })
    }

    /// Adaptive primary text color
    static var adaptiveTextPrimary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.902, green: 0.902, blue: 0.902, alpha: 1.0)  // Dark: RGB(230,230,230) Light gray text
                : UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)  // Light: RGB(26,26,26) Dark gray text
        })
    }

    /// Adaptive secondary text color
    static var adaptiveTextSecondary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.702, green: 0.702, blue: 0.702, alpha: 1.0)  // Dark: RGB(179,179,179) Medium gray
                : UIColor(red: 0.400, green: 0.400, blue: 0.400, alpha: 1.0)  // Light: RGB(102,102,102) Darker gray for contrast
        })
    }

    /// Adaptive tertiary text color
    static var adaptiveTextTertiary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.502, green: 0.502, blue: 0.502, alpha: 1.0)  // Dark: RGB(128,128,128) Dimmer gray
                : UIColor(red: 0.600, green: 0.600, blue: 0.600, alpha: 1.0)  // Light: RGB(153,153,153) Medium gray
        })
    }

    // MARK: - Adaptive Accent Colors

    /// Adaptive blue accent - for interactive elements, primary actions
    static var adaptiveAccentBlue: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.251, green: 0.604, blue: 1.0, alpha: 1.0)    // Dark: Lighter blue for contrast
                : UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)      // Light: Standard iOS blue
        })
    }

    /// Adaptive red accent - for errors, destructive actions
    static var adaptiveAccentRed: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1.0)    // Dark: Lighter red for visibility
                : UIColor(red: 0.878, green: 0.106, blue: 0.141, alpha: 1.0)  // Light: Standard red
        })
    }

    /// Adaptive green accent - for success, positive states
    static var adaptiveAccentGreen: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.188, green: 0.82, blue: 0.345, alpha: 1.0)   // Dark: Lighter green for visibility
                : UIColor(red: 0.0, green: 0.706, blue: 0.196, alpha: 1.0)    // Light: Standard green
        })
    }

    /// Adaptive orange accent - for warnings, pending states
    static var adaptiveAccentOrange: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0)    // Dark: Lighter orange
                : UIColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)      // Light: Standard orange
        })
    }

    /// Muted green - softer, less bright for balance displays
    static var adaptiveMutedGreen: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.65, blue: 0.28, alpha: 1.0)     // Dark: Muted green
                : UIColor(red: 0.0, green: 0.55, blue: 0.15, alpha: 1.0)      // Light: Softer green
        })
    }

    /// Muted red - softer, less bright for balance displays
    static var adaptiveMutedRed: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.85, green: 0.22, blue: 0.19, alpha: 1.0)     // Dark: Muted red
                : UIColor(red: 0.70, green: 0.08, blue: 0.11, alpha: 1.0)     // Light: Softer red
        })
    }
}

// MARK: - Usage Examples
/*

 Basic Usage:
 ```
 Text("Hello World")
     .foregroundColor(.adaptiveTextPrimary)
     .background(Color.adaptiveDepth0)
 ```

 Card with Depth:
 ```
 VStack {
     Text("Card Content")
 }
 .padding()
 .background(Color.adaptiveDepth2)
 .cornerRadius(12)
 ```

 Text Hierarchy:
 ```
 VStack(alignment: .leading) {
     Text("Heading")
         .foregroundColor(.adaptiveTextPrimary)
     Text("Body text")
         .foregroundColor(.adaptiveTextSecondary)
     Text("Caption")
         .foregroundColor(.adaptiveTextTertiary)
 }
 ```

 */
