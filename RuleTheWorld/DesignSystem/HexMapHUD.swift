import SwiftUI

struct HexMapHUD: View {
    let resolution: Int?
    let lastTappedCell: HexCell?
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
        showGrid: .constant(true)
    )
}
