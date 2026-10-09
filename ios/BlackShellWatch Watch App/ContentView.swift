import Foundation
import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var store: WatchRoundStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var selectedPlayerIndex = 0

  var body: some View {
    Group {
      if store.state.active, !store.state.players.isEmpty {
        roundView
      } else {
        waitingView
      }
    }
    .onAppear {
      selectedPlayerIndex = safePlayerIndex(store.state.currentPlayerIndex)
      store.requestLatestState()
    }
    .onChange(of: store.state) { _, newState in
      if selectedPlayerIndex >= newState.players.count {
        selectedPlayerIndex = safePlayerIndex(newState.currentPlayerIndex)
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        store.requestLatestState()
      }
    }
    .alert(
      localized("watch.error.title"),
      isPresented: Binding(
        get: { store.lastError != nil },
        set: { if !$0 { store.clearError() } }
      )
    ) {
      Button("OK", role: .cancel) { store.clearError() }
    } message: {
      Text(store.lastError ?? "")
    }
  }

  private var roundView: some View {
    ScrollView {
      VStack(spacing: 8) {
        VStack(spacing: 1) {
          Text(store.state.courseName)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)

          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(localizedFormat("watch.hole.format", store.state.holeNumber))
              .font(.headline.weight(.bold))
            if store.state.par > 0 {
              Text(localizedFormat("watch.par.format", store.state.par))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            }
            if let yards = store.state.yards {
              Text(localizedFormat("watch.yards.format", yards))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }

        if store.state.players.count > 1 {
          Picker(localized("watch.player"), selection: $selectedPlayerIndex) {
            ForEach(store.state.players) { player in
              Text(player.name).tag(player.id)
            }
          }
          .labelsHidden()
        } else if let player = selectedPlayer {
          Text(player.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
        }

        if let player = selectedPlayer {
          HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(player.entered ? relativeScore(player.holeScore) : "–")
              .font(.system(size: 42, weight: .bold, design: .rounded))
              .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: 0) {
              Text(localized("watch.current_hole"))
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(localizedFormat("watch.total.format", relativeScore(player.toPar)))
                .font(.caption.weight(.semibold))
            }
          }
          .accessibilityElement(children: .combine)

          HStack(spacing: 8) {
            scoreButton(systemName: "minus", delta: -1)
            Button(localized("watch.mark_par")) {
              store.send(command: "markPar", playerIndex: selectedPlayerIndex)
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.bordered)
            .tint(.green)
            .disabled(!store.isReachable)
            scoreButton(systemName: "plus", delta: 1)
          }
        }

        HStack(spacing: 10) {
          Button {
            store.send(command: "previousHole")
          } label: {
            Label(localized("watch.previous"), systemImage: "chevron.left")
              .labelStyle(.iconOnly)
          }
          .disabled(!store.isReachable || store.state.holeIndex <= 0)

          Text(
            store.isReachable
              ? localizedStatus(store.state.statusCode)
              : localized("watch.iphone_disconnected")
          )
            .font(.caption2)
            .foregroundStyle(
              store.isReachable ? Color.white.opacity(0.62) : Color.orange
            )
            .lineLimit(1)
            .frame(maxWidth: .infinity)

          Button {
            store.send(command: "nextHole")
          } label: {
            Label(
              store.state.isLastHole
                ? localized("watch.results")
                : localized("watch.next"),
              systemImage: store.state.isLastHole ? "trophy" : "chevron.right"
            )
              .labelStyle(.iconOnly)
          }
          .disabled(
            !store.isReachable ||
              !store.state.holeComplete
          )
        }
        .buttonStyle(.bordered)
      }
      .padding(.horizontal, 4)
    }
  }

  private var waitingView: some View {
    VStack(spacing: 8) {
      Image(systemName: "figure.golf")
        .font(.system(size: 34))
        .foregroundStyle(.green)
      Text("BS Golf")
        .font(.headline)
      Text(localized("watch.waiting.message"))
        .font(.caption2)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.secondary)
      Button(localized("watch.reload")) {
        store.requestLatestState()
      }
      .font(.caption)
      .disabled(!store.isReachable)
    }
    .padding()
  }

  private var selectedPlayer: WatchPlayer? {
    guard store.state.players.indices.contains(selectedPlayerIndex) else {
      return store.state.players.first
    }
    return store.state.players[selectedPlayerIndex]
  }

  private func scoreButton(systemName: String, delta: Int) -> some View {
    Button {
      store.send(
        command: "scoreDelta",
        playerIndex: selectedPlayerIndex,
        delta: delta
      )
    } label: {
      Image(systemName: systemName)
        .font(.headline.weight(.bold))
    }
    .buttonStyle(.borderedProminent)
    .tint(.green)
    .disabled(!store.isReachable)
    .accessibilityLabel(
      localized(delta > 0 ? "watch.score.increment" : "watch.score.decrement")
    )
  }

  private func safePlayerIndex(_ suggestedIndex: Int) -> Int {
    guard !store.state.players.isEmpty else { return 0 }
    return min(max(suggestedIndex, 0), store.state.players.count - 1)
  }

  private func relativeScore(_ score: Int) -> String {
    if score == 0 { return "E" }
    return score > 0 ? "+\(score)" : "\(score)"
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
      return localized("watch.status.complete")
    case "readyForNextHole":
      return localized("watch.status.ready")
    default:
      return localized("watch.status.scoring")
    }
  }
}
