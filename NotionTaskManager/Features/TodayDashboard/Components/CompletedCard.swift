import SwiftUI

struct CompletedCard: View {
    let model: TaskDisplayModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Checkmark circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .strikethrough(true, color: .secondary.opacity(0.5))
                        .lineLimit(1)
                    
                    HStack(spacing: 10) {
                        if let endTime = model.endTime {
                            Label {
                                Text(endTime.formatted(date: .omitted, time: .shortened))
                            } icon: {
                                Image(systemName: "clock.badge.checkmark")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                        
                        if let url = model.url, let label = model.bookmarkLabel {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                    Text(label)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.green.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 12) {
            CompletedCard(
                model: TaskDisplayModel(task: TaskEntity(
                    notionID: "1",
                    name: "メール確認完了",
                    status: .complete,
                    timestamp: Date(),
                    timeslot: .morning,
                    endTime: Date(),
                    priority: .twoStars,
                    updatedAt: Date(),
                    createdAt: Date()
                )),
                onTap: {}
            )
            
            CompletedCard(
                model: TaskDisplayModel(task: TaskEntity(
                    notionID: "2",
                    name: "レポート作成",
                    status: .complete,
                    timestamp: Date(),
                    timeslot: .afternoon,
                    endTime: Date().addingTimeInterval(-3600),
                    priority: .fourStars,
                    updatedAt: Date(),
                    createdAt: Date()
                )),
                onTap: {}
            )
        }
        .padding()
    }
}
