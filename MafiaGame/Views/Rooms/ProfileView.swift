import SwiftUI

/// Who you are: a name, boy or girl, and an avatar. The first screen on a new
/// device, and the edit sheet from the rooms screen.
struct ProfileView: View {
    let store: GameStore
    /// Shown as a sheet (editing) rather than the first screen.
    var isEditing = false
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String
    @State private var gender: Gender
    @State private var avatar: String
    @FocusState private var nameFocused: Bool

    init(store: GameStore, isEditing: Bool = false) {
        self.store = store
        self.isEditing = isEditing
        let saved = store.profile
        let gender = saved?.gender ?? .male
        _nickname = State(initialValue: saved?.nickname ?? "")
        _gender = State(initialValue: gender)
        _avatar = State(initialValue: saved?.avatar ?? PlayerAvatar.keys[gender]!.randomElement()!)
    }

    private var trimmed: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty && trimmed.count <= 20 }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if !isEditing {
                    VStack(spacing: 6) {
                        Text("المافيا").font(.kufi(52, weight: 600, relativeTo: .largeTitle))
                        Text("الراوي صار في جيبك").font(.title3).foregroundStyle(Palette.Night.muted)
                    }
                    .padding(.top, 70)
                }

                PlayerAvatar(name: trimmed.isEmpty ? "؟" : trimmed, avatar: avatar, size: 112)
                    .overlay(Circle().stroke(Palette.gold, lineWidth: 3).padding(-4))
                    .padding(.top, isEditing ? 12 : 0)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("اسمك").font(.kufi(16))
                        TextField("اسمك في اللعبة", text: $nickname)
                            .textContentType(.nickname)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .modifier(InputField())
                        if store.profileRejected {
                            Text("الاسم فيه كلمة غير مناسبة، اختر اسم ثاني.")
                                .font(.footnote)
                                .foregroundStyle(Palette.danger)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("أنت").font(.kufi(16))
                        Picker("الجنس", selection: $gender) {
                            Text("ولد").tag(Gender.male)
                            Text("بنت").tag(Gender.female)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: gender) { _, new in
                            if !avatar.hasPrefix(new == .male ? "m" : "f") { avatar = PlayerAvatar.keys[new]!.randomElement()! }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("اختر صورتك").font(.kufi(16))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                            ForEach(PlayerAvatar.keys[gender]!, id: \.self) { key in
                                Button { avatar = key } label: {
                                    PlayerAvatar(name: "؟", avatar: key, size: 64)
                                        .overlay(Circle().stroke(Palette.gold, lineWidth: key == avatar ? 3 : 0).padding(-3))
                                        .scaleEffect(key == avatar ? 1.06 : 1)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("صورة \(key.dropFirst())")
                                .accessibilityAddTraits(key == avatar ? .isSelected : [])
                            }
                        }
                        .animation(.spring(duration: 0.25), value: avatar)
                    }
                }
                .panel()

                Button(isEditing ? "حفظ" : "يلا نلعب", action: save)
                    .buttonStyle(GoldButtonStyle())
                    .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = false }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        guard canSave else { return }
        store.saveProfile(Profile(nickname: trimmed, gender: gender, avatar: avatar))
        if isEditing { dismiss() }
    }
}

/// Text field look shared by the profile and rooms screens.
struct InputField: ViewModifier {
    @Environment(\.phaseTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.text.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.stroke, lineWidth: 1))
    }
}

#Preview {
    RootView(store: GameStore(service: MockGameService(), identity: InMemoryIdentityStore()))
}
