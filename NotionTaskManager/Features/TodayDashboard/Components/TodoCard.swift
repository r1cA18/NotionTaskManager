import SwiftUI

struct TodoCard: View {
    let model: TaskDisplayModel
    let tint: Color
    var isSyncing: Bool = false
    let onStart: () -> Void
    let onTrash: () -> Void
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Title + Priority
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Metadata row
                        HStack(spacing: 10) {
                            if let timestamp = model.timestamp {
                                Label {
                                    Text(timestamp.formatted(date: .abbreviated, time: .omitted))
                                } icon: {
                                    Image(systemName: "calendar")
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            }
                            
                            Label {
                                Text(model.timeslotLabel)
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Priority badge
                    if let priority = model.priority {
                        priorityBadge(priority)
                    }
                }
                
                // Memo preview
                if let memo = memoText {
                    Text(memo)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                // Bookmark link
                if let url = model.url, let label = model.bookmarkLabel {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .medium))
                            Text(label)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(tint.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Action buttons
                HStack(spacing: 10) {
                    // Start button
                    Button(action: onStart) {
                        HStack(spacing: 6) {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text("開始")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [tint, tint.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: tint.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.status == .inProgress || isSyncing)
                    .opacity(model.status == .inProgress || isSyncing ? 0.6 : 1)
                    
                    Spacer()
                    
                    // Trash button
                    Button(action: onTrash) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color(.systemFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSyncing)
                    .opacity(isSyncing ? 0.5 : 1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.3), tint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(CardButtonStyle())
        .opacity(isSyncing ? 0.8 : 1)
        .animation(.easeInOut(duration: 0.2), value: isSyncing)
    }
    
    private func priorityBadge(_ priority: TaskPriority) -> some View {
        let color = TaskPalette.priorityColor(priority)
        return HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
            Text(priorityShortLabel(priority))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
    
    private func priorityShortLabel(_ priority: TaskPriority) -> String {
        switch priority {
        case .fourStars: return "4"
        case .threeAndHalf: return "3.5"
        case .twoStars: return "2"
        case .oneStar: return "1"
        }
    }
    
    private var memoText: String? {
        let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

// Custom button style for card press effect
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            TodoCard(
                model: TaskDisplayModel(task: TaskEntity(
                    notionID: "1",
                    name: "朝の会議準備をする",
                    memo: "資料のレビューと参加者への連絡",
                    status: .toDo,
                    timestamp: Date(),
                    timeslot: .morning,
                    priority: .fourStars,
                    updatedAt: Date(),
                    createdAt: Date()
                )),
                tint: .orange,
                isSyncing: false,
                onStart: {},
                onTrash: {},
                onTap: {}
            )
            
            TodoCard(
                model: TaskDisplayModel(task: TaskEntity(
                    notionID: "2",
                    name: "デザインレビュー",
                    status: .toDo,
                    timestamp: Date(),
                    timeslot: .afternoon,
                    priority: .twoStars,
                    updatedAt: Date(),
                    createdAt: Date()
                )),
                tint: .blue,
                isSyncing: true,
                onStart: {},
                onTrash: {},
                onTap: {}
            )
        }
        .padding()
    }
}
