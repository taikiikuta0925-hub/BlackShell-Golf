import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct BlackShellRoundLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BlackShellGolfActivityAttributes.self) { context in
      LockScreenRoundView(context: context)
        .activityBackgroundTint(Color(red: 0.035, green: 0.12, blue: 0.09))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 1) {
            Text(localized("live.hole"))
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text("\(context.state.holeNumber)")
              .font(.title2.weight(.bold))
          }
          .accessibilityElement(children: .combine)
        }

        DynamicIslandExpandedRegion(.trailing) {
          if context.state.par > 0 {
            VStack(alignment: .trailing, spacing: 1) {
              Text(localized("live.par"))
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text("\(context.state.par)")
                .font(.title2.weight(.bold))
                .foregroundStyle(.green)
            }
            .accessibilityElement(children: .combine)
          }
        }

        DynamicIslandExpandedRegion(.center) {
          Text(context.state.courseName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }

        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            VStack(alignment: .leading, spacing: 1) {
              Text(context.state.currentPlayerName)
                .font(.headline)
                .lineLimit(1)
              Text(localizedStatus(context.state.statusCode))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
              Text(
                context.state.currentHoleEntered
                  ? relativeScore(context.state.currentHoleScore)
                  : "–"
              )
                .font(.title2.weight(.bold))
              Text(relativeScore(context.state.currentToPar))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            }
          }
        }
      } compactLeading: {
        Label(
          localizedFormat("live.compact_hole.format", context.state.holeNumber),
          systemImage: "figure.golf"
        )
        .labelStyle(.titleAndIcon)
        .font(.caption2.weight(.bold))
      } compactTrailing: {
        Text(relativeScore(context.state.currentToPar))
          .font(.caption.weight(.bold))
          .foregroundStyle(.green)
      } minimal: {
        Image(systemName: "figure.golf")
          .foregroundStyle(.green)
      }
      .keylineTint(.green)
    }
  }

  private func relativeScore(_ score: Int) -> String {
    if score == 0 { return "E" }
    return score > 0 ? "+\(score)" : "\(score)"
  }
}

private struct LockScreenRoundView: View {
  let context: ActivityViewContext<BlackShellGolfActivityAttributes>

  var body: some View {
    HStack(spacing: 12) {
      VStack(spacing: 0) {
        Text(localized("live.hole"))
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text("\(context.state.holeNumber)")
          .font(.system(size: 32, weight: .bold, design: .rounded))
        if context.state.par > 0 {
          Text(localizedFormat("live.par.format", context.state.par))
            .font(.caption.weight(.bold))
            .foregroundStyle(.green)
        }
      }
      .frame(width: 58)

      Rectangle()
        .fill(.white.opacity(0.12))
        .frame(width: 1, height: 54)

      VStack(alignment: .leading, spacing: 3) {
        Text(context.state.courseName)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Text(context.state.currentPlayerName)
          .font(.headline)
          .lineLimit(1)
        if !context.state.leaderName.isEmpty {
          Text(
            localizedFormat(
              "live.leader.format",
              context.state.leaderName,
              relativeScore(context.state.leaderToPar)
            )
          )
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        }
      }

      Spacer(minLength: 4)

      VStack(alignment: .trailing, spacing: 0) {
        Text(
          context.state.currentHoleEntered
            ? relativeScore(context.state.currentHoleScore)
            : "–"
        )
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .contentTransition(.numericText())
        Text(relativeScore(context.state.currentToPar))
          .font(.caption.weight(.bold))
          .foregroundStyle(.green)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .foregroundStyle(.white)
    .accessibilityElement(children: .combine)
  }

  private func relativeScore(_ score: Int) -> String {
    if score == 0 { return "E" }
    return score > 0 ? "+\(score)" : "\(score)"
  }
}

private func localized(_ key: String) -> String {
  NSLocalizedString(key, comment: "")
}

private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
  String(
    format: NSLocalizedString(key, comment: ""),
    locale: Locale.current,
    arguments: arguments
  )
}

private func localizedStatus(_ statusCode: String) -> String {
  switch statusCode {
  case "complete":
    return localized("live.status.complete")
  case "readyForNextHole":
    return localized("live.status.ready")
  default:
    return localized("live.status.scoring")
  }
}
