import SwiftUI

/// The ⋯ button (top right): rules & cards, and leaving the room.
struct GameMenuButton: View {
    let deck: [DeckEntry]
    /// Ask before leaving when it would knock me out of a running game.
    var confirmLeave = false
    let leave: () -> Void

    // `-devOpenDeck YES` opens the cards page on launch (screenshots during development).
    @State private var showDeck = UserDefaults.standard.string(forKey: "devOpenDeck") == "YES"
    @State private var confirming = false

    var body: some View {
        Menu {
            Button("القواعد والبطاقات", systemImage: "book.closed.fill") { showDeck = true }
            Button("خروج من الغرفة", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                if confirmLeave { confirming = true } else { leave() }
            }
        } label: {
            MenuDots()
        }
        .accessibilityLabel("القائمة")
        .confirmationDialog("تبي تطلع من اللعبة؟", isPresented: $confirming, titleVisibility: .visible) {
            Button("اطلع", role: .destructive, action: leave)
            Button("كمّل اللعب", role: .cancel) {}
        } message: {
            Text("لو طلعت الحين تصير خارج اللعبة وينكشف كرتك.")
        }
        .fullScreenCover(isPresented: $showDeck) {
            DeckSheet(deck: deck)
        }
    }
}

/// The ⋯ in its dark circle, top right of the table (the game's menu, the lobby's settings).
struct MenuDots: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.title3.weight(.bold))
            .frame(width: 44, height: 44)
            .background(Circle().fill(Palette.Night.surface.opacity(0.92)))
            .foregroundStyle(Palette.Night.text)
    }
}
