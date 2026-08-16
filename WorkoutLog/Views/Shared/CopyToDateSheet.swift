import SwiftUI

private extension Calendar {
    /// 履歴画面の月間カレンダーに合わせた月曜始まりのカレンダー
    static var mondayStart: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
}

/// コピー先の日付を選択するシート（デフォルトの「今日にコピー」に対するオプション）
struct CopyToDateSheet: View {
    let maxDate: Date
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(maxDate: Date = Date(), onConfirm: @escaping (Date) -> Void) {
        self.maxDate = maxDate
        self.onConfirm = onConfirm
        _selectedDate = State(initialValue: maxDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "コピー先の日付",
                    selection: $selectedDate,
                    in: ...maxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.calendar, .mondayStart)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 12)
            .navigationTitle("コピー先の日付を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("コピー") {
                        onConfirm(selectedDate)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
    }
}
