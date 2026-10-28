import SwiftUI

/// Picks the screen from the room's phase and wraps it in the night/day theme.
struct RootView: View {
    let store: GameStore

    private var phase: GamePhase? { store.room?.phase }
    private var theme: PhaseTheme { PhaseTheme(phase: phase, winner: store.room?.winner) }

    /// The lobby and the game share the table (and its background).
    private var atTable: Bool { phase != nil }

    var body: some View {
        ZStack {
            if atTable {
                BoardBackground(theme: theme)
            } else {
                PanoramaBackground()
            }
            content
        }
        .animation(.easeInOut(duration: 0.5), value: atTable)
        .overlay(alignment: .top) { connectionBanner }
        .overlay(alignment: .bottom) { errorToast }
        .environment(\.phaseTheme, theme)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .foregroundStyle(theme.text)
        .tint(theme.accentText)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: phase) { _, new in announce(new) }
        .alert("تنبيه", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("حسناً", role: .cancel) {}
        } message: {
            Text(store.notice ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case nil:
            if store.updateRequired {
                UpdateRequiredView()
            } else if store.profile == nil || store.profileRejected {
                ProfileView(store: store)
            } else {
                RoomsView(store: store)
            }
        case .lobby: LobbyView(store: store)
        case .some: GameBoardView(store: store)
        }
    }

    @ViewBuilder private var connectionBanner: some View {
        if store.status != .connected && !store.nickname.isEmpty {
            Label(store.status == .connecting ? "جاري الاتصال..." : "انقطع الاتصال، نحاول نرجع...", systemImage: "wifi.exclamationmark")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Palette.danger))
                .foregroundStyle(.white)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder private var errorToast: some View {
        if let error = store.lastError {
            Text(error.message)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Palette.Night.surface))
                .foregroundStyle(Palette.Night.text)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: error.id) {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { store.lastError = nil }
                }
        }
    }

    private func announce(_ phase: GamePhase?) {
        switch phase {
        case .morning: Haptics.announce(store.room?.lastNightKilledIds.isEmpty == false ? .warning : .success)
        case .verdict: Haptics.announce(store.room?.verdict?.eliminatedId != nil ? .warning : .success)
        case .ended: Haptics.announce(.success)
        case .night, .roleReveal: Haptics.tap(.medium)
        default: break
        }
    }
}
