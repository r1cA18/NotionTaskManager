import SwiftUI

struct InProgressBar: View {
    let model: TaskDisplayModel
    var isSyncing: Bool = false
    
    @State private var pulseAnimation = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Animated icon
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .scaleEffect(pulseAnimation ? 1.2 : 1)
                    .opacity(pulseAnimation ? 0 : 0.8)
                
                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("進行中")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                    
                    if isSyncing {
                        Text("同期中...")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(model.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label {
                        Text(model.timeslotLabel)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    
                    if let startTime = model.startTime {
                        Label {
                            Text(formatDuration(from: startTime))
                        } icon: {
                            Image(systemName: "timer")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Swipe hint
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.orange.opacity(0.15), radius: 16, x: 0, y: 8)
    }
    
    private func formatDuration(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            InProgressBar(
                model: TaskDisplayModel(task: TaskEntity(
                    notionID: "1",
                    name: "デザインレビュー中",
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
                    name: "同期中のタスク",
                    status: .inProgress,
                    timestamp: Date(),
                    timeslot: .morning,
                    startTime: Date().addingTimeInterval(-3600),
                    priority: .fourStars,
                    updatedAt: Date(),
                    createdAt: Date()
                )),
                isSyncing: true
            )
        }
        .padding()
    }
}
