import SwiftUI

/// How to play, in plain Gulf Arabic.
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, symbol: String, lines: [String])] = [
        ("فكرة اللعبة", "building.columns.fill", [
            "مدينة فيها مواطنين، وبينهم أفراد من المافيا مندسّين بالسر.",
            "المافيا يطلّعون لاعب كل ليلة بدون ما ينكشفون، والمدينة تحاول تكشفهم وتطردهم بالتصويت.",
            "التطبيق هو الراوي: يوزّع الأدوار ويدير الوقت ويعلن النتائج.",
        ]),
        ("مراحل الجولة", "clock.fill", [
            "كشف الأدوار: كل واحد يقلب كرته بالسر.",
            "الليل (25 ثانية): المافيا يختارون ضحية، والطبيب يحمي، والمحقق يكشف. الباقين ينتظرون.",
            "الصباح: الراوي يعلن مين طلع، وينكشف كرته للكل.",
            "النقاش: المدة يحددها المضيف. الأحياء يتكلمون بالشات.",
            "التصويت (30 ثانية): صوّت على اللي تشك فيه أو امتنع. تقدر تغيّر صوتك، ولما يصوّت الكل يبقى 5 ثواني للتغيير.",
            "النتيجة: تنكشف الأصوات. صاحب أعلى أصوات يطلع، وفي التعادل ما أحد يطلع.",
        ]),
        ("الفوز", "trophy.fill", [
            "المدينة تفوز إذا طلعت كل المافيا.",
            "المافيا تفوز إذا صار عددهم يساوي أو يزيد على الباقين.",
            "بنهاية اللعبة تنكشف أدوار الجميع.",
        ]),
        ("قوانين مهمة", "exclamationmark.shield.fill", [
            "اللي يطلع يصير مشاهد: يشوف اللعبة ويدردش مع المشاهدين بس، وما يصوّت.",
            "اللي ما يصوّت قبل نهاية الوقت ما ينحسب له صوت. واللي يضغط «امتناع» ينحسب ممتنع.",
            "إذا انقطع اتصالك أكثر من دقيقتين تطلع من اللعبة. لو رجعت قبلها تكمل عادي، ولو رجعت بعدها ترجع للغرفة كمشاهد.",
            "لا تخلّي أحد يطالع شاشتك!",
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(section.title, systemImage: section.symbol)
                                .font(.kufi(20, weight: 600))
                                .foregroundStyle(Color(hex: 0xA3261F))
                            ForEach(section.lines, id: \.self) { line in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•").foregroundStyle(Palette.goldDeep)
                                    Text(line).fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.body)
                                .foregroundStyle(Color(hex: 0x3A2A17))
                            }
                        }
                    }
                }
                .padding(22)
            }
            .background(Color(hex: 0xF3E6C8).ignoresSafeArea())
            .navigationTitle("قواعد اللعبة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("تم") { dismiss() } }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.colorScheme, .light)
    }
}

#Preview {
    RulesView()
}
