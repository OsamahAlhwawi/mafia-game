import SwiftUI

/// The server speaks a newer protocol than this build: nothing to do but update.
struct UpdateRequiredView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.down.app.fill").font(.system(size: 64)).foregroundStyle(Palette.gold)
            Text("فيه نسخة جديدة").font(.kufi(28, weight: 600))
            Text("حدّث التطبيق من TestFlight عشان تكمل اللعب.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.Night.muted)
            Spacer()
        }
        .padding(32)
    }
}
