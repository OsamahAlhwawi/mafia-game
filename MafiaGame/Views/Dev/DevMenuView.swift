import SwiftUI

/// Dev-mode tools: fill the room with bots, pick your role, shorten timers.
struct DevMenuView: View {
    let model: LobbyViewModel
    @Environment(\.dismiss) private var dismiss
    /// Shown at once when tapped; the server's answer catches up in the background.
    @State private var role: RoleID?
    @State private var fastTimers = false

    init(model: LobbyViewModel) {
        self.model = model
        _role = State(initialValue: model.forcedRole)
        _fastTimers = State(initialValue: model.fastTimers)
    }

    private let roles: [(RoleID?, String)] = [
        (nil, "عشوائي"), (.mafia, "المافيا"), (.doctor, "الطبيب"), (.detective, "المحقق"),
        (.officer, "الضابط"), (.mayor, "العمدة"), (.citizen, "المواطن"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("اللاعبين") {
                    Button("أضف بوت", systemImage: "plus.circle.fill", action: model.addBot)
                        .disabled(!model.canAddBot)
                    Button("كمّل العدد لـ 5 ببوتات", systemImage: "person.3.fill") {
                        for _ in 0..<model.missingPlayers { model.addBot() }
                    }
                    .disabled(!model.canAddBot || model.missingPlayers == 0)
                }
                Section("دوري في اللعبة الجاية") {
                    Picker("الدور", selection: $role) {
                        ForEach(roles, id: \.1) { role, name in
                            Text(name).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: role) { _, new in if new != model.forcedRole { model.setForcedRole(new) } }
                    .onChange(of: model.forcedRole) { _, new in role = new }
                }
                if model.isHost {
                    Section("المؤقتات") {
                        Toggle("مؤقتات سريعة للتجربة", isOn: $fastTimers)
                            .onChange(of: fastTimers) { _, new in if new != model.fastTimers { model.setFastTimers(new) } }
                            .onChange(of: model.fastTimers) { _, new in fastTimers = new }
                    }
                }
            }
            .navigationTitle("أدوات التطوير")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("تم") { dismiss() }
            }
        }
    }
}
