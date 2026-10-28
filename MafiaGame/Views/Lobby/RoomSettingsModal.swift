import SwiftUI

/// The room's settings on parchment, rising from the bottom over the dimmed
/// table: mafia count, special roles and discussion length (the leader changes
/// them, everyone else sees them), then the rules, the dev tools and leaving.
struct RoomSettingsModal: View {
    let model: LobbyViewModel
    let close: () -> Void
    let openDeck: () -> Void
    let openDevTools: () -> Void

    @State private var shown = false
    private let ink = Color(hex: 0x3A2A17)

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.6 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                page
                Button("خروج من الغرفة", systemImage: "rectangle.portrait.and.arrow.right", action: model.leave)
                    .buttonStyle(FilledButtonStyle(color: Palette.danger, font: .kufi(18, weight: 600), height: 56, cornerRadius: 0))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .offset(y: shown ? 0 : 500)
        }
        .environment(\.colorScheme, .light)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { shown = true }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismiss() }
    }

    /// Slides the page back down, then hands over (to the rules or the dev tools, if asked).
    private func dismiss(then next: (() -> Void)? = nil) {
        withAnimation(.easeIn(duration: 0.2)) { shown = false } completion: {
            close()
            next?()
        }
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Ornament(color: ink.opacity(0.3))

            section("عدد المافيا") {
                if model.isHost {
                    HStack(spacing: 6) {
                        InkChip(title: "تلقائي", selected: model.mafiaChoice == nil) { model.setMafia(nil) }
                        ForEach(1...3, id: \.self) { n in
                            InkChip(title: "\(n)", selected: model.mafiaChoice == n) { model.setMafia(n) }
                                .disabled(n > model.maxMafia)
                        }
                    }
                } else {
                    value("\(model.mafiaInDeck)")
                }
            }
            if let note = model.mafiaCapNote {
                Text(note).font(.caption).foregroundStyle(ink.opacity(0.65))
            }

            VStack(alignment: .leading, spacing: 10) {
                label("الأدوار الخاصة")
                RoleToggles(roles: model.optionalRoles, canEdit: model.isHost, toggle: model.toggle)
            }

            section("مدة النقاش") {
                HStack(spacing: 10) {
                    if model.isHost {
                        stepButton("أقل", symbol: "minus", disabled: model.discussionSeconds <= 30) { model.changeDiscussion(by: -15) }
                    }
                    value(TimerRing.format(TimeInterval(model.discussionSeconds)))
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(minWidth: 52)
                    if model.isHost {
                        stepButton("أكثر", symbol: "plus", disabled: model.discussionSeconds >= 300) { model.changeDiscussion(by: 15) }
                    }
                }
            }

            Ornament(color: ink.opacity(0.3))

            VStack(spacing: 0) {
                link("القواعد والبطاقات", symbol: "book.closed.fill") { dismiss(then: openDeck) }
                if model.canDebug {
                    Divider().overlay(ink.opacity(0.15))
                    link("أدوات التطوير", symbol: "hammer.fill") { dismiss(then: openDevTools) }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ParchmentFrame())
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("إعدادات الغرفة")
                    .font(.kufi(22, weight: 600))
                    .foregroundStyle(Palette.goldDeep)
                if !model.isHost {
                    Text("قائد الغرفة بس يقدر يغيّرها")
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.6))
                }
            }
            Spacer()
            Button("إغلاق", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ink.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(Circle().fill(ink.opacity(0.08)))
                .contentShape(Circle())
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            label(title)
            Spacer(minLength: 8)
            content()
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.kufi(16, weight: 600)).foregroundStyle(ink)
    }

    private func value(_ text: String) -> some View {
        Text(text).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(ink)
    }

    private func stepButton(_ title: String, symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol) {
            Haptics.choose()
            action()
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 15, weight: .bold))
        .frame(width: 40, height: 40)
        .background(Circle().stroke(ink.opacity(0.45), lineWidth: 1.5))
        .foregroundStyle(ink)
        .contentShape(Circle())
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private func link(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.goldDeep)
                    .frame(width: 24)
                Text(title).font(.kufi(16)).foregroundStyle(ink)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(ink.opacity(0.4))
            }
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One choice in a row (the mafia count), inked on the parchment.
private struct InkChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    private let ink = Color(hex: 0x3A2A17)

    var body: some View {
        Button {
            Haptics.choose()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(minWidth: 40, minHeight: 36)
                .background(Capsule().fill(selected ? ink : .clear))
                .overlay(Capsule().stroke(ink.opacity(selected ? 0 : 0.4), lineWidth: 1.5))
                .foregroundStyle(selected ? Color(hex: 0xF3E6C8) : ink)
                .opacity(isEnabled ? 1 : 0.3)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The special roles in their own colours when dealt, faded when off. The leader taps to switch.
private struct RoleToggles: View {
    let roles: [OptionalRole]
    let canEdit: Bool
    let toggle: (OptionalRole) -> Void

    private let ink = Color(hex: 0x3A2A17)

    /// Three to a row, the last row padded so every chip keeps the same width.
    private var rows: [[OptionalRole?]] {
        stride(from: 0, to: roles.count, by: 3).map { start in
            let row: [OptionalRole?] = Array(roles[start..<min(start + 3, roles.count)])
            return row + Array(repeating: nil, count: 3 - row.count)
        }
    }

    var body: some View {
        // Not a lazy grid: its chips are built a moment after the page appears and
        // would pop in at their final place instead of rising with it.
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    ForEach(Array(rows[index].enumerated()), id: \.offset) { _, option in
                        if let option { chip(option) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                    }
                }
            }
        }
    }

    private func chip(_ option: OptionalRole) -> some View {
        let style = RoleStyle.of(option.role.id)
        return Button {
            Haptics.choose()
            toggle(option)
        } label: {
            Label(option.role.name, systemImage: option.enabled ? style.symbol : "xmark")
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    Capsule().fill(option.enabled
                        ? AnyShapeStyle(LinearGradient(colors: style.gradient, startPoint: .topTrailing, endPoint: .bottomLeading))
                        : AnyShapeStyle(Color.clear))
                }
                .overlay(Capsule().strokeBorder(ink.opacity(option.enabled ? 0 : 0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                .foregroundStyle(option.enabled ? style.foreground : ink.opacity(0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // Not `.disabled`: the others should see the setup in full colour.
        .allowsHitTesting(canEdit)
        .accessibilityLabel("\(option.role.name)، \(option.enabled ? "موجود" : "مقفل")")
        .accessibilityHint(canEdit ? "اضغط عشان تشغّله أو تقفله" : "")
    }
}

#Preview {
    RoomSettingsModal(model: LobbyViewModel(store: PreviewData.store(phase: .lobby)), close: {}, openDeck: {}, openDevTools: {})
        .environment(\.layoutDirection, .rightToLeft)
}
