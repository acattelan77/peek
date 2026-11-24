import SwiftUI

/// The compact, read-only month grid at the top of the popover (PEEK-201).
/// Days with visible events carry a dot; choosing a day shows its agenda below.
struct MonthCalendarView: View {
    let grid: MonthGrid
    let eventDays: Set<Date>
    let selectedDay: Date?
    let onSelectDay: (Date) -> Void

    /// "November 2026", capitalized for languages that lowercase month names.
    static func monthTitle(for date: Date) -> String {
        monthFormatter.string(from: date).capitalized
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    private static let accessibilityDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        // The month title and ‹ Today › controls live in the popover header (Peek 2.0).
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(MonthGrid.shortWeekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(PeekFont.sectionLabel)
                    .tracking(PeekFont.weekdayTracking)
                    .foregroundColor(PeekColor.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, PeekSpacing.xs)
                    .accessibilityHidden(true)
            }
            ForEach(grid.days, id: \.date) { day in
                dayCell(day)
            }
        }
        .padding(PeekMetrics.monthGridInsets)
    }

    private func dayCell(_ day: MonthGrid.Day) -> some View {
        let isSelected = selectedDay == day.date
        // Out-of-month days stay quiet: no event dot, as in the mockup.
        let hasEvents = day.isInMonth && eventDays.contains(day.date)

        return Button {
            onSelectDay(day.date)
        } label: {
            VStack(spacing: PeekMetrics.monthDotGap) {
                Text(verbatim: "\(day.dayNumber)")
                    .font(day.isToday || isSelected ? PeekFont.dayNumberStrong : PeekFont.dayNumber)
                    .monospacedDigit()
                    .foregroundColor(numberColor(day, isSelected: isSelected))
                    .frame(width: PeekMetrics.monthDayNumber.width, height: PeekMetrics.monthDayNumber.height)
                    .background(
                        RoundedRectangle(cornerRadius: PeekRadius.button, style: .continuous)
                            .fill(numberBackground(day, isSelected: isSelected))
                    )
                Circle()
                    .fill(hasEvents ? (day.isPast ? PeekColor.mutedText : PeekColor.accentRail) : Color.clear)
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
        if !day.isInMonth { return PeekColor.mutedText }
        return day.isPast ? PeekColor.tertiaryText : PeekColor.ink
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
