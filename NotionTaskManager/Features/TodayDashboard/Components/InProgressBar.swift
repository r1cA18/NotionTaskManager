import SwiftUI

struct InProgressBar: View {
    let model: TaskDisplayModel
    var isSyncing: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with sync indicator
            ZStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                if isSyncing {
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 36, height: 36)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(
                            .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                            value: isSyncing
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("In Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if isSyncing {
                        Text("同期中...")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                Text(model.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Label(model.timeslotLabel, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let startTime = model.startTime {
                        Label(
                            startTime.formatted(date: .omitted, time: .shortened),
                            systemImage: "clock.arrow.circlepath"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                
                if let memo = memoText {
                    Text(memo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                if let url = model.url, let label = model.bookmarkLabel {
                    Link(destination: url) {
                        Label(label, systemImage: "link")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("関連リンクを開く")
                }
            }
            
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    TaskPalette.tint(for: model.timeslot).opacity(isSyncing ? 0.3 : 0.6),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    private var memoText: String? {
        let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    VStack(spacing: 16) {
        InProgressBar(
            model: TaskDisplayModel(task: TaskEntity(
                notionID: "1",
                name: "Working on this task",
                status: .inProgress,
                timestamp: Date(),
                timeslot: .afternoon,
                startTime: Date().addingTimeInterval(-1800),
                priority: .threeAndHalf,
                updatedAt: Date(),
                createdAt: Date()
            )),
            isSyncing: false
        )
        
        InProgressBar(
            model: TaskDisplayModel(task: TaskEntity(
                notionID: "2",
                name: "Syncing task",
                status: .inProgress,
                timestamp: Date(),
                timeslot: .morning,
                startTime: Date().addingTimeInterval(-3600),
                priority: .twoStars,
                updatedAt: Date(),
                createdAt: Date()
            )),
            isSyncing: true
        )
    }
    .padding()
}
