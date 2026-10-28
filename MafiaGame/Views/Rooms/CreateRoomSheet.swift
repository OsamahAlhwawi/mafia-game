import SwiftUI

/// Opening a room: an optional name and how many seats (fixed once created).
/// Bots fill every seat but mine.
struct CreateRoomSheet: View {
    let defaultName: String
    let create: (_ name: String, _ capacity: Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var capacity = 7

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(defaultName, text: $name)
                } header: {
                    Text("اسم الغرفة")
                } footer: {
                    Text("اختياري. لو تركته فاضي يصير «\(defaultName)»، وتقدر تغيّره بعدين.")
                }

                Section {
                    Picker("عدد اللاعبين", selection: $capacity) {
                        ForEach(5...9, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("عدد اللاعبين")
                } footer: {
                    Text("أنت وبوتات على باقي الكراسي. تقدر تشيل بوت أو ترجّعه من الغرفة.")
                }
            }
            .navigationTitle("غرفة جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("أنشئ") {
                        create(name, capacity)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

#Preview {
    CreateRoomSheet(defaultName: "غرفة سارة") { _, _ in }
        .environment(\.layoutDirection, .rightToLeft)
}
