import SwiftUI

/// The compact, read-only month grid at the top of the popover (PEEK-201).
/// Days with visible events carry a dot; choosing a day shows its agenda below.
struct MonthCalendarView: View {
    let grid: MonthGrid
    let eventDays: Set<Date>
    let selectedDay: Date?
    let onSelectDay: (Date) -> Void
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onToday: () -> Void

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    private static let accessibilityDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: PeekSpacing.xs) {
            HStack(spacing: PeekSpacing.xs) {
                Text(Self.monthFormatter.string(from: grid.monthStart).capitalized)
                    .font(PeekFont.bodyEmphasis)
                    .foregroundColor(PeekColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                navButton(systemName: "chevron.left", help: NSLocalizedString("Previous month", comment: "Month view: previous month"), action: onPreviousMonth)
                Button(NSLocalizedString("Today", comment: "Month view: jump to today"), action: onToday)
                    .buttonStyle(SecondaryFillButtonStyle())
                    .controlSize(.small)
                navButton(systemName: "chevron.right", help: NSLocalizedString("Next month", comment: "Month view: next month"), action: onNextMonth)
            }

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(MonthGrid.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(PeekFont.captionStrong)
                        .foregroundColor(PeekColor.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                ForEach(grid.days, id: \.date) { day in
                    dayCell(day)
                }
            }
        }
        .padding(.horizontal, PeekSpacing.md)
        .padding(.vertical, PeekSpacing.sm)
    }

    private func navButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(PeekIcon.meta)
                .foregroundColor(PeekColor.secondaryText)
                .frame(width: PeekMetrics.monthNavButton, height: PeekMetrics.monthNavButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(help))
    }

    private func dayCell(_ day: MonthGrid.Day) -> some View {
        let isSelected = selectedDay == day.date
        let hasEvents = eventDays.contains(day.date)

        return Button {
            onSelectDay(day.date)
        } label: {
            VStack(spacing: PeekMetrics.monthDotGap) {
                Text(verbatim: "\(day.dayNumber)")
                    .font(day.isToday || isSelected ? PeekFont.captionStrong : PeekFont.caption)
                    .monospacedDigit()
                    .foregroundColor(numberColor(day, isSelected: isSelected))
                    .frame(width: PeekMetrics.monthDayNumber.width, height: PeekMetrics.monthDayNumber.height)
                    .background(
                        RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous)
                            .fill(numberBackground(day, isSelected: isSelected))
                    )
                Circle()
                    .fill(hasEvents ? (day.isPast ? PeekColor.tertiaryText : PeekColor.accentRail) : Color.clear)
                    .frame(width: PeekMetrics.monthEventDot, height: PeekMetrics.monthEventDot)
            }
            .frame(maxWidth: .infinity)
            .frame(height: PeekMetrics.monthDayCellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel(day, hasEvents: hasEvents)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func numberColor(_ day: MonthGrid.Day, isSelected: Bool) -> Color {
        if day.isToday { return PeekColor.onAccent }
        if isSelected { return PeekColor.accentText }
        if !day.isInMonth { return PeekColor.tertiaryText }
        return day.isPast ? PeekColor.secondaryText : PeekColor.ink
    }

    private func numberBackground(_ day: MonthGrid.Day, isSelected: Bool) -> Color {
        if day.isToday { return PeekColor.accent }
        if isSelected { return PeekColor.blueTint }
        return Color.clear
    }

    private func accessibilityLabel(_ day: MonthGrid.Day, hasEvents: Bool) -> String {
        let date = Self.accessibilityDayFormatter.string(from: day.date)
        return hasEvents
            ? String(format: NSLocalizedString("%@, has events", comment: "Month view: day with events"), date)
            : date
    }
}
