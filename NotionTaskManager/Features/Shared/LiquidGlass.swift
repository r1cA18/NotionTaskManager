import SwiftUI

// MARK: - Liquid Glass Design System for iOS 26

/// Glass material types for different contexts
enum GlassMaterial {
    case ultraThin
    case thin
    case regular
    case thick
    case chrome
    
    var material: Material {
        switch self {
        case .ultraThin: return .ultraThinMaterial
        case .thin: return .thinMaterial
        case .regular: return .regularMaterial
        case .thick: return .thickMaterial
        case .chrome: return .bar
        }
    }
}

// MARK: - Glass Background Modifier

struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    let material: GlassMaterial
    let shadowRadius: CGFloat
    let borderOpacity: CGFloat
    
    init(
        cornerRadius: CGFloat = 24,
        material: GlassMaterial = .thin,
        shadowRadius: CGFloat = 12,
        borderOpacity: CGFloat = 0.2
    ) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.shadowRadius = shadowRadius
        self.borderOpacity = borderOpacity
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material.material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: shadowRadius, x: 0, y: 4)
    }
}

// MARK: - Glass Card View

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let material: GlassMaterial
    let padding: CGFloat
    @ViewBuilder let content: () -> Content
    
    init(
        cornerRadius: CGFloat = 20,
        material: GlassMaterial = .thin,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.padding = padding
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(padding)
            .modifier(GlassBackground(cornerRadius: cornerRadius, material: material))
    }
}

// MARK: - Floating Glass Button

struct GlassButton: View {
    let icon: String
    let title: String?
    let tint: Color
    let size: CGFloat
    let action: () -> Void
    
    init(
        icon: String,
        title: String? = nil,
        tint: Color = .accentColor,
        size: CGFloat = 56,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.tint = tint
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .medium))
                
                if let title {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(.white)
            .frame(width: size, height: title != nil ? size + 8 : size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.4, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: tint.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Pill Button

struct GlassPill: View {
    let icon: String?
    let text: String
    let tint: Color
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(text)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isActive ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isActive ? tint : Color(.systemFill))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isActive ? 0.3 : 0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Segmented Control

struct GlassSegmentedPicker<T: Hashable & CaseIterable & Identifiable>: View where T.AllCases: RandomAccessCollection {
    @Binding var selection: T
    let titleForItem: (T) -> String
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(T.allCases)) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                    }
                } label: {
                    Text(titleForItem(item))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(selection == item ? .white : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "segment", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - View Extensions

extension View {
    func glassBackground(
        cornerRadius: CGFloat = 24,
        material: GlassMaterial = .thin,
        shadowRadius: CGFloat = 12
    ) -> some View {
        modifier(GlassBackground(
            cornerRadius: cornerRadius,
            material: material,
            shadowRadius: shadowRadius
        ))
    }
    
    func glassMorphism() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Updated Color Palette

struct LiquidColors {
    // Primary accent colors
    static let accent = Color.accentColor
    static let accentGradient = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Status colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // Task status colors (softer, glass-friendly)
    static let todoTint = Color.blue.opacity(0.15)
    static let todoForeground = Color.blue
    static let inProgressTint = Color.orange.opacity(0.15)
    static let inProgressForeground = Color.orange
    static let completedTint = Color.green.opacity(0.15)
    static let completedForeground = Color.green
    
    // Timeslot colors
    static func timeslotColor(for slot: TaskTimeslot?) -> Color {
        switch slot {
        case .morning: return .orange
        case .forenoon: return .yellow
        case .afternoon: return .blue
        case .evening: return .purple
        case .none: return .gray
        }
    }
    
    // Priority colors
    static func priorityColor(for priority: TaskPriority?) -> Color {
        switch priority {
        case .fourStars: return .red
        case .threeAndHalf: return .orange
        case .twoStars: return .yellow
        case .oneStar: return .green
        case .none: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 24) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("This is a liquid glass card with blur effect")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 16) {
                GlassButton(icon: "plus", tint: .blue) {}
                GlassButton(icon: "tray.full", title: "Inbox", tint: .orange) {}
            }
            
            HStack {
                GlassPill(icon: "star.fill", text: "Priority", tint: .orange, isActive: true) {}
                GlassPill(icon: "clock", text: "Later", tint: .blue, isActive: false) {}
            }
        }
        .padding()
    }
}
