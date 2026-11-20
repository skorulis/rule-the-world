import SwiftUI

struct HexCellDetailView: View {
    let cell: HexCell
    let visit: HexVisit?
    let visitCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hexagon")
                .font(.headline)
            LabeledContent("Visits", value: "\(visitCount)")
            if let visit {
                LabeledContent("Score", value: "\(Int(visit.score))")
                LabeledContent(
                    "Last visit",
                    value: visit.lastVisit.formatted(.relative(presentation: .named))
                )
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.height(180)])
    }
}

#Preview {
    HexCellDetailView(
        cell: HexCell(rawValue: 0x8928308280FFFFF),
        visit: HexVisit(
            cell: HexCell(rawValue: 0x8928308280FFFFF),
            lastVisit: .now,
            score: 3,
            lastScore: 1
        ),
        visitCount: 7
    )
}
