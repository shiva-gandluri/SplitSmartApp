//
//  ButtonStyles.swift
//  SplitSmart Design System
//
//  Reusable button styles with consistent design system integration
//  Includes Primary, Secondary, and Tertiary button styles
//

import SwiftUI

// MARK: - Primary Button Style
/// Primary action button with accent color background
/// Use for: Main CTAs, important actions, form submissions
/// Standard usage: Apply .frame(maxWidth: .infinity) for full-width buttons
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.adaptiveAccentBlue)
            .cornerRadius(.cornerRadiusButton)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(reduceMotion ? .none : .buttonPress, value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Disabled Primary Button Style
/// Disabled state for primary button - gray color with same config
/// Use for: Disabled primary actions
struct DisabledPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(red: 0.5, green: 0.5, blue: 0.5))
            .cornerRadius(.cornerRadiusButton)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(reduceMotion ? .none : .buttonPress, value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Secondary Button Style
/// Secondary action button with outlined style
/// Use for: Secondary actions, cancel buttons, alternative choices
/// Same size, shape, style as Primary - only color differs
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.adaptiveAccentBlue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.adaptiveAccentBlue.opacity(0.1))
            .cornerRadius(.cornerRadiusButton)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(reduceMotion ? .none : .buttonPress, value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Tertiary Button Style
/// Text-only button with subtle hover effect
/// Use for: Tertiary actions, links, inline actions
struct TertiaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyText)
            .foregroundColor(.adaptiveAccentBlue)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                configuration.isPressed ?
                Color.adaptiveAccentBlue.opacity(0.1) :
                Color.clear
            )
            .cornerRadius(.cornerRadiusButton)
            .animation(reduceMotion ? .none : .smoothEaseOut, value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Destructive Button Style
/// Destructive action button with red accent
/// Use for: Delete actions, destructive confirmations
/// Standard usage: Apply .frame(maxWidth: .infinity) for full-width buttons
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.adaptiveAccentRed)
            .cornerRadius(.cornerRadiusButton)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(reduceMotion ? .none : .buttonPress, value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview Provider
struct ButtonStyles_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: .spacingLG) {
            // Primary Button
            Button("Primary Action") {
                print("Primary tapped")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Primary action button")
            .accessibilityHint("Performs the main action")

            // Secondary Button
            Button("Secondary Action") {
                print("Secondary tapped")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Secondary action button")
            .accessibilityHint("Performs an alternative action")

            // Tertiary Button
            Button("Tertiary Action") {
                print("Tertiary tapped")
            }
            .buttonStyle(TertiaryButtonStyle())
            .accessibilityLabel("Tertiary action button")
            .accessibilityHint("Shows additional information")

            // Destructive Button
            Button("Delete Action") {
                print("Delete tapped")
            }
            .buttonStyle(DestructiveButtonStyle())
            .accessibilityLabel("Delete action button")
            .accessibilityHint("Permanently deletes this item")

            // Full Width Example
            Button("Full Width Primary") {
                print("Full width tapped")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Full width primary button")
        }
        .padding(.paddingScreen)
        .background(Color.adaptiveDepth0)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Button Styles")
    }
}

// MARK: - Usage Examples
/*

 Primary Button:
 ```
 Button("Submit") {
     submitForm()
 }
 .buttonStyle(PrimaryButtonStyle())
 .accessibilityLabel("Submit form")
 .accessibilityHint("Submits the current form data")
 ```

 Secondary Button:
 ```
 Button("Cancel") {
     dismissView()
 }
 .buttonStyle(SecondaryButtonStyle())
 .accessibilityLabel("Cancel action")
 .accessibilityHint("Cancels and returns to previous screen")
 ```

 Tertiary Button:
 ```
 Button("Learn More") {
     showInfo()
 }
 .buttonStyle(TertiaryButtonStyle())
 .accessibilityLabel("Learn more")
 .accessibilityHint("Opens additional information")
 ```

 Destructive Button:
 ```
 Button("Delete Bill") {
     deleteBill()
 }
 .buttonStyle(DestructiveButtonStyle())
 .accessibilityLabel("Delete bill")
 .accessibilityHint("Permanently deletes this bill. This action cannot be undone")
 ```

 Full Width Button:
 ```
 Button("Confirm Payment") {
     confirmPayment()
 }
 .buttonStyle(PrimaryButtonStyle())
 .frame(maxWidth: .infinity)
 .accessibilityLabel("Confirm payment")
 .accessibilityHint("Confirms and processes the payment")
 ```

 */
