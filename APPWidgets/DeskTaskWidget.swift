import ActivityKit
import SwiftUI
import WidgetKit

private func taskKind(_ raw: String) -> DeskTaskKind {
    DeskTaskKind(rawValue: raw) ?? .download
}

private func taskTint(_ raw: String) -> Color {
    taskKind(raw) == .decrypt
        ? Color(red: 0.62, green: 0.44, blue: 1.00)
        : Color(red: 0.20, green: 0.55, blue: 1.00)
}

private func taskSymbol(_ raw: String) -> String {
    taskKind(raw) == .decrypt ? "lock.open.fill" : "arrow.down.circle.fill"
}

private func percentText(_ value: Double) -> String {
    value <= 0 ? "0%" : "\(Int((value * 100).rounded()))%"
}

private struct TaskBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 3)
    }
}

private struct LockScreenCard: View {
    let state: DeskTaskAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(taskTint(state.kind).opacity(0.18))
                Image(systemName: taskSymbol(state.kind))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(taskTint(state.kind))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(state.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(state.done ? "完成" : percentText(state.progress))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(taskTint(state.kind))
                }
                Text(state.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                TaskBar(value: state.done ? 1 : state.progress, tint: taskTint(state.kind))
                Text(state.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(14)
    }
}

struct DeskTaskWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeskTaskAttributes.self) { context in
            LockScreenCard(state: context.state)
                .activityBackgroundTint(Color(red: 0.06, green: 0.06, blue: 0.07))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: taskSymbol(context.state.kind))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(taskTint(context.state.kind))
                        .frame(width: 26, height: 26)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.done ? "完成" : percentText(context.state.progress))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(taskTint(context.state.kind))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(context.state.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 7) {
                        TaskBar(value: context.state.done ? 1 : context.state.progress, tint: taskTint(context.state.kind))
                        Text(context.state.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: taskSymbol(context.state.kind))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(taskTint(context.state.kind))
            } compactTrailing: {
                Text(context.state.done ? "✓" : percentText(context.state.progress))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(taskTint(context.state.kind))
            } minimal: {
                Image(systemName: taskSymbol(context.state.kind))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(taskTint(context.state.kind))
            }
            .keylineTint(taskTint(context.state.kind))
        }
    }
}

@main
struct APPWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DeskTaskWidget()
    }
}
