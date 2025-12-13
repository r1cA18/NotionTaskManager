import SwiftUI

/// Calendar popup for selecting a date with Liquid Glass design
struct CalendarPopupView: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempSelectedDate: Date
    
    init(selectedDate: Binding<Date>, onDateSelected: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        self._tempSelectedDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar
                DatePicker(
                    "日付を選択",
                    selection: $tempSelectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .environment(\.timeZone, .tokyo)
                .tint(.accentColor)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Divider()
                    .padding(.top, 16)
                
                // Quick actions
                quickActions
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("日付を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("選択") {
                        selectedDate = tempSelectedDate
                        onDateSelected(tempSelectedDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var quickActions: some View {
        HStack(spacing: 12) {
            quickDateButton(label: "昨日", offset: -1)
            quickDateButton(label: "今日", offset: 0, isPrimary: true)
            quickDateButton(label: "明日", offset: 1)
            quickDateButton(label: "来週", offset: 7)
        }
    }
    
    private func quickDateButton(label: String, offset: Int, isPrimary: Bool = false) -> some View {
        Button {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .tokyo
            if let date = calendar.date(byAdding: .day, value: offset, to: Date.todayInJST()) {
                withAnimation(.spring(response: 0.25)) {
                    tempSelectedDate = date
                }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isPrimary ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isPrimary ? Color.accentColor : Color(.systemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CalendarPopupView(
        selectedDate: .constant(Date()),
        onDateSelected: { _ in }
    )
}
