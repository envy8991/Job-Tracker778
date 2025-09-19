import SwiftUI

struct DashboardWeekdayPicker: View {
    let weekdays: [DashboardViewModel.Weekday]
    let selectedOffset: Int?
    let onSelect: (DashboardViewModel.Weekday) -> Void

    var body: some View {
        HStack(spacing: JTSpacing.sm) {
            ForEach(weekdays) { day in
                let isSelected = day.offset == selectedOffset
                Button {
                    onSelect(day)
                } label: {
                    Text(day.label)
                        .font(JTTypography.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .padding(.vertical, JTSpacing.sm)
                        .padding(.horizontal, JTSpacing.md)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? JTColors.accent.opacity(0.9) : JTColors.glassHighlight)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isSelected ? JTColors.accent : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(JTColors.textPrimary)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(day.label)")
            }
        }
        .padding(.horizontal, JTSpacing.md)
    }
}

#Preview("Weekday Picker – iPhone") {
    DashboardWeekdayPicker(
        weekdays: DashboardViewModel().weekdays,
        selectedOffset: 2,
        onSelect: { _ in }
    )
    .padding()
    .background(JTGradients.background.ignoresSafeArea())
}

#Preview("Weekday Picker – iPad") {
    DashboardWeekdayPicker(
        weekdays: DashboardViewModel().weekdays,
        selectedOffset: nil,
        onSelect: { _ in }
    )
    .padding()
    .frame(maxWidth: 600)
    .background(JTGradients.background.ignoresSafeArea())
}
