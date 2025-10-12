//
//  CardView.swift
//  SplitSmart Design System
//
//  Reusable card components with depth system integration
//  Includes basic CardView and ElevatedCard with hover effects
//

import SwiftUI

// MARK: - Basic Card View
/// Standard card container with padding and subtle shadow
/// Use for: Content containers, list items, grouped content
struct CardView<Content: View>: View {
    let content: Content
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.paddingCard)
            .background(Color.adaptiveDepth2)
            .cornerRadius(.cornerRadiusMedium)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .accessibilityElement(children: .contain)
    }
}

// MARK: - Elevated Card with Depth
/// Card with configurable depth levels and hover effects
/// Use for: Interactive cards, prominent content, feature sections
struct ElevatedCard<Content: View>: View {
    let content: Content
    let depth: Int
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(depth: Int = 2, @ViewBuilder content: () -> Content) {
        self.depth = depth
        self.content = content()
    }

    var backgroundColor: Color {
        switch depth {
        case 1: return .adaptiveDepth1
        case 2: return .adaptiveDepth2
        case 3: return .adaptiveDepth3
        default: return .adaptiveDepth2
        }
    }

    var shadowRadius: CGFloat {
        isHovered ? CGFloat(depth * 4 + 4) : CGFloat(depth * 4)
    }

    var shadowOpacity: Double {
        isHovered ? 0.15 : 0.1
    }

    var yOffset: CGFloat {
        isHovered ? -2 : 0
    }

    var body: some View {
        content
            .padding(.paddingCard)
            .background(backgroundColor)
            .cornerRadius(.cornerRadiusMedium)
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .offset(y: yOffset)
            .animation(reduceMotion ? .none : .gentleSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .accessibilityElement(children: .contain)
    }
}

// MARK: - Compact Card
/// Minimal card with reduced padding
/// Use for: List rows, compact displays, dense layouts
struct CompactCard<Content: View>: View {
    let content: Content
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.spacingMD)
            .background(Color.adaptiveDepth1)
            .cornerRadius(.cornerRadiusSmall)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
            .accessibilityElement(children: .contain)
    }
}

// MARK: - Interactive Card
/// Card with tap action and press animation
/// Use for: Navigable cards, selectable items, interactive content
struct InteractiveCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(.paddingCard)
                .background(Color.adaptiveDepth2)
                .cornerRadius(.cornerRadiusMedium)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(reduceMotion ? .none : .smoothSpring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview Provider
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light Mode Preview
            ScrollView {
                VStack(spacing: .spacingLG) {
                    // Basic Card
                    CardView {
                        VStack(alignment: .leading, spacing: .spacingSM) {
                            Text("Basic Card")
                                .heading3()
                            Text("Standard card with consistent padding and shadow")
                                .bodyStyle()
                        }
                    }
                    .accessibilityLabel("Basic card example")

                    // Elevated Cards with Different Depths
                    ForEach(1...3, id: \.self) { depth in
                        ElevatedCard(depth: depth) {
                            VStack(alignment: .leading, spacing: .spacingSM) {
                                Text("Elevated Card - Depth \(depth)")
                                    .heading4()
                                Text("Hover to see elevation effect")
                                    .smallStyle()
                            }
                        }
                        .accessibilityLabel("Elevated card with depth level \(depth)")
                    }

                    // Compact Card
                    CompactCard {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.accentColor)
                                .accessibilityHidden(true)
                            Text("Compact Card")
                                .bodyStyle()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.adaptiveTextTertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Compact card example")

                    // Interactive Card
                    InteractiveCard(action: { print("Card tapped") }) {
                        HStack {
                            VStack(alignment: .leading, spacing: .spacingSM) {
                                Text("Interactive Card")
                                    .heading4()
                                Text("Tap to see animation")
                                    .smallStyle()
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Interactive card")
                    .accessibilityHint("Tap to activate")
                }
                .padding(.paddingScreen)
            }
            .background(Color.adaptiveDepth0)
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

            // Dark Mode Preview
            ScrollView {
                VStack(spacing: .spacingLG) {
                    CardView {
                        Text("Dark Mode Card")
                            .heading3()
                    }
                    .accessibilityLabel("Dark mode card example")

                    ElevatedCard(depth: 2) {
                        Text("Elevated in Dark Mode")
                            .bodyStyle()
                    }
                    .accessibilityLabel("Elevated card in dark mode")
                }
                .padding(.paddingScreen)
            }
            .background(Color.adaptiveDepth0)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}

// MARK: - Accessibility
extension CardView {
    /// Add accessibility label to card
    func accessibilityCard(label: String, hint: String? = nil) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .modifier(ConditionalAccessibilityHint(hint: hint))
    }
}

// Helper modifier for conditional accessibility hint
private struct ConditionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint = hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - Usage Examples
/*

 Basic Card:
 ```
 CardView {
     VStack(alignment: .leading, spacing: .spacingMD) {
         Text("Bill Summary")
             .heading3()
         Text("Total: $124.50")
             .bodyStyle()
     }
 }
 .accessibilityCard(label: "Bill summary", hint: "Shows total amount")
 ```

 Elevated Card with Depth:
 ```
 ElevatedCard(depth: 3) {
     VStack {
         Image(systemName: "checkmark.circle.fill")
             .font(.largeTitle)
             .foregroundColor(.adaptiveAccentGreen)
         Text("Payment Successful")
             .heading2()
     }
 }
 .accessibilityLabel("Payment confirmation")
 .accessibilityHint("Payment has been processed successfully")
 ```

 Compact Card for Lists:
 ```
 ForEach(items) { item in
     CompactCard {
         HStack {
             Text(item.name)
             Spacer()
             Text(item.amount)
         }
     }
     .accessibilityLabel("\(item.name), \(item.amount)")
 }
 ```

 Interactive Card:
 ```
 InteractiveCard(action: { navigateToDetail() }) {
     HStack {
         VStack(alignment: .leading) {
             Text("View Details")
                 .heading4()
             Text("Tap to open")
                 .smallStyle()
         }
         Spacer()
         Image(systemName: "chevron.right")
     }
 }
 .accessibilityLabel("View details")
 .accessibilityHint("Opens detailed view")
 ```

 */
