import SwiftUI

struct HexCellDetailView: View {
    let model: HexCellDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hexagon")
                .font(.headline)
            LabeledContent("Visits", value: "\(model.visitCount)")
            if let visit = model.visit {
                LabeledContent("Score", value: visit.score.formatted())
                if visit.total > 0 {
                    LabeledContent(
                        "Last visit",
                        value: visit.lastVisit.formatted(.relative(presentation: .named))
                    )
                }
            }
            if model.isLoadingTotals {
                ProgressView()
            } else if let totals = model.info?.totals {
                LabeledContent("Total visits", value: "\(totals.totalVisits)")
                if totals.rivalScore > 0 {
                    LabeledContent("Rival score", value: totals.rivalScore.formatted())
                }
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.height(260)])
    }
}

#Preview {
    if let database = try? AppDatabase.inMemory() {
        HexCellDetailView(
            model: HexCellDetailViewModel(
                cell: HexCell(rawValue: 0x8928308280FFFFF),
                store: HexInfoStore(database: database),
                logStore: HexVisitLogStore(database: database)
            )
        )
    } else {
        Text("Preview unavailable")
    }
}
