import SwiftUI

/// After the profile: your card and numbers, and opening a room. Offline, the
/// room is yours alone and bots take the other seats.
struct RoomsView: View {
    let store: GameStore
    @State private var model: RoomsViewModel
    @State private var creating = false
    @State private var editingProfile = false

    init(store: GameStore) {
        self.store = store
        _model = State(initialValue: RoomsViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    botsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            Button("أنشئ غرفة", systemImage: "plus") { creating = true }
                .buttonStyle(GoldButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $creating) {
            CreateRoomSheet(defaultName: "غرفة \(model.profile?.nickname ?? "")") { name, capacity in
                model.create(name: name, capacity: capacity)
            }
            .presentationDetents([.medium, .large])
            .environment(\.layoutDirection, .rightToLeft)
        }
        .sheet(isPresented: $editingProfile) {
            ProfileView(store: store, isEditing: true)
                .presentationBackground(Palette.Night.top)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }

    // MARK: Me

    private var profileCard: some View {
        HStack(spacing: 14) {
            PlayerAvatar(name: model.profile?.nickname ?? "؟", avatar: model.profile?.avatar, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.profile?.nickname ?? "").font(.kufi(20, weight: 600)).lineLimit(1)
                HStack(spacing: 12) {
                    StatLabel(value: model.stats.games, title: "لعبة")
                    StatLabel(value: model.stats.wins, title: "فوز")
                    if let rate = model.winRate { StatLabel(value: rate, title: "٪ فوز") }
                }
            }
            Spacer()
            Button("عدّل ملفك", systemImage: "pencil") { editingProfile = true }
                .buttonStyle(IconButtonStyle())
                .foregroundStyle(Palette.gold)
        }
        .panel()
    }

    private var botsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "cpu").font(.system(size: 34)).foregroundStyle(Palette.gold)
            Text("العب مع البوتات").font(.kufi(17))
            Text("اللعبة كلها على جهازك: أنشئ غرفة، والبوتات يقعدون على باقي الكراسي.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.Night.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .panel()
    }
}

private struct StatLabel: View {
    let value: Int
    let title: String

    var body: some View {
        HStack(spacing: 3) {
            Text("\(value)").font(.subheadline.weight(.bold).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(Palette.Night.muted)
        }
    }
}

#Preview {
    RootView(store: PreviewData.store(phase: nil))
}
