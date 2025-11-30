import SwiftUI

struct SwipeableInProgressRow: View {
    let model: TaskDisplayModel
    var isSyncing: Bool = false
    let onComplete: () -> Void
    let onCancel: () -> Void
    let onTap: () -> Void
    
    @GestureState private var dragOffset: CGFloat = 0
    private let threshold: CGFloat = 80
    
    var body: some View {
        let offset = dragOffset
        ZStack {
            // Background action labels
            HStack {
                if offset > 0 {
                    actionLabel(text: "Complete", systemImage: "checkmark", color: .green)
                }
                Spacer()
                if offset < 0 {
                    actionLabel(text: "Cancel", systemImage: "arrow.uturn.backward", color: .orange)
                }
            }
            .padding(.horizontal, 24)
            
            // Main content
            InProgressBar(model: model, isSyncing: isSyncing)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($dragOffset) { value, state, _ in
                            guard !isSyncing else { return }
                            state = value.translation.width
                        }
                        .onEnded { value in
                            guard !isSyncing else { return }
                            let width = value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if width > threshold {
                                    onComplete()
                                } else if width < -threshold {
                                    onCancel()
                                }
                            }
                        }
                )
                .onTapGesture(perform: onTap)
        }
        .opacity(isSyncing ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSyncing)
    }
    
    private func actionLabel(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color)
            )
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 16) {
        SwipeableInProgressRow(
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
            isSyncing: false,
            onComplete: {},
            onCancel: {},
            onTap: {}
        )
        
        SwipeableInProgressRow(
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
            isSyncing: true,
            onComplete: {},
            onCancel: {},
            onTap: {}
        )
    }
    .padding()
}
