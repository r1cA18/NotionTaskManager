import SwiftUI

struct SwipeableInProgressRow: View {
    let model: TaskDisplayModel
    let onComplete: () -> Void
    let onCancel: () -> Void
    let onTap: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    private let threshold: CGFloat = 80

    var body: some View {
        let offset = dragOffset
        ZStack {
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

            InProgressBar(model: model)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let width = value.translation.width
                            withAnimation(.spring()) {
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
    }

    private func actionLabel(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
    }
}
