import SwiftUI

struct SwipeableInProgressRow: View {
    let model: TaskDisplayModel
    var isSyncing: Bool = false
    let onComplete: () -> Void
    let onCancel: () -> Void
    let onTap: () -> Void
    
    @GestureState private var dragOffset: CGFloat = 0
    private let threshold: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Background actions
            HStack(spacing: 0) {
                // Complete action (right swipe)
                if dragOffset > 20 {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("完了")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                Spacer()
                
                // Cancel action (left swipe)
                if dragOffset < -20 {
                    HStack(spacing: 8) {
                        Text("キャンセル")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.8), Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: dragOffset)
            
            // Main card
            InProgressBar(model: model, isSyncing: isSyncing)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .updating($dragOffset) { value, state, _ in
                            guard !isSyncing else { return }
                            // Add resistance at edges
                            let resistance: CGFloat = 0.7
                            state = value.translation.width * resistance
                        }
                        .onEnded { value in
                            guard !isSyncing else { return }
                            let translation = value.translation.width
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if translation > threshold {
                                    onComplete()
                                } else if translation < -threshold {
                                    onCancel()
                                }
                            }
                        }
                )
                .onTapGesture(perform: onTap)
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            SwipeableInProgressRow(
                model: TaskDisplayModel(task: TaskEntity(
                    notionID: "1",
                    name: "スワイプして完了/キャンセル",
                    status: .inProgress,
                    timestamp: Date(),
                    timeslot: .afternoon,
                    startTime: Date().addingTimeInterval(-1800),
                    priority: .threeAndHalf,
                    updatedAt: Date(),
                    createdAt: Date()
                )),
                isSyncing: false,
                onComplete: { print("Completed") },
                onCancel: { print("Cancelled") },
                onTap: { print("Tapped") }
            )
        }
        .padding()
    }
}
