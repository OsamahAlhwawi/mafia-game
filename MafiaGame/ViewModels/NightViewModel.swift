import Foundation
import Observation

struct TargetRow: Identifiable, Equatable {
    let id: String
    let name: String
    let enabled: Bool
    let selected: Bool
    /// Teammates (mafia) who picked this player; "أنت" for me.
    let pickedBy: [String]
}

@MainActor
@Observable
final class NightViewModel {
    enum Mode: Equatable {
        /// Mafia: vote together, see each other's picks live.
        case team
        /// One player picks one target (doctor, detective, officer, future roles).
        case single(AbilityKind)
        /// Citizens and spectators.
        case waiting
    }

    private let store: GameStore

    init(store: GameStore) {
        self.store = store
    }

    var role: RoleInfo? { store.me?.role }
    var isAlive: Bool { store.me?.alive ?? false }
    var locked: Bool { store.me?.nightActionLocked ?? false }
    var myTarget: String? { store.me?.myNightTarget }
    /// A limited ability (the officer's bullet) that has been used up.
    var abilitySpent: Bool { store.me?.abilityUsesLeft == 0 }

    var mode: Mode {
        guard isAlive, let kind = role?.abilityKind, !abilitySpent else { return .waiting }
        return kind == .teamKill ? .team : .single(kind)
    }

    var prompt: String {
        switch mode {
        case .team: "اختاروا الضحية"
        case .single(.protect): "مين تحمي الليلة؟"
        case .single(.inspect): "مين تبي تحقق فيه؟"
        case .single(.shoot): "مين تطلق عليه؟"
        case .single: "اختر لاعب"
        case .waiting:
            if !isAlive { "أنت تشاهد. المدينة نايمة" }
            else if abilitySpent { "استخدمت رصاصتك... انتظر الصباح" }
            else { "المدينة نايمة... انتظر الصباح" }
        }
    }

    var hint: String? {
        switch mode {
        case .team: "اختيارات فريقك تظهر لحظياً"
        case .single(.protect): "تقدر تحمي نفسك، بس مو نفس الشخص ليلتين ورا بعض"
        case .single(.inspect): locked ? "اخترت الليلة، والنتيجة قدامك" : "اختيارك نهائي، فكّر زين"
        case .single(.shoot): "رصاصة وحدة باللعبة كلها. لو طلع بريء تموت أنت"
        default: nil
        }
    }

    var teammates: [Teammate] { store.me?.teammates ?? [] }

    var rows: [TargetRow] {
        guard let room = store.room, let me = store.me else { return [] }
        let valid = Set(me.validTargetIds)
        let picks = Dictionary(grouping: me.teamChoices ?? [], by: { $0.targetId ?? "" })
        let candidates = room.players.filter { player in
            guard player.alive else { return false }
            // Mafia only see who they may pick; single pickers see everyone alive, unavailable ones disabled.
            return mode == .team ? valid.contains(player.id) || myTarget == player.id : true
        }
        return candidates.map { player in
            TargetRow(
                id: player.id,
                name: player.id == me.playerId ? "\(player.name) (أنت)" : player.name,
                enabled: valid.contains(player.id),
                selected: myTarget == player.id,
                pickedBy: (picks[player.id] ?? []).map { $0.actorId == me.playerId ? "أنت" : store.name(of: $0.actorId) }
            )
        }
    }

    /// The detective's answer for tonight, once chosen.
    var tonightsInspection: InspectionResult? {
        guard let round = store.room?.round else { return nil }
        return store.me?.inspections.last { $0.round == round }
    }

    var pastInspections: [InspectionResult] {
        let round = store.room?.round
        return (store.me?.inspections ?? []).filter { $0.round != round }.reversed()
    }

    func name(of id: String) -> String { store.name(of: id) }

    func tap(_ row: TargetRow) {
        guard !locked else { return }
        if row.selected {
            store.nightAction(nil)
        } else if row.enabled {
            store.nightAction(row.id)
        }
    }

    // Mafia night chat.
    var chat: [ChatMessage] { store.messages(in: .mafia) }
    var canChat: Bool { store.me?.writableChannels.contains(.mafia) ?? false }
    var myId: String? { store.playerId }
    func sendChat(_ text: String) { store.sendChat(text, channel: .mafia) }

    // Spectators talk among themselves.
    var deadChat: [ChatMessage] { store.messages(in: .dead) }
    var canDeadChat: Bool { store.me?.writableChannels.contains(.dead) ?? false }
    func sendDeadChat(_ text: String) { store.sendChat(text, channel: .dead) }
}
