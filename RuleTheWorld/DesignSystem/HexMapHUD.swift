import SwiftUI

struct HexMapHUD: View {
    let resolution: Int?
    let lastTappedCell: HexCell?
    let lastTappedVisit: HexVisit?
    @Binding var showGrid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let resolution {
                LabeledContent("Resolution", value: "\(resolution)")
            } else {
                Text("Zoom in to see grid")
                    .font(.headline)
            }
            if let lastTappedCell {
                LabeledContent("Last tapped", value: lastTappedCell.description)
                    .font(.caption)
            }
            if let lastTappedVisit {
                LabeledContent("Score", value: "\(Int(lastTappedVisit.score))")
                LabeledContent(
                    "Last visit",
                    value: lastTappedVisit.lastVisit.formatted(.relative(presentation: .named))
                )
                .font(.caption)
            }
            Toggle("Show grid", isOn: $showGrid)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

#Preview {
    HexMapHUD(
        resolution: 10,
        lastTappedCell: HexCell(rawValue: 0x8928308280FFFFF),
        lastTappedVisit: HexVisit(
            cell: HexCell(rawValue: 0x8928308280FFFFF),
            lastVisit: .now,
            score: 3,
            lastScore: 1
        ),
        showGrid: .constant(true)
    )
}
